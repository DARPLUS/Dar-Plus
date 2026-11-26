import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'ringtone_service.dart';

/// Etat d'un appel audio.
enum CallStatus { outgoing, incoming, connecting, connected, ended }

/// Appel audio en cours (appelant ou appelé).
class CallSession {
  CallSession({
    required this.id,
    required this.peerId,
    required this.peerName,
    required this.isCaller,
    required this.status,
    this.bookingId,
    this.serviceType,
    this.connectedAt,
    this.endReason,
    this.muted = false,
    this.speakerOn = false,
    this.micUnavailable = false,
  });

  final String id;
  final String peerId;
  final String peerName;
  final bool isCaller;
  final String? bookingId;
  final String? serviceType;

  CallStatus status;
  DateTime? connectedAt;
  String? endReason;
  bool muted;
  bool speakerOn;
  bool micUnavailable;
}

/// Service d'appels audio intégrés à l'application (WebRTC).
///
/// La signalisation (offre/réponse SDP + candidats ICE) transite par la
/// collection Firestore `calls`. Aucun serveur supplémentaire n'est requis.
class CallService extends ChangeNotifier {
  CallService._();

  static final CallService instance = CallService._();

  /// Serveurs STUN publics + TURN de secours (Open Relay).
  /// En production, remplacez le TURN par le vôtre.
  static const Map<String, dynamic> _iceConfiguration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {
        'urls': 'turn:openrelay.metered.ca:80',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
      {
        'urls': 'turn:openrelay.metered.ca:443',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
      {
        'urls': 'turn:openrelay.metered.ca:443?transport=tcp',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
    ],
  };

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CallSession? _session;
  CallSession? get session => _session;

  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  RTCVideoRenderer? _remoteRenderer;
  DocumentReference<Map<String, dynamic>>? _callRef;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _docSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _incomingSub;

  Timer? _ringTimer;
  Timer? _clearTimer;

  bool _initialized = false;
  bool _remoteDescriptionSet = false;
  bool _docReady = false;
  bool _finishing = false;
  bool _applyingAnswer = false;

  int _remoteCandidateCount = 0;
  final List<Map<String, dynamic>> _pendingLocalCandidates = [];
  final List<RTCIceCandidate> _pendingRemoteCandidates = [];

  String get _localCandidatesField =>
      (_session?.isCaller ?? true) ? 'callerCandidates' : 'calleeCandidates';

  String get _remoteCandidatesField =>
      (_session?.isCaller ?? true) ? 'calleeCandidates' : 'callerCandidates';

  /// A appeler une fois au démarrage de l'application.
  void init() {
    if (_initialized) return;
    _initialized = true;
    _auth.authStateChanges().listen(_onAuthChanged);
  }

  void _onAuthChanged(User? user) {
    _incomingSub?.cancel();
    _incomingSub = null;
    if (user == null) return;

    _incomingSub = _firestore
        .collection('calls')
        .where('calleeId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'ringing')
        .snapshots()
        .listen(
          _onIncomingSnapshot,
          onError: (Object e) => debugPrint('[CALL] incoming listen error: $e'),
        );
  }

  void _onIncomingSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    if (_session != null) return;
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      if ((data['callerId'] ?? '').toString() == myUid) continue;

      final createdAt = data['createdAt'];
      if (createdAt is Timestamp) {
        final age = DateTime.now().difference(createdAt.toDate());
        if (age.inSeconds > 45) continue;
      }

      _showIncoming(doc.id, data);
      return;
    }
  }

  void _showIncoming(String callId, Map<String, dynamic> data) {
    _resetSessionState();
    _callRef = _firestore.collection('calls').doc(callId);
    _session = CallSession(
      id: callId,
      peerId: (data['callerId'] ?? '').toString(),
      peerName: (data['callerName'] ?? 'Utilisateur').toString(),
      serviceType: data['serviceType']?.toString(),
      bookingId: data['bookingId']?.toString(),
      isCaller: false,
      status: CallStatus.incoming,
    );
    _watchCallDoc();
    _ringTimer = Timer(const Duration(seconds: 45), () {
      if (_session?.status == CallStatus.incoming) {
        _finish('missed', writeStatus: true);
      }
    });
    notifyListeners();
  }

