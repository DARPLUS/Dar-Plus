import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';

import '../core/localization/app_localizations.dart';
import '../services/call_service.dart';
import '../services/push_notification_service.dart';
import '../services/ringtone_service.dart';
import 'pro_avatar_widget.dart';

/// Superposition globale qui affiche l'écran d'appel au-dessus de toute l'app.
class CallOverlay extends StatefulWidget {
  final Widget child;

  const CallOverlay({super.key, required this.child});

  @override
  State<CallOverlay> createState() => _CallOverlayState();
}

class _CallOverlayState extends State<CallOverlay> {
  @override
  void initState() {
    super.initState();
    CallService.instance.init();
    PushNotificationService.instance.init();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CallService.instance,
      builder: (context, _) {
        final session = CallService.instance.session;
        return Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            if (session != null)
              Positioned.fill(child: CallScreen(session: session)),
          ],
        );
      },
    );
  }
}

/// Écran plein écran d'un appel entrant ou en cours.
class CallScreen extends StatefulWidget {
  final CallSession session;

  const CallScreen({super.key, required this.session});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  Timer? _ticker;
  Timer? _ringtone;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.primaryFocus?.unfocus();
    CallService.instance.addListener(_onCallChanged);
    _syncTimers();
  }

  @override
  void dispose() {
    CallService.instance.removeListener(_onCallChanged);
    _ticker?.cancel();
    _ringtone?.cancel();
    super.dispose();
  }

  void _onCallChanged() {
    if (!mounted) return;
    _syncTimers();
  }

  void _syncTimers() {
    final session = widget.session;

    if (session.status == CallStatus.connected) {
      _ringtone?.cancel();
      _ringtone = null;
      RingtoneService.instance.stop();
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          _elapsed = DateTime.now()
              .difference(session.connectedAt ?? DateTime.now());
        });
      });
    } else if (session.status == CallStatus.incoming) {
      _ticker?.cancel();
      _ticker = null;
      _ringtone ??= Timer.periodic(const Duration(seconds: 3), (_) {
        RingtoneService.instance.play();
        HapticFeedback.selectionClick();
      });
      RingtoneService.instance.play();
      HapticFeedback.mediumImpact();
    } else if (session.status == CallStatus.outgoing) {
      _ticker?.cancel();
      _ticker = null;
      _ringtone ??= Timer.periodic(const Duration(seconds: 3), (_) {
        RingtoneService.instance.playRingback();
      });
      RingtoneService.instance.playRingback();
    } else {
      _ticker?.cancel();
      _ticker = null;
      _ringtone?.cancel();
      _ringtone = null;
      RingtoneService.instance.stop();
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _statusText(BuildContext context) {
    final session = widget.session;
    switch (session.status) {
      case CallStatus.incoming:
        return 'call_incoming'.tr();
      case CallStatus.outgoing:
        return 'call_calling'.tr();
      case CallStatus.connecting:
        return 'call_connecting'.tr();
      case CallStatus.connected:
        return 'call_connected'.tr();
      case CallStatus.ended:
        switch (session.endReason) {
          case 'rejected':
            return 'call_rejected'.tr();
          case 'missed':
            return 'call_missed'.tr();
          case 'failed':
            return 'call_failed'.tr();
          default:
            return 'call_ended'.tr();
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final isIncoming = session.status == CallStatus.incoming;
    final isEnded = session.status == CallStatus.ended;
    final isConnected = session.status == CallStatus.connected;

    return Material(
      color: const Color(0xFF0B1B2B),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: () {},
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0B1B2B),
                Color(0xFF0C3B3A),
                Color(0xFF0D544E),
              ],
            ),
          ),
          child: Semantics(
            explicitChildNodes: true,
            container: true,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 20, 28, 30),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock_rounded,
                          color: Colors.white54, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'call_audio_title'.tr(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  ProAvatarWidget(
                    size: 118,
                    name: session.peerName,
                    borderRadius: 59,
                    showVerifiedBadge: false,
                  ),
                  const SizedBox(height: 26),
                  Text(
                    session.peerName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 27,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if ((session.serviceType ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        session.serviceType!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Text(
                    _statusText(context),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (isConnected) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _formatDuration(_elapsed),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                  if (session.micUnavailable) ...[
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.mic_off_rounded,
                            color: Color(0xFFFBBF24), size: 16),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'call_mic_unavailable'.tr(),
                            style: const TextStyle(
                              color: Color(0xFFFBBF24),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const Spacer(),
                  if (isEnded)
                    const SizedBox(height: 92)
                  else if (isIncoming)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _CallActionButton(
                          icon: Icons.call_end_rounded,
                          label: 'call_decline'.tr(),
                          color: const Color(0xFFDC2626),
                          onPressed: CallService.instance.rejectCall,
                        ),
                        _CallActionButton(
                          icon: Icons.call_rounded,
                          label: 'call_accept'.tr(),
                          color: const Color(0xFF10B981),
                          onPressed: CallService.instance.acceptCall,
                        ),
                      ],
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _CallActionButton(
                          icon: session.muted
                              ? Icons.mic_off_rounded
                              : Icons.mic_rounded,
                          label: 'call_mute'.tr(),
                          color: session.muted
                              ? const Color(0xFFE05D38)
                              : Colors.white.withValues(alpha: 0.14),
                          onPressed: CallService.instance.toggleMute,
                        ),
                        _CallActionButton(
                          icon: session.speakerOn
                              ? Icons.volume_up_rounded
                              : Icons.volume_off_rounded,
                          label: 'call_speaker'.tr(),
                          color: session.speakerOn
                              ? const Color(0xFFE05D38)
                              : Colors.white.withValues(alpha: 0.14),
                          onPressed: CallService.instance.toggleSpeaker,
                        ),
                        _CallActionButton(
                          icon: Icons.call_end_rounded,
                          label: 'call_hang_up'.tr(),
                          color: const Color(0xFFDC2626),
                          onPressed: CallService.instance.hangUp,
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.shield_rounded,
                          color: Colors.white38, size: 13),
                      const SizedBox(width: 5),
                      Text(
                        'call_encrypted'.tr(),
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CallActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Future<void> Function() onPressed;

  const _CallActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        button: true,
        label: label,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: color,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onPressed,
                child: SizedBox(
                  width: 68,
                  height: 68,
                  child: Icon(icon, color: Colors.white, size: 30),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