  /// Démarre un appel vers [calleeId].
  Future<void> startCall({
    required String calleeId,
    required String calleeName,
    String? bookingId,
    String? serviceType,
  }) async {
    final me = _auth.currentUser;
    if (me == null || _session != null) return;
    if (calleeId.trim().isEmpty || calleeId == me.uid) return;

    _resetSessionState();

    final ref = _firestore.collection('calls').doc();
    _callRef = ref;
    _session = CallSession(
      id: ref.id,
      peerId: calleeId,
      peerName: calleeName.trim().isEmpty ? 'Utilisateur' : calleeName.trim(),
      bookingId: bookingId,
      serviceType: serviceType,
      isCaller: true,
      status: CallStatus.outgoing,
    );
    _finishing = false;
    notifyListeners();

    try {
      var callerName = (me.displayName ?? '').trim();
      var callerRole = 'client';
      try {
        final userSnap = await _firestore.collection('users').doc(me.uid).get();
        final user = userSnap.data();
        final fullName = (user?['fullName'] ?? '').toString().trim();
        if (fullName.isNotEmpty) callerName = fullName;
        final role = (user?['role'] ?? '').toString().trim();
        if (role.isNotEmpty) callerRole = role;
      } catch (_) {}
      if (callerName.isEmpty) callerName = 'Utilisateur';

      await _openPeer();
      if (_session?.micUnavailable == true) notifyListeners();

      final offer = await _pc!.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': false,
      });
      await _pc!.setLocalDescription(offer);

      if (_session == null || _session!.status == CallStatus.ended) {
        await _closePeer();
        return;
      }

      await ref.set({
        'callerId': me.uid,
        'callerName': callerName,
        'callerRole': callerRole,
        'calleeId': calleeId,
        'calleeName': _session!.peerName,
        'bookingId': bookingId,
        'serviceType': serviceType,
        'status': 'ringing',
        'createdAt': FieldValue.serverTimestamp(),
        'offer': {'type': offer.type, 'sdp': offer.sdp},
        'callerCandidates': <Map<String, dynamic>>[],
        'calleeCandidates': <Map<String, dynamic>>[],
      });

      _docReady = true;
      _flushLocalCandidates();
      _watchCallDoc();

      _ringTimer = Timer(const Duration(seconds: 45), () {
        final status = _session?.status;
        if (status == CallStatus.outgoing || status == CallStatus.connecting) {
          _finish('missed', writeStatus: true);
        }
      });
    } catch (e) {
      debugPrint('[CALL] startCall error: $e');
      await _finish('failed', writeStatus: true);
    }
  }

  /// Accepte l'appel entrant.
  Future<void> acceptCall() async {
    final session = _session;
    final ref = _callRef;
    if (session == null || ref == null) return;
    if (session.isCaller || session.status != CallStatus.incoming) return;

    session.status = CallStatus.connecting;
    _ringTimer?.cancel();
    try {
      RingtoneService.instance.stop();
    } catch (_) {}
    notifyListeners();

    try {
      await ref.update({
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      final latest = await ref.get();
      final data = latest.data() ?? const <String, dynamic>{};
      final offer = data['offer'];
      if (offer is! Map || (offer['sdp'] ?? '').toString().isEmpty) {
        await _finish('failed', writeStatus: true);
        return;
      }

      _docReady = true;
      await _openPeer();

      if (_session == null || _session!.status == CallStatus.ended) {
        await _closePeer();
        return;
      }

      await _pc!.setRemoteDescription(
        RTCSessionDescription(
          offer['sdp'].toString(),
          offer['type'].toString(),
        ),
      );
      _remoteDescriptionSet = true;

      _applyRemoteCandidates(data['callerCandidates']);
      _flushRemoteCandidates();

      final answer = await _pc!.createAnswer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': false,
      });
      await _pc!.setLocalDescription(answer);

      await ref.update({
        'answer': {'type': answer.type, 'sdp': answer.sdp},
      });
    } catch (e) {
      debugPrint('[CALL] acceptCall error: $e');
      await _finish('failed', writeStatus: true);
    }
  }

  /// Refuse l'appel entrant.
  Future<void> rejectCall() async {
    final session = _session;
    if (session == null || session.isCaller) return;
    await _finish('rejected', writeStatus: true);
  }

  /// Raccroche / annule l'appel.
  Future<void> hangUp() async {
    final session = _session;
    if (session == null) return;
    if (session.status == CallStatus.incoming) {
      await _finish('rejected', writeStatus: true);
    } else {
      await _finish('ended', writeStatus: true);
    }
  }

  Future<void> toggleMute() async {
    final session = _session;
    if (session == null) return;
    session.muted = !session.muted;
    for (final track
        in _localStream?.getAudioTracks() ?? const <MediaStreamTrack>[]) {
      track.enabled = !session.muted;
    }
    notifyListeners();
  }

  Future<void> toggleSpeaker() async {
    final session = _session;
    if (session == null) return;
    session.speakerOn = !session.speakerOn;
    try {
      await Helper.setSpeakerphoneOn(session.speakerOn);
    } catch (e) {
      debugPrint('[CALL] speaker error: $e');
    }
    notifyListeners();
  }

  Future<void> _openPeer() async {
    _remoteRenderer = RTCVideoRenderer();
    await _remoteRenderer!.initialize();
    _pc = await createPeerConnection(_iceConfiguration);
    try {
      await Helper.setSpeakerphoneOn(true);
    } catch (_) {}

    try {
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': false,
      });
    } catch (e) {
      debugPrint('[CALL] getUserMedia (detailed) error: $e');
      try {
        _localStream = await navigator.mediaDevices.getUserMedia({
          'audio': true,
          'video': false,
        });
      } catch (e2) {
        debugPrint('[CALL] getUserMedia (simple) error: $e2');
        _localStream = null;
        _session?.micUnavailable = true;
      }
    }

    if (_localStream != null) {
      for (final track in _localStream!.getAudioTracks()) {
        await _pc!.addTrack(track, _localStream!);
      }
    }

    _pc!.onTrack = (event) {
      debugPrint('[CALL] onTrack: ${event.track.kind} (${event.track.id})');
      final streams = event.streams;
      if (streams.isNotEmpty && _remoteRenderer != null) {
        _remoteRenderer!.srcObject = streams.first;
      }
    };
    _pc!.onAddStream = (stream) {
      debugPrint(
        '[CALL] onAddStream: ${stream.id} (${stream.getAudioTracks().length} audio)',
      );
      if (_remoteRenderer != null) {
        _remoteRenderer!.srcObject = stream;
      }
    };
    _pc!.onRemoveStream = (stream) {
      debugPrint('[CALL] onRemoveStream: ${stream.id}');
    };

    _pc!.onIceCandidate = (candidate) {
      final value = candidate.candidate;
      if (value == null || value.isEmpty) return;
      final data = <String, dynamic>{
        'candidate': value,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      };
      if (!_docReady) {
        _pendingLocalCandidates.add(data);
        return;
      }
      _callRef
          ?.update({
            _localCandidatesField: FieldValue.arrayUnion([data]),
          })
          .catchError((Object e) => debugPrint('[CALL] send candidate: $e'));
    };

    _pc!.onConnectionState = (state) {
      debugPrint('[CALL] connection state: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _markConnected();
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        if (_session != null && _session!.status != CallStatus.ended) {
          _finish('failed', writeStatus: true);
        }
      }
    };

    _pc!.onIceConnectionState = (state) {
      debugPrint('[CALL] ice state: $state');
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        _markConnected();
      }
    };
  }

  Future<void> _markConnected() async {
    final session = _session;
    if (session == null) return;
    if (session.status == CallStatus.connected ||
        session.status == CallStatus.ended) {
      return;
    }
    session.status = CallStatus.connected;
    session.connectedAt ??= DateTime.now();
    _ringTimer?.cancel();
    _ringTimer = null;
    try {
      RingtoneService.instance.stop();
    } catch (_) {}
    // Activer le haut-parleur par défaut pour que l'audio soit audible.
    session.speakerOn = true;
    try {
      await Helper.setSpeakerphoneOn(true);
    } catch (_) {}
    notifyListeners();
  }

  void _watchCallDoc() {
    _docSub?.cancel();
    final ref = _callRef;
    if (ref == null) return;

    _docSub = ref.snapshots().listen((snapshot) {
      final data = snapshot.data();
      final session = _session;
      if (data == null || session == null || session.id != ref.id) return;

      _applyRemoteCandidates(data[_remoteCandidatesField]);

      if (session.isCaller && !_remoteDescriptionSet) {
        final answer = data['answer'];
        if (answer is Map && (answer['sdp'] ?? '').toString().isNotEmpty) {
          _applyAnswer(answer);
        }
      }

      final status = (data['status'] ?? '').toString();
      switch (status) {
        case 'accepted':
          if (session.isCaller && session.status == CallStatus.outgoing) {
            session.status = CallStatus.connecting;
            notifyListeners();
          }
          break;
        case 'rejected':
          _finish('rejected');
          break;
        case 'missed':
          _finish('missed');
          break;
        case 'failed':
          _finish('failed');
          break;
        case 'ended':
          _finish('ended');
          break;
      }
    }, onError: (Object e) => debugPrint('[CALL] doc listen error: $e'));
  }

  Future<void> _applyAnswer(Map<dynamic, dynamic> answer) async {
    if (_pc == null || _remoteDescriptionSet || _applyingAnswer) return;
    _applyingAnswer = true;
    try {
      await _pc!.setRemoteDescription(
        RTCSessionDescription(
          answer['sdp'].toString(),
          answer['type'].toString(),
        ),
      );
      _remoteDescriptionSet = true;
      _flushRemoteCandidates();
    } catch (e) {
      debugPrint('[CALL] apply answer error: $e');
    } finally {
      _applyingAnswer = false;
    }
  }

  void _applyRemoteCandidates(dynamic raw) {
    if (raw is! List) return;
    if (_remoteCandidateCount >= raw.length) return;

    final newCandidates = raw.sublist(_remoteCandidateCount);
    _remoteCandidateCount = raw.length;

    for (final item in newCandidates) {
      if (item is! Map) continue;
      final value = (item['candidate'] ?? '').toString();
      if (value.isEmpty) continue;

      final candidate = RTCIceCandidate(
        value,
        item['sdpMid']?.toString(),
        (item['sdpMLineIndex'] as num?)?.toInt(),
      );

      if (!_remoteDescriptionSet || _pc == null) {
        _pendingRemoteCandidates.add(candidate);
      } else {
        unawaited(
          _pc!
              .addCandidate(candidate)
              .catchError((Object e) => debugPrint('[CALL] add candidate: $e')),
        );
      }
    }
  }

  void _flushRemoteCandidates() {
    final pc = _pc;
    if (pc == null || !_remoteDescriptionSet) return;
    final pending = List<RTCIceCandidate>.from(_pendingRemoteCandidates);
    _pendingRemoteCandidates.clear();
    for (final candidate in pending) {
      unawaited(
        pc
            .addCandidate(candidate)
            .catchError(
              (Object e) => debugPrint('[CALL] add pending candidate: $e'),
            ),
      );
    }
  }

  void _flushLocalCandidates() {
    final ref = _callRef;
    if (ref == null || _pendingLocalCandidates.isEmpty) return;
    final pending = List<Map<String, dynamic>>.from(_pendingLocalCandidates);
    _pendingLocalCandidates.clear();
    ref
        .update({_localCandidatesField: FieldValue.arrayUnion(pending)})
        .catchError((Object e) => debugPrint('[CALL] flush candidates: $e'));
  }

  void _resetSessionState() {
    _ringTimer?.cancel();
    _ringTimer = null;
    _clearTimer?.cancel();
    _clearTimer = null;
    _docSub?.cancel();
    _docSub = null;
    _remoteDescriptionSet = false;
    _docReady = false;
    _finishing = false;
    _remoteCandidateCount = 0;
    _pendingLocalCandidates.clear();
    _pendingRemoteCandidates.clear();
  }

  Future<void> _finish(String reason, {bool writeStatus = false}) async {
    final session = _session;
    if (session == null || _finishing) return;
    _finishing = true;

    _ringTimer?.cancel();
    _ringTimer = null;
    try {
      RingtoneService.instance.stop();
    } catch (_) {}
    _docSub?.cancel();
    _docSub = null;

    if (writeStatus) {
      final ref = _callRef;
      if (ref != null) {
        final status = switch (reason) {
          'rejected' => 'rejected',
          'missed' => 'missed',
          'failed' => 'failed',
          _ => 'ended',
        };
        try {
          await ref.update({
            'status': status,
            'endedAt': FieldValue.serverTimestamp(),
            'endedBy': _auth.currentUser?.uid ?? '',
          });
        } catch (e) {
          debugPrint('[CALL] finish update error: $e');
        }
      }
    }

    session.status = CallStatus.ended;
    session.endReason = reason;

    // Enregistrer l'appel dans la discussion (historique d'appel).
    final bookingId = session.bookingId;
    if (bookingId != null && bookingId.isNotEmpty) {
      final wasConnected = session.connectedAt != null;
      String label;
      if (reason == 'rejected') {
        label = 'Appel refusé';
      } else if (reason == 'missed') {
        label = 'Appel manqué';
      } else if (reason == 'failed') {
        label = 'Appel échoué';
      } else if (wasConnected) {
        final d = DateTime.now().difference(session.connectedAt!);
        final mm = d.inMinutes.toString().padLeft(2, '0');
        final ss = (d.inSeconds % 60).toString().padLeft(2, '0');
        label = 'Appel audio — $mm:$ss';
      } else {
        label = 'Appel annulé';
      }
      unawaited(
        Future<void>(() async {
          try {
            await _firestore
                .collection('bookings')
                .doc(bookingId)
                .collection('messages')
                .add({
                  'senderId': _auth.currentUser?.uid ?? '',
                  'text': label,
                  'createdAt': FieldValue.serverTimestamp(),
                  'type': 'call',
                });
          } catch (_) {}
        }),
      );
    }

    notifyListeners();

    await _closePeer();
    try {
      await Helper.setSpeakerphoneOn(false);
    } catch (_) {}

    _clearTimer?.cancel();
    _clearTimer = Timer(const Duration(milliseconds: 1700), () {
      if (_session?.id == session.id) {
        _session = null;
        _callRef = null;
        _finishing = false;
        notifyListeners();
        _checkPendingIncoming();
      }
    });
  }

  /// Rattrape un appel entrant arrivé pendant la fermeture de l'appel précédent.
  Future<void> _checkPendingIncoming() async {
    final user = _auth.currentUser;
    if (user == null || _session != null) return;
    try {
      final snapshot = await _firestore
          .collection('calls')
          .where('calleeId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'ringing')
          .get();
      _onIncomingSnapshot(snapshot);
    } catch (e) {
      debugPrint('[CALL] pending incoming check error: $e');
    }
  }

  Future<void> _closePeer() async {
    final pc = _pc;
    final stream = _localStream;
    final renderer = _remoteRenderer;
    _pc = null;
    _localStream = null;
    _remoteRenderer = null;

    try {
      await renderer?.dispose();
    } catch (_) {}

    try {
      await stream?.dispose();
    } catch (_) {}
    try {
      await pc?.close();
    } catch (_) {}
  }
}
