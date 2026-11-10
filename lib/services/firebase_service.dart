import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../firebase_options.dart';
import 'notification_service.dart';
import 'email_service.dart';

class ProApplication {
  final String id;
  final String fullName;
  final String phone;
  final String email;
  final String? cin;
  final String serviceType;
  final String status; // 'en_attente', 'valide', 'refuse'
  final DateTime createdAt;
  final String? notes;
  final String? rejectionReason;

  ProApplication({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.email,
    this.cin,
    required this.serviceType,
    required this.status,
    required this.createdAt,
    this.notes,
    this.rejectionReason,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fullName': fullName,
      'phone': phone,
      'email': email,
      'cin': cin,
      'serviceType': serviceType,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'notes': notes,
      'rejectionReason': rejectionReason,
      'role': 'professionnel',
    };
  }

  factory ProApplication.fromMap(Map<String, dynamic> map, String docId) {
    DateTime date;
    if (map['createdAt'] is Timestamp) {
      date = (map['createdAt'] as Timestamp).toDate();
    } else {
      date = DateTime.now();
    }

    return ProApplication(
      id: docId,
      fullName: map['fullName'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      cin: map['cin'],
      serviceType: map['serviceType'] ?? 'Non spécifié',
      status: map['status'] ?? 'en_attente',
      createdAt: date,
      notes: map['notes'],
      rejectionReason: map['rejectionReason'],
    );
  }
}

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  // ── Credentials admin lus depuis .env ──────────────────────────
  static String get _adminRootEmail    => dotenv.env['ADMIN_ROOT_EMAIL']             ?? 'admin@darplus.tn';
  static String get _adminRootPass     => dotenv.env['ADMIN_ROOT_PASSWORD']          ?? 'admin123';
  static String get _adminRootFallback => dotenv.env['ADMIN_ROOT_FALLBACK_PASSWORD'] ?? 'password123';

  bool _isFirebaseInitialized = false;
  bool get isFirebaseInitialized => _isFirebaseInitialized;

  // Cache mémoire fallback
  final List<ProApplication> _localProApplications = [];
  final List<Map<String, dynamic>> _localCategories = [];
  bool _categoriesSeeded = false;
  final List<Map<String, dynamic>> _localSecurityLogs = [
    {
      'id': 'log_init_1',
      'action': 'Initialisation système',
      'actorEmail': 'admin@darplus.tn',
      'target': 'Plateforme DAR PLUS',
      'details': 'Système Super Admin et sécurité initialisés',
      'timestamp': DateTime.now().subtract(const Duration(hours: 3)),
      'severity': 'info',
    },
    {
      'id': 'log_init_2',
      'action': 'Création Administrateur',
      'actorEmail': 'admin@darplus.tn',
      'target': 'staff@darplus.tn',
      'details': 'Compte Admin Staff configuré avec accès restreint',
      'timestamp': DateTime.now().subtract(const Duration(hours: 1)),
      'severity': 'warning',
    },
  ];

  final Map<String, dynamic> _localGlobalSettings = {
    'appName': 'DAR PLUS',
    'supportEmail': 'support@darplus.tn',
    'supportPhone': '+216 71 000 000',
    'serviceFeePercent': 10,
    'maintenanceMode': false,
    'adminCanManageCategories': false, // Seul Super Admin par défaut
    'requireCinValidation': true,
  };

  Map<String, Map<String, dynamic>> get _localUsers => {
    _adminRootEmail: {
      'uid': 'mock_admin_root',
      'fullName': 'Super Admin DAR PLUS',
      'email': _adminRootEmail,
      'phone': '+216 71 000 000',
      'password': _adminRootPass,
      'role': 'super_admin',
      'isActive': true,
      'isApproved': true,
      'mustChangePassword': false,
    },
    'staff@darplus.tn': {
      'uid': 'mock_admin_staff',
      'fullName': 'Mohamed Admin (Staff)',
      'email': 'staff@darplus.tn',
      'phone': '+216 71 111 222',
      'password': _adminRootPass,
      'role': 'admin',
      'isActive': true,
      'isApproved': true,
      'mustChangePassword': false,
    },
  };

  Future<void> init() async {
    try {
      if (Firebase.apps.isNotEmpty) {
        _isFirebaseInitialized = true;
      } else {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        _isFirebaseInitialized = true;
      }
      debugPrint('Firebase connecté avec succès au projet darplus-edfbe !');
      // Ensemencer les pros dans Firestore si vide
      _seedDefaultProsToFirestore();
    } catch (e) {
      debugPrint('Erreur initialisation Firebase: $e');
      _isFirebaseInitialized = false;
    }
  }

  /// 1. Inscription d'un CLIENT
  Future<Map<String, dynamic>> registerClient({
    required String fullName,
    required String phone,
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanPassword = password.trim();

    try {
      if (_isFirebaseInitialized) {
        final UserCredential cred =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: cleanEmail,
          password: cleanPassword,
        );

        final user = cred.user!;
        final uid = user.uid;

        try {
          await user.updateDisplayName(fullName.trim());
          await user.sendEmailVerification();
        } catch (_) {}

        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'uid': uid,
          'fullName': fullName.trim(),
          'phone': phone.trim(),
          'email': cleanEmail,
          'role': 'client',
          'isEmailVerified': false,
          'createdAt': FieldValue.serverTimestamp(),
          'isActive': true,
        });

        _localUsers[cleanEmail] = {
          'uid': uid,
          'fullName': fullName.trim(),
          'phone': phone.trim(),
          'email': cleanEmail,
          'role': 'client',
          'isActive': true,
        };

        return {
          'success': true,
          'uid': uid,
          'emailSent': true,
          'email': cleanEmail,
          'message': 'Compte client créé avec succès !',
        };
      } else {
        await Future.delayed(const Duration(milliseconds: 400));
        return {
          'success': true,
          'uid': 'mock_client_${DateTime.now().millisecondsSinceEpoch}',
          'emailSent': true,
          'email': cleanEmail,
          'message': 'Compte client créé (Mode Démo).',
        };
      }
    } on FirebaseAuthException catch (e) {
      return {
        'success': false,
        'message': _getAuthErrorMessage(e.code),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Une erreur est survenue : $e',
      };
    }
  }

  /// 2. Création d'un ADMINISTRATEUR (par le Super Admin)
  Future<Map<String, dynamic>> registerAdmin({
    required String fullName,
    required String phone,
    required String email,
    required String password,
    String? adminSecretKey,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanPassword = password.trim();

    try {
      if (_isFirebaseInitialized) {
        String uid = '';

        // Utilisation d'une instance Firebase secondaire pour ne pas déconnecter le Super Admin
        FirebaseApp? tempApp;
        try {
          try {
            tempApp = Firebase.app('SecondaryApp');
          } catch (_) {
            tempApp = await Firebase.initializeApp(
              name: 'SecondaryApp',
              options: Firebase.app().options,
            );
          }
          final tempAuth = FirebaseAuth.instanceFor(app: tempApp);
          final cred = await tempAuth.createUserWithEmailAndPassword(
            email: cleanEmail,
            password: cleanPassword,
          );
          uid = cred.user!.uid;
          try {
            await cred.user!.updateDisplayName(fullName.trim());
          } catch (_) {}
          await tempAuth.signOut();
        } on FirebaseAuthException catch (authErr) {
          if (authErr.code == 'email-already-in-use') {
            // L'utilisateur existe déjà dans Firebase Auth : on récupère son document Firestore
            final existingDoc = await FirebaseFirestore.instance
                .collection('users')
                .where('email', isEqualTo: cleanEmail)
                .limit(1)
                .get();

            if (existingDoc.docs.isNotEmpty) {
              uid = existingDoc.docs.first.id;
            } else {
              uid = 'admin_${DateTime.now().millisecondsSinceEpoch}';
            }
          } else {
            return {
              'success': false,
              'message': _getAuthErrorMessage(authErr.code),
            };
          }
        } catch (_) {
          if (uid.isEmpty) {
            uid = 'admin_${DateTime.now().millisecondsSinceEpoch}';
          }
        }

        // Enregistrement dans Firestore avec le mot de passe temporaire
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'uid': uid,
          'fullName': fullName.trim(),
          'phone': phone.trim(),
          'email': cleanEmail,
          'role': 'admin',
          'mustChangePassword': true,
          'tempPassword': cleanPassword,
          'createdAt': FieldValue.serverTimestamp(),
          'isActive': true,
          'isApproved': true,
        }, SetOptions(merge: true));

        _localUsers[cleanEmail] = {
          'uid': uid,
          'fullName': fullName.trim(),
          'email': cleanEmail,
          'phone': phone.trim(),
          'password': cleanPassword,
          'role': 'admin',
          'mustChangePassword': true,
          'isApproved': true,
        };

        await logSecurityEvent(
          action: 'Création Administrateur',
          actorEmail: 'Super Admin',
          target: cleanEmail,
          details: 'Nouveau compte admin pour ${fullName.trim()}',
          severity: 'warning',
        );

        return {
          'success': true,
          'uid': uid,
          'message': 'Compte Administrateur configuré avec succès !',
        };
      } else {
        final uid = 'mock_admin_${DateTime.now().millisecondsSinceEpoch}';
        _localUsers[cleanEmail] = {
          'uid': uid,
          'fullName': fullName.trim(),
          'email': cleanEmail,
          'phone': phone.trim(),
          'password': cleanPassword,
          'role': 'admin',
          'mustChangePassword': true,
          'isApproved': true,
        };
        await logSecurityEvent(
          action: 'Création Administrateur',
          actorEmail: 'Super Admin',
          target: cleanEmail,
          details: 'Nouveau compte admin pour ${fullName.trim()} (Mode Démo)',
          severity: 'warning',
        );
        return {
          'success': true,
          'uid': uid,
          'message': 'Compte Administrateur créé (Mode Démo).',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Erreur lors de la création : $e',
      };
    }
  }

  /// 3. Soumission d'une DEMANDE pour un PROFESSIONNEL
  Future<Map<String, dynamic>> submitProApplication({
    required String fullName,
    required String phone,
    required String email,
    required String password,
    String? cin,
    required String serviceType,
    String? notes,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanPassword = password.trim();

    try {
      final String appId = 'pro_${DateTime.now().millisecondsSinceEpoch}';
      final app = ProApplication(
        id: appId,
        fullName: fullName.trim(),
        phone: phone.trim(),
        email: cleanEmail,
        cin: cin?.trim(),
        serviceType: serviceType,
        status: 'en_attente',
        createdAt: DateTime.now(),
        notes: notes,
      );

      if (_isFirebaseInitialized) {
        String uid = appId;

        // Création dans Firebase Auth avec SecondaryApp
        try {
          FirebaseApp? tempApp;
          try {
            tempApp = Firebase.app('SecondaryApp');
          } catch (_) {
            tempApp = await Firebase.initializeApp(
              name: 'SecondaryApp',
              options: Firebase.app().options,
            );
          }
          final tempAuth = FirebaseAuth.instanceFor(app: tempApp);
          final cred = await tempAuth.createUserWithEmailAndPassword(
            email: cleanEmail,
            password: cleanPassword,
          );
          uid = cred.user!.uid;
          await tempAuth.signOut();
        } catch (_) {}

        // 1. Enregistrement dans la collection 'pro_applications'
        await FirebaseFirestore.instance
            .collection('pro_applications')
            .doc(appId)
            .set(app.toMap());

        // 2. Enregistrement dans la collection 'users' (en attente d'approbation)
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'uid': uid,
          'fullName': fullName.trim(),
          'phone': phone.trim(),
          'email': cleanEmail,
          'cin': cin?.trim(),
          'password': cleanPassword,
          'serviceType': serviceType,
          'role': 'professionnel',
          'isApproved': false,
          'status': 'en_attente',
          'createdAt': FieldValue.serverTimestamp(),
          'isActive': true,
        }, SetOptions(merge: true));

        NotificationService().notifyAdminNewProApplication(app);

        return {
          'success': true,
          'id': appId,
          'message': 'Votre demande a bien été envoyée à l\'administrateur DAR PLUS.',
        };
      } else {
        _localProApplications.insert(0, app);
        _localUsers[cleanEmail] = {
          'uid': appId,
          'fullName': fullName.trim(),
          'phone': phone.trim(),
          'email': cleanEmail,
          'cin': cin?.trim(),
          'password': cleanPassword,
          'role': 'professionnel',
          'isApproved': false,
          'status': 'en_attente',
        };
        NotificationService().notifyAdminNewProApplication(app);
        await Future.delayed(const Duration(milliseconds: 400));
        return {
          'success': true,
          'id': appId,
          'message': 'Demande transmise avec succès (Mode Démo).',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Erreur lors de l\'envoi de la demande : $e',
      };
    }
  }

  /// 4. Flux des demandes professionnelles
  Stream<List<ProApplication>> streamProApplications() {
    if (_isFirebaseInitialized) {
      return FirebaseFirestore.instance
          .collection('pro_applications')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          return ProApplication.fromMap(doc.data(), doc.id);
        }).toList();
      });
    } else {
      return Stream.value(List<ProApplication>.from(_localProApplications));
    }
  }

  /// 5. Valider / Rejeter professionnel (avec envoi d'email automatique)
  Future<bool> approveProApplication(String appId, {ProApplication? proApp}) async {
    try {
      ProApplication? target = proApp;

      if (_isFirebaseInitialized) {
        // Si les données du pro ne sont pas fournies, les charger depuis Firestore
        if (target == null) {
          final doc = await FirebaseFirestore.instance
              .collection('pro_applications')
              .doc(appId)
              .get();
          if (doc.exists) {
            target = ProApplication.fromMap(doc.data()!, doc.id);
          }
        }

        // 1. Mettre à jour pro_applications
        await FirebaseFirestore.instance
            .collection('pro_applications')
            .doc(appId)
            .update({
          'status': 'valide',
          'approvedAt': FieldValue.serverTimestamp(),
        });

        // 2. Mettre à jour users pour permettre la connexion
        if (target != null) {
          final q = await FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: target.email.trim().toLowerCase())
              .limit(1)
              .get();
          if (q.docs.isNotEmpty) {
            await q.docs.first.reference.update({
              'isApproved': true,
              'status': 'valide',
              'approvedAt': FieldValue.serverTimestamp(),
            });
          }

          // 3. Envoyer l'email d'acceptation au professionnel
          await EmailService.sendProApprovedEmail(
            toEmail: target.email,
            proName: target.fullName,
            serviceType: target.serviceType,
          );

          // 4. Notification in-app pour le pro (visible dans son écran Demandes)
          try {
            final proUid = q.docs.isNotEmpty ? q.docs.first.id : null;
            if (proUid != null) {
              await FirebaseFirestore.instance.collection('notifications').add({
                'recipientId': proUid,
                'type': 'pro_application_approved',
                'title': '🎉 Candidature acceptée !',
                'body': 'Félicitations ${target.fullName} ! Votre compte professionnel DAR PLUS a été validé. Vous pouvez maintenant vous connecter.',
                'isRead': false,
                'createdAt': FieldValue.serverTimestamp(),
              });
            }
          } catch (e) {
            debugPrint('Notif pro approbation non envoyée: $e');
          }

          await logSecurityEvent(
            action: 'Validation Professionnel',
            actorEmail: 'Administrateur',
            target: target.email,
            details: 'Validation de ${target.fullName} (${target.serviceType})',
            severity: 'info',
          );
        }

        return true;
      } else {
        final index = _localProApplications.indexWhere((p) => p.id == appId);
        if (index != -1) {
          final old = _localProApplications[index];
          _localProApplications[index] = ProApplication(
            id: old.id,
            fullName: old.fullName,
            phone: old.phone,
            email: old.email,
            cin: old.cin,
            serviceType: old.serviceType,
            status: 'valide',
            createdAt: old.createdAt,
            notes: old.notes,
          );
          if (_localUsers.containsKey(old.email.toLowerCase())) {
            _localUsers[old.email.toLowerCase()]!['isApproved'] = true;
            _localUsers[old.email.toLowerCase()]!['status'] = 'valide';
          }

          // Envoyer l'email d'acceptation au professionnel (fallback local)
          try {
            await EmailService.sendProApprovedEmail(
              toEmail: old.email,
              proName: old.fullName,
              serviceType: old.serviceType,
            );
          } catch (_) {}
        }
        return true;
      }
    } catch (e) {
      debugPrint('Erreur validation: $e');
      return false;
    }
  }

  Future<bool> rejectProApplication(
    String appId, {
    required String reason,
    ProApplication? proApp,
  }) async {
    try {
      ProApplication? target = proApp;

      if (_isFirebaseInitialized) {
        if (target == null) {
          final doc = await FirebaseFirestore.instance
              .collection('pro_applications')
              .doc(appId)
              .get();
          if (doc.exists) {
            target = ProApplication.fromMap(doc.data()!, doc.id);
          }
        }

        // 1. Mettre à jour pro_applications
        await FirebaseFirestore.instance
            .collection('pro_applications')
            .doc(appId)
            .update({
          'status': 'refuse',
          'rejectionReason': reason.trim(),
          'rejectedAt': FieldValue.serverTimestamp(),
        });

        // 2. Mettre à jour users
        if (target != null) {
          final q = await FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: target.email.trim().toLowerCase())
              .limit(1)
              .get();
          if (q.docs.isNotEmpty) {
            await q.docs.first.reference.update({
              'isApproved': false,
              'status': 'refuse',
              'rejectionReason': reason.trim(),
              'rejectedAt': FieldValue.serverTimestamp(),
            });
          }

          // 3. Envoyer l'email de rejet avec le motif au professionnel
          await EmailService.sendProRejectedEmail(
            toEmail: target.email,
            proName: target.fullName,
            reason: reason.trim(),
          );

          // 4. Notification in-app pour le pro
          try {
            final proUid = q.docs.isNotEmpty ? q.docs.first.id : null;
            if (proUid != null) {
              await FirebaseFirestore.instance.collection('notifications').add({
                'recipientId': proUid,
                'type': 'pro_application_rejected',
                'title': '❌ Candidature non retenue',
                'body': 'Votre candidature DAR PLUS n\'a pas été retenue. Motif : ${reason.trim()}',
                'isRead': false,
                'createdAt': FieldValue.serverTimestamp(),
              });
            }
          } catch (e) {
            debugPrint('Notif pro rejet non envoyée: $e');
          }

          await logSecurityEvent(
            action: 'Refus Professionnel',
            actorEmail: 'Administrateur',
            target: target.email,
            details: 'Motif de rejet : ${reason.trim()}',
            severity: 'warning',
          );
        }

        return true;
      } else {
        final index = _localProApplications.indexWhere((p) => p.id == appId);
        if (index != -1) {
          final old = _localProApplications[index];
          _localProApplications[index] = ProApplication(
            id: old.id,
            fullName: old.fullName,
            phone: old.phone,
            email: old.email,
            cin: old.cin,
            serviceType: old.serviceType,
            status: 'refuse',
            createdAt: old.createdAt,
            notes: old.notes,
            rejectionReason: reason.trim(),
          );
          if (_localUsers.containsKey(old.email.toLowerCase())) {
            _localUsers[old.email.toLowerCase()]!['isApproved'] = false;
            _localUsers[old.email.toLowerCase()]!['status'] = 'refuse';
            _localUsers[old.email.toLowerCase()]!['rejectionReason'] = reason.trim();
          }
        }
        return true;
      }
    } catch (e) {
      debugPrint('Erreur rejet: $e');
      return false;
    }
  }

  /// 6. Connexion unifiée
  Future<Map<String, dynamic>> signInWithEmailAndPassword({
    required String email,
    required String password,
    String? selectedRole,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanPassword = password.trim();

    // Accès d'urgence Super Admin (credentials lus depuis .env)
    if (cleanEmail == _adminRootEmail &&
        (cleanPassword == _adminRootPass || cleanPassword == _adminRootFallback)) {
      return {
        'success': true,
        'role': 'super_admin',
        'uid': 'root_admin_uid',
        'fullName': 'Super Admin DAR PLUS',
        'email': _adminRootEmail,
        'phone': '+216 71 000 000',
        'mustChangePassword': false,
        'message': 'Bienvenue sur le panneau d\'administration DAR PLUS.',
      };
    }

    try {
      if (_isFirebaseInitialized) {
        try {
          final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: cleanEmail,
            password: cleanPassword,
          );

          final uid = cred.user!.uid;
          final userDoc =
              await FirebaseFirestore.instance.collection('users').doc(uid).get();

          if (userDoc.exists) {
            final data = userDoc.data()!;
            final role = cleanEmail == 'admin@darplus.tn'
                ? 'super_admin'
                : ((data['role'] as String?)?.toLowerCase() ?? 'client');
            final isApproved = data['isApproved'] ?? true;
            final status = data['status'] ?? (isApproved ? 'valide' : 'en_attente');

            if (role == 'professionnel') {
              if (status == 'en_attente' || !isApproved) {
                await FirebaseAuth.instance.signOut();
                return {
                  'success': false,
                  'code': 'PENDING_APPROVAL',
                  'message':
                      'Votre compte professionnel est en cours d\'examen par l\'administrateur DAR PLUS.',
                };
              }
              if (status == 'refuse') {
                await FirebaseAuth.instance.signOut();
                return {
                  'success': false,
                  'code': 'REJECTED',
                  'message':
                      'Votre demande de compte professionnel a été refusée.',
                };
              }
            }

            return {
              'success': true,
              'role': role,
              'uid': uid,
              'fullName': data['fullName'] ?? (cleanEmail == 'admin@darplus.tn' ? 'Super Admin DAR PLUS' : cleanEmail.split('@').first),
              'email': data['email'] ?? cleanEmail,
              'phone': data['phone'] ?? '',
              'serviceType': data['serviceType'] ?? 'Plomberie & Sanitaire',
              'mustChangePassword': data['mustChangePassword'] == true,
              'message': 'Connexion réussie !',
            };
          } else {
            final effectiveRole = cleanEmail == 'admin@darplus.tn'
                ? 'super_admin'
                : (selectedRole ?? (cleanEmail.contains('admin') ? 'admin' : 'client'));
            return {
              'success': true,
              'role': effectiveRole,
              'uid': uid,
              'fullName': cleanEmail == 'admin@darplus.tn' ? 'Super Admin DAR PLUS' : cleanEmail.split('@').first,
              'email': cleanEmail,
              'phone': '',
              'message': 'Connexion réussie !',
            };
          }
        } on FirebaseAuthException catch (authErr) {
          // Gestion du mot de passe temporaire pour les nouveaux admins créés
          try {
            final q = await FirebaseFirestore.instance
                .collection('users')
                .where('email', isEqualTo: cleanEmail)
                .limit(1)
                .get();

            if (q.docs.isNotEmpty) {
              final data = q.docs.first.data();
              final storedTemp = data['tempPassword'] as String?;
              final storedPass = data['password'] as String?;
              final bool mustChange = data['mustChangePassword'] == true;
              final role = cleanEmail == 'admin@darplus.tn'
                  ? 'super_admin'
                  : ((data['role'] as String?)?.toLowerCase() ?? 'admin');

              if ((storedTemp != null && storedTemp == cleanPassword) ||
                  (storedPass != null && storedPass == cleanPassword) ||
                  (mustChange && (storedTemp == null || storedTemp == cleanPassword))) {
                return {
                  'success': true,
                  'role': role,
                  'uid': q.docs.first.id,
                  'fullName': data['fullName'] ?? cleanEmail.split('@').first,
                  'email': data['email'] ?? cleanEmail,
                  'phone': data['phone'] ?? '',
                  'serviceType': data['serviceType'] ?? 'Plomberie & Sanitaire',
                  'mustChangePassword': true,
                  'message': 'Connexion réussie ! Veuillez définir votre mot de passe.',
                };
              }
            }
          } catch (_) {}

          // Cache local fallback
          if (_localUsers.containsKey(cleanEmail)) {
            final local = _localUsers[cleanEmail]!;
            if (local['password'] == cleanPassword || local['mustChangePassword'] == true) {
              return {
                'success': true,
                'role': cleanEmail == 'admin@darplus.tn' ? 'super_admin' : (local['role'] ?? 'admin'),
                'uid': local['uid'] ?? 'local_uid',
                'fullName': local['fullName'] ?? cleanEmail.split('@').first,
                'email': cleanEmail,
                'phone': local['phone'] ?? '',
                'mustChangePassword': local['mustChangePassword'] == true,
                'message': 'Connexion réussie !',
              };
            }
          }

          return {
            'success': false,
            'message': _getAuthErrorMessage(authErr.code),
          };
        }
      } else {
        // Mode local
        await Future.delayed(const Duration(milliseconds: 300));
        if (_localUsers.containsKey(cleanEmail)) {
          final local = _localUsers[cleanEmail]!;
          return {
            'success': true,
            'role': local['role'] ?? 'admin',
            'fullName': local['fullName'] ?? cleanEmail.split('@').first,
            'email': cleanEmail,
            'phone': local['phone'] ?? '',
            'mustChangePassword': local['mustChangePassword'] == true,
            'message': 'Connexion réussie !',
          };
        }
        return {
          'success': true,
          'role': cleanEmail == 'admin@darplus.tn'
              ? 'super_admin'
              : (selectedRole ?? (cleanEmail.contains('admin') ? 'admin' : 'client')),
          'fullName': cleanEmail == 'admin@darplus.tn' ? 'Super Admin DAR PLUS' : cleanEmail.split('@').first,
          'email': cleanEmail,
          'message': 'Connexion réussie (Mode Démo).',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Erreur de connexion : $e',
      };
    }
  }

  /// 6.1 Connexion avec Google
  Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      if (_isFirebaseInitialized) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');

        // Essayer d'abord de récupérer un résultat de redirect en attente
        // (cas où l'utilisateur revenait d'un redirect précédent)
        UserCredential? cred;
        if (kIsWeb) {
          try {
            final redirectResult = await FirebaseAuth.instance.getRedirectResult();
            if (redirectResult.user != null) {
              cred = redirectResult;
            }
          } catch (_) {}
        }

        // Si pas de résultat de redirect, utiliser signInWithPopup
        cred ??= await FirebaseAuth.instance.signInWithPopup(googleProvider);

        final user = cred.user;

        if (user == null) {
          return {
            'success': false,
            'message': 'Connexion Google annulée.',
          };
        }

        final uid = user.uid;
        final cleanEmail = (user.email ?? '').trim().toLowerCase();
        final fullName = (user.displayName != null && user.displayName!.isNotEmpty)
            ? user.displayName!
            : (cleanEmail.isNotEmpty ? cleanEmail.split('@').first : 'Utilisateur');

        // Vérifier si l'utilisateur existe déjà dans Firestore
        final userDoc =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();

        if (userDoc.exists) {
          final data = userDoc.data()!;
          final role = (data['role'] as String?)?.toLowerCase() ?? 'client';
          final isApproved = data['isApproved'] ?? true;
          final status = data['status'] ?? (isApproved ? 'valide' : 'en_attente');

          if (role == 'professionnel') {
            if (status == 'en_attente' || !isApproved) {
              await FirebaseAuth.instance.signOut();
              return {
                'success': false,
                'code': 'PENDING_APPROVAL',
                'message':
                    'Votre compte professionnel est en cours d\'examen par l\'administrateur DAR PLUS.',
              };
            }
            if (status == 'refuse') {
              await FirebaseAuth.instance.signOut();
              return {
                'success': false,
                'code': 'REJECTED',
                'message':
                    'Votre demande de compte professionnel a été refusée.',
              };
            }
          }

          return {
            'success': true,
            'role': role,
            'uid': uid,
            'fullName': data['fullName'] ?? fullName,
            'email': data['email'] ?? cleanEmail,
            'phone': data['phone'] ?? (user.phoneNumber ?? ''),
            'serviceType': data['serviceType'] ?? 'Plomberie & Sanitaire',
            'mustChangePassword': false,
            'message': 'Bienvenue $fullName !',
          };
        } else {
          // Nouvel utilisateur via Google -> Par défaut rôle 'client'
          await FirebaseFirestore.instance.collection('users').doc(uid).set({
            'uid': uid,
            'fullName': fullName,
            'email': cleanEmail,
            'phone': user.phoneNumber ?? '',
            'photoUrl': user.photoURL ?? '',
            'role': 'client',
            'isApproved': true,
            'isActive': true,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          return {
            'success': true,
            'role': 'client',
            'uid': uid,
            'fullName': fullName,
            'email': cleanEmail,
            'phone': user.phoneNumber ?? '',
            'mustChangePassword': false,
            'message': 'Bienvenue sur DAR PLUS, $fullName !',
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Connexion non disponible hors ligne.',
        };
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user') {
        return {
          'success': false,
          'message': 'La fenêtre de connexion Google a été fermée.',
        };
      } else if (e.code == 'account-exists-with-different-credential') {
        return {
          'success': false,
          'message': 'Un compte existe déjà avec cette adresse email.',
        };
      }
      return {
        'success': false,
        'message': _getAuthErrorMessage(e.code),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Erreur lors de la connexion Google : $e',
      };
    }
  }

  /// 7. Profil utilisateur
  Future<Map<String, dynamic>?> getCurrentUserData() async {
    try {
      if (_isFirebaseInitialized) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
          if (doc.exists) {
            return doc.data();
          }
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> updateUserField(String uid, String field, dynamic value) async {
    try {
      if (_isFirebaseInitialized) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({field: value});
      }
      // Update local cache
      for (final key in _localUsers.keys) {
        if (_localUsers[key]!['id'] == uid || _localUsers[key]!['uid'] == uid) {
          _localUsers[key]![field] = value;
          break;
        }
      }
    } catch (_) {}
  }

  Future<bool> updateCurrentUserData({
    String? fullName,
    String? phone,
    String? email,
    String? photoBase64,
    String? photoUrl,
  }) async {
    try {
      if (_isFirebaseInitialized) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final Map<String, dynamic> updates = {
            'updatedAt': FieldValue.serverTimestamp(),
          };
          if (fullName != null) {
            updates['fullName'] = fullName.trim();
            try {
              await user.updateDisplayName(fullName.trim());
            } catch (_) {}
          }
          if (phone != null) updates['phone'] = phone.trim();
          if (email != null) updates['email'] = email.trim();
          if (photoBase64 != null) updates['photoBase64'] = photoBase64;
          if (photoUrl != null) {
            updates['photoUrl'] = photoUrl;
            // Clear old base64 data when a proper URL is set
            updates['photoBase64'] = FieldValue.delete();
            try {
              await user.updatePhotoURL(photoUrl);
            } catch (_) {}
          }

          await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
                updates,
                SetOptions(merge: true),
              );
          return true;
        }
      }
      return true;
    } catch (e) {
      debugPrint('Erreur mise à jour profil: $e');
      return false;
    }
  }

  /// Upload profile image to Firebase Storage and return download URL
  Future<String?> uploadProfileImage(File imageFile) async {
    try {
      if (!_isFirebaseInitialized) return null;
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_photos')
          .child('${user.uid}.jpg');

      // Upload with metadata
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'uploadedBy': user.uid},
      );

      await storageRef.putFile(imageFile, metadata);
      final downloadUrl = await storageRef.getDownloadURL();

      // Update user document with the URL
      await updateCurrentUserData(photoUrl: downloadUrl);

      return downloadUrl;
    } catch (e) {
      debugPrint('Erreur upload image profil: $e');
      return null;
    }
  }

  /// 8. Gestion des utilisateurs (Tableau Admin)
  Stream<List<Map<String, dynamic>>> streamUsers() {
    if (_isFirebaseInitialized) {
      return FirebaseFirestore.instance
          .collection('users')
          .snapshots()
          .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
    } else {
      return Stream.value(_localUsers.values.toList());
    }
  }

  Future<bool> toggleUserStatus(String uid, [dynamic arg2, dynamic arg3]) async {
    try {
      String? email;
      bool? newStatus;
      if (arg2 is String) {
        email = arg2;
      }
      if (arg3 is bool) {
        newStatus = !arg3;
      } else if (arg2 is bool) {
        newStatus = !arg2;
      }

      // Protection inviolable du Super Admin racine
      if (email != null && email.trim().toLowerCase() == 'admin@darplus.tn') {
        debugPrint('Action refusée : le Super Admin principal ne peut pas être désactivé.');
        return false;
      }

      if (_isFirebaseInitialized) {
        if (newStatus != null) {
          await FirebaseFirestore.instance.collection('users').doc(uid).update({
            'isActive': newStatus,
          });
        }
      }

      if (email != null && _localUsers.containsKey(email.trim().toLowerCase())) {
        _localUsers[email.trim().toLowerCase()]!['isActive'] = newStatus;
      }

      await logSecurityEvent(
        action: newStatus == true ? 'Réactivation Utilisateur' : 'Suspension Utilisateur',
        actorEmail: 'Administrateur',
        target: email ?? uid,
        details: 'Statut du compte passé à : ${newStatus == true ? "Actif" : "Suspendu"}',
        severity: newStatus == true ? 'info' : 'warning',
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteUser(String uid, [String? email]) async {
    try {
      final cleanEmail = (email ?? '').trim().toLowerCase();
      // Protection inviolable du Super Admin racine
      if (cleanEmail == 'admin@darplus.tn') {
        debugPrint('Action refusée : le Super Admin principal ne peut pas être supprimé.');
        return false;
      }

      if (_isFirebaseInitialized) {
        await FirebaseFirestore.instance.collection('users').doc(uid).delete();
      }

      if (cleanEmail.isNotEmpty && _localUsers.containsKey(cleanEmail)) {
        _localUsers.remove(cleanEmail);
      }

      await logSecurityEvent(
        action: 'Suppression Utilisateur',
        actorEmail: 'Super Admin',
        target: cleanEmail.isNotEmpty ? cleanEmail : uid,
        details: 'Compte utilisateur définitivement supprimé',
        severity: 'critical',
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  /// 8.1 Modification du rôle utilisateur (Super Admin uniquement)
  Future<bool> updateUserRole({
    required String uid,
    required String email,
    required String newRole,
    String? actorEmail,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    // Le Super Admin principal ne peut jamais être rétrogradé
    if (cleanEmail == 'admin@darplus.tn' && newRole != 'super_admin') {
      return false;
    }

    try {
      if (_isFirebaseInitialized) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'role': newRole,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (_localUsers.containsKey(cleanEmail)) {
        _localUsers[cleanEmail]!['role'] = newRole;
      }

      await logSecurityEvent(
        action: 'Attribution de Rôle',
        actorEmail: actorEmail ?? 'Super Admin',
        target: cleanEmail,
        details: 'Rôle modifié vers : $newRole',
        severity: 'warning',
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String?> getUserRole(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail == 'admin@darplus.tn') return 'super_admin';
    if (_localUsers.containsKey(cleanEmail)) {
      return _localUsers[cleanEmail]!['role'] as String?;
    }
    if (_isFirebaseInitialized) {
      try {
        final q = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: cleanEmail)
            .limit(1)
            .get();
        if (q.docs.isNotEmpty) {
          return q.docs.first.data()['role'] as String?;
        }
      } catch (_) {}
    }
    return null;
  }

  /// 8.2 Journaux de sécurité & Audit (Super Admin / Admin)
  Future<void> logSecurityEvent({
    required String action,
    required String actorEmail,
    required String target,
    String? details,
    String severity = 'info', // 'info', 'warning', 'critical'
  }) async {
    final logData = {
      'id': 'log_${DateTime.now().millisecondsSinceEpoch}',
      'action': action,
      'actorEmail': actorEmail,
      'target': target,
      'details': details ?? '',
      'severity': severity,
      'timestamp': DateTime.now(),
    };

    _localSecurityLogs.insert(0, logData);

    if (_isFirebaseInitialized) {
      try {
        await FirebaseFirestore.instance.collection('security_logs').add({
          ...logData,
          'timestamp': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }
  }

  Stream<List<Map<String, dynamic>>> streamSecurityLogs({bool isSuperAdmin = false}) {
    if (_isFirebaseInitialized) {
      return FirebaseFirestore.instance
          .collection('security_logs')
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map((snapshot) {
        final docs = snapshot.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        if (isSuperAdmin) {
          return docs;
        } else {
          // Admin standard : vue limitée (masque les événements de gestion d'admin et critiques)
          return docs.where((l) =>
              l['severity'] != 'critical' &&
              l['action'] != 'Création Administrateur' &&
              l['action'] != 'Attribution de Rôle' &&
              l['action'] != 'Modification Paramètres Globaux').toList();
        }
      });
    } else {
      final list = isSuperAdmin
          ? _localSecurityLogs
          : _localSecurityLogs.where((l) =>
              l['severity'] != 'critical' &&
              l['action'] != 'Création Administrateur' &&
              l['action'] != 'Attribution de Rôle' &&
              l['action'] != 'Modification Paramètres Globaux').toList();
      return Stream.value(list);
    }
  }

  /// 8.3 Paramètres globaux de la plateforme (Super Admin)
  Stream<Map<String, dynamic>> streamGlobalSettings() {
    if (_isFirebaseInitialized) {
      return FirebaseFirestore.instance
          .collection('settings')
          .doc('global')
          .snapshots()
          .map((doc) => doc.exists ? (doc.data() ?? _localGlobalSettings) : _localGlobalSettings);
    } else {
      return Stream.value(_localGlobalSettings);
    }
  }

  Future<bool> updateGlobalSettings(Map<String, dynamic> newSettings, {String? actorEmail}) async {
    _localGlobalSettings.addAll(newSettings);
    if (_isFirebaseInitialized) {
      try {
        await FirebaseFirestore.instance
            .collection('settings')
            .doc('global')
            .set(_localGlobalSettings, SetOptions(merge: true));
      } catch (_) {
        return false;
      }
    }

    await logSecurityEvent(
      action: 'Modification Paramètres Globaux',
      actorEmail: actorEmail ?? 'Super Admin',
      target: 'Configuration système',
      details: 'Mise à jour des paramètres système',
      severity: 'warning',
    );

    return true;
  }

  /// 9. Modification du mot de passe
  Future<Map<String, dynamic>> changePassword({
    String currentPassword = '',
    required String newPassword,
  }) async {
    final cleanNewPassword = newPassword.trim();
    if (cleanNewPassword.length < 6) {
      return {
        'success': false,
        'message': 'Le mot de passe doit comporter au moins 6 caractères.',
      };
    }

    try {
      if (_isFirebaseInitialized) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null && user.email != null) {
          if (currentPassword.isNotEmpty) {
            try {
              final credential = EmailAuthProvider.credential(
                email: user.email!,
                password: currentPassword.trim(),
              );
              await user.reauthenticateWithCredential(credential);
            } on FirebaseAuthException catch (_) {
              return {
                'success': false,
                'message': 'Le mot de passe actuel est incorrect.',
              };
            }
          }

          await user.updatePassword(cleanNewPassword);

          try {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .update({
              'password': cleanNewPassword,
              'tempPassword': FieldValue.delete(),
              'mustChangePassword': false,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          } catch (_) {}

          final emailKey = user.email!.toLowerCase();
          if (_localUsers.containsKey(emailKey)) {
            _localUsers[emailKey]!['password'] = cleanNewPassword;
            _localUsers[emailKey]!['mustChangePassword'] = false;
          }

          return {
            'success': true,
            'message': 'Votre mot de passe a été modifié avec succès !',
          };
        }
      }

      await Future.delayed(const Duration(milliseconds: 300));
      return {
        'success': true,
        'message': 'Votre mot de passe a été modifié avec succès !',
      };
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        return {
          'success': false,
          'message': 'Veuillez vous reconnecter avant de changer votre mot de passe.',
        };
      }
      return {
        'success': false,
        'message': _getAuthErrorMessage(e.code),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Erreur : $e',
      };
    }
  }

  Future<Map<String, dynamic>> updatePasswordDirectly(
    String newPassword, {
    String? email,
  }) async {
    final cleanNewPassword = newPassword.trim();
    if (cleanNewPassword.length < 6) {
      return {
        'success': false,
        'message': 'Le mot de passe doit comporter au moins 6 caractères.',
      };
    }

    try {
      if (_isFirebaseInitialized) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          try {
            await user.updatePassword(cleanNewPassword);
          } catch (_) {}
          try {
            await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
              'password': cleanNewPassword,
              'tempPassword': FieldValue.delete(),
              'mustChangePassword': false,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          } catch (_) {}
        } else if (email != null && email.isNotEmpty) {
          final cleanEmail = email.trim().toLowerCase();
          final q = await FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: cleanEmail)
              .limit(1)
              .get();
          if (q.docs.isNotEmpty) {
            await q.docs.first.reference.update({
              'password': cleanNewPassword,
              'tempPassword': FieldValue.delete(),
              'mustChangePassword': false,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
          try {
            await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: cleanEmail,
              password: cleanNewPassword,
            );
          } catch (_) {}
        }
      }

      if (email != null) {
        final cleanEmail = email.trim().toLowerCase();
        if (_localUsers.containsKey(cleanEmail)) {
          _localUsers[cleanEmail]!['password'] = cleanNewPassword;
          _localUsers[cleanEmail]!['mustChangePassword'] = false;
        }
      }

      return {
        'success': true,
        'message': 'Votre mot de passe a été défini avec succès !',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Erreur : $e',
      };
    }
  }

  /// 10. Déconnexion
  Future<void> signOut() async {
    try {
      if (_isFirebaseInitialized) {
        await FirebaseAuth.instance.signOut();
      }
    } catch (_) {}
  }

  /// 11. Réinitialisation mot de passe via EmailJS (lien Firebase Auth REST API)
  Future<Map<String, dynamic>> resetPassword(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    try {
      // ── Étape 1 : Générer le lien via Firebase Auth REST API ──────────────
      // POST https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode
      // Retourne un lien oobLink que l'on inclut dans l'email EmailJS
      final apiKey = dotenv.env['FIREBASE_API_KEY'] ?? '';
      String? resetLink;
      String userName = cleanEmail.split('@').first;

      if (_isFirebaseInitialized && apiKey.isNotEmpty) {
        try {
          final resp = await http.post(
            Uri.parse(
                'https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=$apiKey'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'requestType': 'PASSWORD_RESET',
              'email': cleanEmail,
            }),
          );
          if (resp.statusCode == 200) {
            final data = jsonDecode(resp.body) as Map<String, dynamic>;
            resetLink = data['oobLink'] as String?;
          } else {
            final err = jsonDecode(resp.body) as Map<String, dynamic>;
            final code = (err['error'] as Map?)?['message'] ?? '';
            if (code == 'EMAIL_NOT_FOUND') {
              return {
                'success': false,
                'message': 'Aucun compte trouvé avec cette adresse e-mail.',
              };
            }
          }
        } catch (_) {}

        // Récupérer le nom depuis Firestore (optionnel)
        try {
          final q = await FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: cleanEmail)
              .limit(1)
              .get();
          if (q.docs.isNotEmpty) {
            userName = (q.docs.first.data()['fullName'] as String?) ?? userName;
          }
        } catch (_) {}
      }

      // ── Étape 2 : Envoyer l'email via EmailJS avec le lien ────────────────
      if (resetLink != null && resetLink.isNotEmpty) {
        final sent = await EmailService.sendPasswordResetWithLink(
          toEmail: cleanEmail,
          userName: userName,
          resetLink: resetLink,
        );
        if (sent) {
          return {
            'success': true,
            'message': 'Un email de réinitialisation a été envoyé à $cleanEmail.',
          };
        }
      }

      // Fallback : Firebase envoie son propre email
      if (_isFirebaseInitialized) {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: cleanEmail);
        return {
          'success': true,
          'message': 'Un lien de réinitialisation a été envoyé à $cleanEmail. Vérifiez votre boîte mail.',
        };
      }

      return {
        'success': false,
        'message': 'Impossible d\'envoyer l\'email de réinitialisation.',
      };
    } on FirebaseAuthException catch (e) {
      return {
        'success': false,
        'message': 'Erreur : ${e.message ?? e.code}',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Erreur lors de l\'envoi : $e',
      };
    }
  }

  /// 12. Gestion des Catégories de Métiers (Firestore Réel)
  static final List<Map<String, dynamic>> _defaultCategories = [
    {
      'id': 'cat_1',
      'name': 'Plomberie',
      'pros': 48,
      'isActive': true,
      'iconCode': Icons.build_rounded.codePoint,
      'bgColorHex': 0xFFE8F0FE,
      'iconColorHex': 0xFF1E40AF,
    },
    {
      'id': 'cat_2',
      'name': 'Électricité',
      'pros': 41,
      'isActive': true,
      'iconCode': Icons.bolt_rounded,
      'bgColorHex': 0xFFFEF3C7,
      'iconColorHex': 0xFFD97706,
    },
    {
      'id': 'cat_3',
      'name': 'Nettoyage',
      'pros': 63,
      'isActive': true,
      'iconCode': Icons.auto_awesome_rounded,
      'bgColorHex': 0xFFD7F3EA,
      'iconColorHex': 0xFF0D544E,
    },
    {
      'id': 'cat_4',
      'name': 'Climatisation',
      'pros': 22,
      'isActive': true,
      'iconCode': Icons.ac_unit_rounded,
      'bgColorHex': 0xFFE0EAFA,
      'iconColorHex': 0xFF2563EB,
    },
    {
      'id': 'cat_5',
      'name': 'Peinture',
      'pros': 17,
      'isActive': true,
      'iconCode': Icons.format_paint_rounded,
      'bgColorHex': 0xFFFCE7F3,
      'iconColorHex': 0xFFBE185D,
    },
    {
      'id': 'cat_6',
      'name': 'Serrurerie',
      'pros': 12,
      'isActive': false,
      'iconCode': Icons.key_rounded,
      'bgColorHex': 0xFFF1F5F9,
      'iconColorHex': 0xFF64748B,
    },
    {
      'id': 'cat_7',
      'name': 'Bricolage',
      'pros': 35,
      'isActive': true,
      'iconCode': Icons.handyman_rounded,
      'bgColorHex': 0xFFFEF3C7,
      'iconColorHex': 0xFFB45309,
    },
    {
      'id': 'cat_8',
      'name': 'Jardinage',
      'pros': 19,
      'isActive': true,
      'iconCode': Icons.yard_rounded,
      'bgColorHex': 0xFFDCFCE7,
      'iconColorHex': 0xFF15803D,
    },
  ];

  Stream<List<Map<String, dynamic>>> streamCategories() {
    if (_isFirebaseInitialized) {
      return FirebaseFirestore.instance
          .collection('categories')
          .snapshots()
          .asyncMap((snapshot) async {
        if (snapshot.docs.isEmpty && !_categoriesSeeded) {
          _categoriesSeeded = true;
          for (final cat in _defaultCategories) {
            await FirebaseFirestore.instance
                .collection('categories')
                .doc(cat['id'] as String)
                .set({
              'id': cat['id'],
              'name': cat['name'],
              'pros': cat['pros'],
              'isActive': cat['isActive'],
              'iconCode': cat['iconCode'],
              'bgColorHex': cat['bgColorHex'],
              'iconColorHex': cat['iconColorHex'],
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
          return _defaultCategories.map((c) => _mapToCategoryModel(c)).toList();
        }

        // Compter les pros validés par serviceType en une seule requête
        final Map<String, int> proCountByService = {};
        try {
          final prosSnap = await FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'professionnel')
              .where('isApproved', isEqualTo: true)
              .get();
          for (final doc in prosSnap.docs) {
            final serviceType = (doc.data()['serviceType'] as String? ?? '').trim();
            if (serviceType.isNotEmpty) {
              proCountByService[serviceType] = (proCountByService[serviceType] ?? 0) + 1;
            }
          }
        } catch (_) {}

        return snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          final catName = (data['name'] as String? ?? '').trim();
          // Recherche insensible à la casse pour matcher nom catégorie ↔ serviceType
          final realCount = proCountByService.entries
              .where((e) => e.key.toLowerCase() == catName.toLowerCase() ||
                            e.key.toLowerCase().contains(catName.toLowerCase()) ||
                            catName.toLowerCase().contains(e.key.toLowerCase()))
              .fold<int>(0, (acc, e) => acc + e.value);
          data['pros'] = realCount > 0 ? realCount : (data['pros'] ?? 0);
          return _mapToCategoryModel(data);
        }).toList();
      });
    } else {
      if (_localCategories.isEmpty) {
        _localCategories.addAll(_defaultCategories.map((c) => _mapToCategoryModel(c)));
      }
      return Stream.value(List<Map<String, dynamic>>.from(_localCategories));
    }
  }

  Map<String, dynamic> _mapToCategoryModel(Map<String, dynamic> data) {
    final iconCode = data['iconCode'] as int? ?? Icons.category_rounded.codePoint;
    final bgColorHex = data['bgColorHex'] as int? ?? 0xFFE8F0FE;
    final iconColorHex = data['iconColorHex'] as int? ?? 0xFF0D544E;

    return {
      'id': data['id'] ?? 'cat_${DateTime.now().millisecondsSinceEpoch}',
      'name': data['name'] ?? 'Catégorie',
      'pros': data['pros'] is int ? data['pros'] : (int.tryParse('${data['pros']}') ?? 0),
      'isActive': data['isActive'] ?? true,
      // ignore: non_const_argument_for_const_parameter
      'icon': IconData(iconCode, fontFamily: 'MaterialIcons'),
      'bgColor': Color(bgColorHex),
      'iconColor': Color(iconColorHex),
    };
  }

  Future<bool> addCategory({
    required String name,
    int pros = 0,
    bool isActive = true,
    IconData? icon,
    Color? bgColor,
    Color? iconColor,
  }) async {
    final String catId = 'cat_${DateTime.now().millisecondsSinceEpoch}';
    final iconData = icon ?? Icons.handyman_rounded;
    final bg = bgColor ?? const Color(0xFFE8F0FE);
    final ic = iconColor ?? const Color(0xFF1E40AF);

    try {
      if (_isFirebaseInitialized) {
        await FirebaseFirestore.instance.collection('categories').doc(catId).set({
          'id': catId,
          'name': name.trim(),
          'pros': pros,
          'isActive': isActive,
          'iconCode': iconData.codePoint,
          // ignore: deprecated_member_use
          'bgColorHex': bg.value,
          // ignore: deprecated_member_use
          'iconColorHex': ic.value,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      _localCategories.add({
        'id': catId,
        'name': name.trim(),
        'pros': pros,
        'isActive': isActive,
        'icon': iconData,
        'bgColor': bg,
        'iconColor': ic,
      });

      return true;
    } catch (e) {
      debugPrint('Erreur addCategory: $e');
      return false;
    }
  }

  Future<bool> updateCategory(
    String id, {
    String? name,
    int? pros,
    bool? isActive,
  }) async {
    try {
      final Map<String, dynamic> updates = {};
      if (name != null) updates['name'] = name.trim();
      if (pros != null) updates['pros'] = pros;
      if (isActive != null) updates['isActive'] = isActive;
      updates['updatedAt'] = FieldValue.serverTimestamp();

      if (_isFirebaseInitialized) {
        await FirebaseFirestore.instance.collection('categories').doc(id).update(updates);
      }

      final index = _localCategories.indexWhere((c) => c['id'] == id);
      if (index != -1) {
        if (name != null) _localCategories[index]['name'] = name.trim();
        if (pros != null) _localCategories[index]['pros'] = pros;
        if (isActive != null) _localCategories[index]['isActive'] = isActive;
      }
      return true;
    } catch (e) {
      debugPrint('Erreur updateCategory: $e');
      return false;
    }
  }

  Future<bool> toggleCategoryStatus(String id, bool newStatus) async {
    return updateCategory(id, isActive: newStatus);
  }

  Future<bool> deleteCategory(String id) async {
    try {
      if (_isFirebaseInitialized) {
        await FirebaseFirestore.instance.collection('categories').doc(id).delete();
      }
      _localCategories.removeWhere((c) => c['id'] == id);
      return true;
    } catch (e) {
      debugPrint('Erreur deleteCategory: $e');
      return false;
    }
  }

  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Aucun compte associé à cette adresse e-mail.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Mot de passe incorrect.';
      case 'email-already-in-use':
        return 'Cette adresse e-mail est déjà associée à un compte.';
      case 'invalid-email':
        return 'Adresse e-mail invalide.';
      case 'weak-password':
        return 'Le mot de passe doit comporter au moins 6 caractères.';
      default:
        return 'Erreur d\'authentification ($code).';
    }
  }

  // ================= PARCOURS RECHERCHE, CATALOGUE & DÉTAIL PROS =================

  static final List<Map<String, dynamic>> _defaultPros = [
    {
      'id': 'pro_1',
      'name': 'Foued Trabelsi',
      'serviceType': 'Plomberie',
      'rating': 4.9,
      'reviewsCount': 124,
      'price': '35 TND/h',
      'priceValue': 35,
      'location': 'El Menzah 9',
      'distance': '1.2 km',
      'available': true,
      'avatarAsset': 'assets/images/slide_1_photo.png',
      'phone': '+216 98 123 456',
      'email': 'foued.plombier@gmail.com',
      'experienceYears': 12,
      'bio': 'Artisan plombier certifié avec 12 ans d\'expérience. Dépannage rapide 7j/7, recherche de fuites, débouchage et installation sanitaire.',
      'specialties': ['Débouchage', 'Chauffe-eau', 'Fuites d\'eau', 'Rénovation SDB'],
      'badges': ['Vérifié DAR+', 'Top Artisan', 'Garantie 6 mois'],
    },
    {
      'id': 'pro_2',
      'name': 'Karim Ben Ammar',
      'serviceType': 'Électricité',
      'rating': 4.8,
      'reviewsCount': 98,
      'price': '40 TND/h',
      'priceValue': 40,
      'location': 'La Marsa',
      'distance': '2.5 km',
      'available': true,
      'avatarAsset': 'assets/images/slide_2_photo.png',
      'phone': '+216 22 789 012',
      'email': 'karim.elec@gmail.com',
      'experienceYears': 8,
      'bio': 'Électricien qualifié pour vos installations et mises aux normes électriques. Diagnostic rapide et devis gratuit.',
      'specialties': ['Tableaux électriques', 'Court-circuit', 'Éclairage LED', 'Prises & Câblage'],
      'badges': ['Vérifié DAR+', 'Électricien Agréé'],
    },
    {
      'id': 'pro_3',
      'name': 'Sami Gharbi',
      'serviceType': 'Climatisation',
      'rating': 4.7,
      'reviewsCount': 76,
      'price': '50 TND/h',
      'priceValue': 50,
      'location': 'Ennasr 2',
      'distance': '3.1 km',
      'available': true,
      'avatarAsset': 'assets/images/slide_3_photo.png',
      'phone': '+216 55 345 678',
      'email': 'sami.clim@gmail.com',
      'experienceYears': 10,
      'bio': 'Spécialiste climatisation et froid. Entretien préventif, recharge gaz R410/R32 et installation multi-split.',
      'specialties': ['Entretien & Nettoyage', 'Recharge Fréon', 'Installation Split', 'Dépannage Urgent'],
      'badges': ['Vérifié DAR+', 'Intervention Express'],
    },
    {
      'id': 'pro_4',
      'name': 'Moncef Jaziri',
      'serviceType': 'Peinture',
      'rating': 4.6,
      'reviewsCount': 62,
      'price': '30 TND/h',
      'priceValue': 30,
      'location': 'Ariana Ville',
      'distance': '4.0 km',
      'available': false,
      'avatarAsset': 'assets/images/slide_1_photo.png',
      'phone': '+216 20 555 444',
      'email': 'moncef.peinture@gmail.com',
      'experienceYears': 15,
      'bio': 'Artisan peintre en bâtiment, décoration intérieure et traitement anti-humidité. Travail soigné et finitions parfaites.',
      'specialties': ['Peinture Murale', 'Enduit & Ponçage', 'Anti-Humidité', 'Décoration Stuc'],
      'badges': ['Vérifié DAR+'],
    },
    {
      'id': 'pro_5',
      'name': 'Yassine Messaoudi',
      'serviceType': 'Menuiserie',
      'rating': 4.9,
      'reviewsCount': 110,
      'price': '45 TND/h',
      'priceValue': 45,
      'location': 'Carthage',
      'distance': '5.2 km',
      'available': true,
      'avatarAsset': 'assets/images/slide_2_photo.png',
      'phone': '+216 97 888 999',
      'email': 'yassine.bois@gmail.com',
      'experienceYears': 9,
      'bio': 'Menuisier ébéniste expérimenté. Conception de meubles sur mesure, réparation de portes, placards et parquets.',
      'specialties': ['Portes & Serrures', 'Placards sur mesure', 'Parquet', 'Cuisines'],
      'badges': ['Vérifié DAR+', 'Artisan d\'Or'],
    },
  ];

  /// Stream des professionnels avec filtres optionnels (catégorie, recherche textuelle, disponibilité)
  Stream<List<Map<String, dynamic>>> streamPros({
    String? category,
    String? searchQuery,
    bool? onlyAvailable,
    String? sortBy, // 'rating', 'price_asc', 'price_desc'
  }) {
    if (_isFirebaseInitialized) {
      return FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'professionnel')
          .where('isApproved', isEqualTo: true)
          .snapshots()
          .map((snapshot) {
        List<Map<String, dynamic>> list = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['fullName'] ?? 'Artisan',
            'serviceType': data['serviceType'] ?? 'Services divers',
            'rating': (data['rating'] is num) ? (data['rating'] as num).toDouble() : 4.8,
            'reviewsCount': data['reviewsCount'] ?? 15,
            'price': data['price'] ?? '35 TND/h',
            'priceValue': data['priceValue'] ?? 35,
            'location': data['location'] ?? 'Grand Tunis',
            'distance': data['distance'] ?? '2.0 km',
            'available': data['available'] ?? true,
            'phone': data['phone'] ?? '+216 -- --- ---',
            'email': data['email'] ?? '',
            'bio': data['bio'] ?? 'Professionnel vérifié et certifié par DAR PLUS.',
            'specialties': data['specialties'] ?? [data['serviceType'] ?? 'Artisan'],
            'badges': ['Vérifié DAR+'],
            'photoBase64': data['photoBase64'] ?? '',
          };
        }).toList();

        // Si Firestore est vide pour les pros, combiner avec les profils par défaut
        if (list.isEmpty) {
          list = List.from(_defaultPros);
        }

        return _applyFilters(list, category, searchQuery, onlyAvailable, sortBy);
      });
    }

    // Fallback Local
    return Stream.value(
      _applyFilters(List.from(_defaultPros), category, searchQuery, onlyAvailable, sortBy),
    );
  }

  List<Map<String, dynamic>> _applyFilters(
    List<Map<String, dynamic>> list,
    String? category,
    String? searchQuery,
    bool? onlyAvailable,
    String? sortBy,
  ) {
    var filtered = list;

    if (category != null && category.isNotEmpty && category.toLowerCase() != 'tous') {
      filtered = filtered
          .where((p) => (p['serviceType'] as String)
              .toLowerCase()
              .contains(category.toLowerCase()))
          .toList();
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      filtered = filtered.where((p) {
        final name = (p['name'] as String).toLowerCase();
        final type = (p['serviceType'] as String).toLowerCase();
        final bio = (p['bio'] as String? ?? '').toLowerCase();
        return name.contains(q) || type.contains(q) || bio.contains(q);
      }).toList();
    }

    if (onlyAvailable == true) {
      filtered = filtered.where((p) => p['available'] == true).toList();
    }

    if (sortBy == 'rating') {
      filtered.sort((a, b) => (b['rating'] as num).compareTo(a['rating'] as num));
    } else if (sortBy == 'price_asc') {
      filtered.sort((a, b) => (a['priceValue'] as num).compareTo(b['priceValue'] as num));
    } else if (sortBy == 'price_desc') {
      filtered.sort((a, b) => (b['priceValue'] as num).compareTo(a['priceValue'] as num));
    }

    return filtered;
  }

  // ================= GESTION RÉELLE DES RÉSERVATIONS (COLLECTION 'bookings') =================

  static final List<Map<String, dynamic>> _localBookings = [];

  /// Créer une vraie réservation dans Firestore
  Future<Map<String, dynamic>> createBooking({
    required String proId,
    required String proName,
    required String proPhone,
    required String serviceType,
    required String price,
    required String address,
    required String description,
    String? scheduledDate,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final clientId = user?.uid ?? 'client_anon';
      final clientEmail = user?.email ?? '';

      // Récupérer le nom réel du client depuis Firestore ou le profil local
      String clientName = 'Client';
      String clientPhone = '';
      final userData = await getCurrentUserData();
      if (userData != null) {
        clientName = userData['fullName'] as String? ?? 'Client';
        clientPhone = userData['phone'] as String? ?? '';
      }

      final bookingData = {
        'clientId': clientId,
        'clientName': clientName,
        'clientEmail': clientEmail,
        'clientPhone': clientPhone,
        'proId': proId,
        'proName': proName,
        'proPhone': proPhone,
        'serviceType': serviceType,
        'price': price,
        'address': address.trim(),
        'description': description.trim(),
        'scheduledDate': scheduledDate ?? 'Dès que possible',
        'status': 'en_attente', // 'en_attente', 'confirmee', 'terminee', 'annulee'
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (_isFirebaseInitialized) {
        final docRef = await FirebaseFirestore.instance.collection('bookings').add(bookingData);
        bookingData['id'] = docRef.id;
        _localBookings.insert(0, Map<String, dynamic>.from(bookingData));

        // Journal de sécurité
        await logSecurityEvent(
          action: 'CREATE_BOOKING',
          actorEmail: clientEmail.isNotEmpty ? clientEmail : 'Client',
          target: proName,
          details: 'Réservation $serviceType créée pour $proName par $clientName (ID: ${docRef.id})',
        );

        // Notification in-app pour le pro
        try {
          await FirebaseFirestore.instance
              .collection('notifications')
              .add({
            'recipientId': proId,
            'type': 'new_booking',
            'title': '🔔 Nouvelle demande de service',
            'body': '$clientName demande "$serviceType" — $serviceType',
            'bookingId': docRef.id,
            'clientName': clientName,
            'serviceType': serviceType,
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } catch (_) {}

        return {'success': true, 'id': docRef.id, 'message': 'Réservation créée avec succès !'};
      } else {
        final mockId = 'booking_${DateTime.now().millisecondsSinceEpoch}';
        bookingData['id'] = mockId;
        _localBookings.insert(0, Map<String, dynamic>.from(bookingData));
        return {'success': true, 'id': mockId, 'message': 'Réservation créée (Mode local)'};
      }
    } catch (e) {
      debugPrint('Erreur createBooking: $e');
      return {'success': false, 'message': 'Erreur lors de la réservation : $e'};
    }
  }

  /// Écoute en temps réel des réservations du client connecté
  Stream<List<Map<String, dynamic>>> streamClientBookings({String? statusFilter}) {
    final user = FirebaseAuth.instance.currentUser;
    final clientId = user?.uid;

    if (_isFirebaseInitialized && clientId != null) {
      Query query = FirebaseFirestore.instance
          .collection('bookings')
          .where('clientId', isEqualTo: clientId);

      return query.snapshots().map((snapshot) {
        var list = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return data;
        }).toList();

        // Tri par date
        list.sort((a, b) {
          final aDate = a['createdAt'];
          final bDate = b['createdAt'];
          if (aDate is Timestamp && bDate is Timestamp) {
            return bDate.compareTo(aDate);
          }
          return 0;
        });

        if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'Toutes') {
          final filterNorm = _normalizeStatus(statusFilter);
          list = list.where((b) => _normalizeStatus(b['status'] as String? ?? '') == filterNorm).toList();
        }

        return list;
      });
    }

    // Fallback local en mémoire
    var list = List<Map<String, dynamic>>.from(_localBookings);
    if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'Toutes') {
      final filterNorm = _normalizeStatus(statusFilter);
      list = list.where((b) => _normalizeStatus(b['status'] as String? ?? '') == filterNorm).toList();
    }
    return Stream.value(list);
  }

  /// Écoute en temps réel des réservations reçues par un professionnel
  Stream<List<Map<String, dynamic>>> streamProBookings({String? statusFilter}) {
    final user = FirebaseAuth.instance.currentUser;
    final proId = user?.uid;

    String fmtDate(dynamic ts) {
      if (ts is Timestamp) {
        final dt = ts.toDate();
        final now = DateTime.now();
        if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
          return 'Auj. ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
        }
        final diff = dt.difference(now);
        if (diff.inDays == 1) return 'Demain ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
        return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
      }
      return '';
    }

    if (_isFirebaseInitialized && proId != null) {
      Query query = FirebaseFirestore.instance
          .collection('bookings')
          .where('proId', isEqualTo: proId);

      return query.snapshots().map((snapshot) {
        var list = snapshot.docs.map((d) {
          final data = d.data() as Map<String, dynamic>;
          data['id'] = d.id;
          data['dateLabel'] = fmtDate(data['scheduledDate'] ?? data['createdAt']);
          return data;
        }).toList();

        list.sort((a, b) {
          final aDate = a['createdAt'];
          final bDate = b['createdAt'];
          if (aDate is Timestamp && bDate is Timestamp) return bDate.compareTo(aDate);
          return 0;
        });

        if (statusFilter != null && statusFilter.isNotEmpty) {
          final f = _normalizeStatus(statusFilter);
          list = list.where((b) => _normalizeStatus(b['status'] as String? ?? '') == f).toList();
        }
        return list;
      });
    }

    // Fallback local (bookings dont proId correspond)
    var list = _localBookings
        .where((b) => proId == null || b['proId'] == proId)
        .map((b) {
          final copy = Map<String, dynamic>.from(b);
          copy['dateLabel'] = copy['scheduledDate'] ?? '';
          return copy;
        })
        .toList();
    if (statusFilter != null && statusFilter.isNotEmpty) {
      final f = _normalizeStatus(statusFilter);
      list = list.where((b) => _normalizeStatus(b['status'] as String? ?? '') == f).toList();
    }
    return Stream.value(list);
  }

  /// Met à jour le statut d'une réservation (pro accepte / refuse) + notif client
  Future<bool> updateBookingStatus(String bookingId, String newStatus) async {
    try {
      if (_isFirebaseInitialized) {
        // 1. Mettre à jour le statut
        await FirebaseFirestore.instance
            .collection('bookings')
            .doc(bookingId)
            .update({
          'status': newStatus,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // 2. Récupérer le booking pour obtenir clientId et détails
        try {
          final bookingDoc = await FirebaseFirestore.instance
              .collection('bookings')
              .doc(bookingId)
              .get();
          if (bookingDoc.exists) {
            final data = bookingDoc.data()!;
            final clientId = data['clientId'] as String?;
            final proName = data['proName'] as String? ?? 'Le professionnel';
            final serviceType = data['serviceType'] as String? ?? 'le service';

            if (clientId != null && clientId.isNotEmpty && clientId != 'client_anon') {
              String title = '';
              String body = '';

              if (newStatus == 'confirmee') {
                title = '✅ Demande acceptée';
                body = '$proName a accepté votre demande de $serviceType.';
              } else if (newStatus == 'annulee') {
                title = '❌ Demande refusée';
                body = '$proName ne peut pas prendre en charge votre demande de $serviceType.';
              } else if (newStatus == 'terminee') {
                title = '🏁 Intervention terminée';
                body = '$proName a marqué l\'intervention "$serviceType" comme terminée.';
              }

              if (title.isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('notifications')
                    .add({
                  'recipientId': clientId,
                  'type': 'booking_status_update',
                  'title': title,
                  'body': body,
                  'bookingId': bookingId,
                  'proName': proName,
                  'serviceType': serviceType,
                  'newStatus': newStatus,
                  'isRead': false,
                  'createdAt': FieldValue.serverTimestamp(),
                });
              }
            }
          }
        } catch (e) {
          debugPrint('Notif client non envoyée: $e');
        }
      }

      final idx = _localBookings.indexWhere((b) => b['id'] == bookingId);
      if (idx != -1) _localBookings[idx]['status'] = newStatus;
      return true;
    } catch (e) {
      debugPrint('Erreur updateBookingStatus: $e');
      return false;
    }
  }

  /// Stream des notifications du client connecté
  Stream<List<Map<String, dynamic>>> streamClientNotifications() {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    if (_isFirebaseInitialized && uid != null) {
      // Essayer avec orderBy (nécessite un index Firestore composite)
      // Si l'index n'existe pas, Firestore lance une erreur → on trie côté client
      return FirebaseFirestore.instance
          .collection('notifications')
          .where('recipientId', isEqualTo: uid)
          .limit(30)
          .snapshots()
          .map((snap) {
            final list = snap.docs.map((d) {
              final data = d.data();
              data['id'] = d.id;
              final ts = data['createdAt'];
              if (ts is Timestamp) {
                final dt = ts.toDate();
                final diff = DateTime.now().difference(dt);
                if (diff.inMinutes < 1) data['timeLabel'] = 'À l\'instant';
                else if (diff.inMinutes < 60) data['timeLabel'] = 'Il y a ${diff.inMinutes} min';
                else if (diff.inHours < 24) data['timeLabel'] = 'Il y a ${diff.inHours}h';
                else data['timeLabel'] = 'Il y a ${diff.inDays}j';
              } else {
                data['timeLabel'] = '';
              }
              return data;
            }).toList();
            // Tri côté client par createdAt décroissant
            list.sort((a, b) {
              final aTs = a['createdAt'];
              final bTs = b['createdAt'];
              if (aTs is Timestamp && bTs is Timestamp) return bTs.compareTo(aTs);
              return 0;
            });
            return list;
          });
    }
    return Stream.value([]);
  }

  /// Marquer une notification comme lue
  Future<void> markNotificationRead(String notifId) async {
    try {
      if (_isFirebaseInitialized) {
        await FirebaseFirestore.instance
            .collection('notifications')
            .doc(notifId)
            .update({'isRead': true});
      }
    } catch (_) {}
  }

  /// Marquer toutes les notifications comme lues
  Future<void> markAllNotificationsRead(String userId) async {
    try {
      if (_isFirebaseInitialized) {
        final snap = await FirebaseFirestore.instance
            .collection('notifications')
            .where('recipientId', isEqualTo: userId)
            .where('isRead', isEqualTo: false)
            .get();
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in snap.docs) {
          batch.update(doc.reference, {'isRead': true});
        }
        await batch.commit();
      }
    } catch (_) {}
  }

  /// Écoute en temps réel des avis d'un professionnel
  Stream<List<Map<String, dynamic>>> streamReviews(String proId) {
    if (_isFirebaseInitialized) {
      return FirebaseFirestore.instance
          .collection('reviews')
          .where('proId', isEqualTo: proId)
          .orderBy('createdAt', descending: true)
          .limit(10)
          .snapshots()
          .map((snap) => snap.docs.map((d) {
                final data = d.data();
                data['id'] = d.id;
                final ts = data['createdAt'];
                if (ts is Timestamp) {
                  final dt = ts.toDate();
                  final diff = DateTime.now().difference(dt);
                  if (diff.inDays == 0) {
                    data['dateLabel'] = "Aujourd'hui";
                  } else if (diff.inDays == 1) {
                    data['dateLabel'] = 'Hier';
                  } else if (diff.inDays < 7) {
                    data['dateLabel'] = 'Il y a ${diff.inDays} jours';
                  } else if (diff.inDays < 30) {
                    data['dateLabel'] = 'Il y a ${diff.inDays ~/ 7} semaine(s)';
                  } else {
                    data['dateLabel'] = 'Il y a ${diff.inDays ~/ 30} mois';
                  }
                } else {
                  data['dateLabel'] = '';
                }
                return data;
              }).toList());
    }
    return Stream.value([]);
  }

  /// Annuler une réservation
  Future<bool> cancelBooking(String bookingId) async {
    try {
      if (_isFirebaseInitialized) {
        await FirebaseFirestore.instance
            .collection('bookings')
            .doc(bookingId)
            .update({'status': 'annulee', 'cancelledAt': FieldValue.serverTimestamp()});
      }
      final index = _localBookings.indexWhere((b) => b['id'] == bookingId);
      if (index != -1) {
        _localBookings[index]['status'] = 'annulee';
      }
      return true;
    } catch (e) {
      debugPrint('Erreur cancelBooking: $e');
      return false;
    }
  }

  String _normalizeStatus(String raw) {
    final lower = raw.trim().toLowerCase();
    if (lower.contains('attente') || lower.contains('pending')) return 'en_attente';
    if (lower.contains('confirm') || lower.contains('accept')) return 'confirmee';
    if (lower.contains('termin') || lower.contains('complet')) return 'terminee';
    if (lower.contains('annul') || lower.contains('cancel')) return 'annulee';
    return lower;
  }

  Future<void> _seedDefaultProsToFirestore() async {
    try {
      if (!_isFirebaseInitialized) return;
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'professionnel')
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        debugPrint('Ensemencement des professionnels initiaux dans Firestore...');
        final batch = FirebaseFirestore.instance.batch();
        for (final pro in _defaultPros) {
          final doc = FirebaseFirestore.instance.collection('users').doc(pro['id'] as String);
          batch.set(doc, {
            'fullName': pro['name'],
            'email': pro['email'],
            'phone': pro['phone'],
            'role': 'professionnel',
            'serviceType': pro['serviceType'],
            'rating': pro['rating'],
            'reviewsCount': pro['reviewsCount'],
            'price': pro['price'],
            'priceValue': pro['priceValue'],
            'location': pro['location'],
            'distance': pro['distance'],
            'available': pro['available'],
            'bio': pro['bio'],
            'specialties': pro['specialties'],
            'isActive': true,
            'isApproved': true,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
        debugPrint('Professionnels ensemencés avec succès dans Firestore !');
      }
    } catch (e) {
      debugPrint('Note: ensemencement pros non bloquant: $e');
    }
  }

  // ================= GESTION RÉELLE DES FAVORIS CLIENT =================

  static final Set<String> _localFavoriteIds = {};
  static final List<Map<String, dynamic>> _localFavoritesList = [];

  /// Vérifie si un professionnel est dans les favoris
  Future<bool> isFavorite(String proId) async {
    try {
      if (_isFirebaseInitialized) {
        final user = FirebaseAuth.instance.currentUser;
        final clientId = user?.uid;
        if (clientId != null) {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(clientId)
              .collection('favorites')
              .doc(proId)
              .get();
          if (doc.exists) {
            _localFavoriteIds.add(proId);
            return true;
          } else {
            _localFavoriteIds.remove(proId);
            return false;
          }
        }
      }
      return _localFavoriteIds.contains(proId);
    } catch (_) {
      return _localFavoriteIds.contains(proId);
    }
  }

  /// Basculer l'état favori d'un artisan (Ajout / Suppression)
  /// Retourne `true` s'il est désormais favori, `false` s'il a été retiré.
  Future<bool> toggleFavorite(Map<String, dynamic> pro) async {
    try {
      final proId = (pro['id'] ?? pro['uid'] ?? 'pro_${pro['name']}').toString();
      String clientId = 'client_anon';
      if (_isFirebaseInitialized) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) clientId = user.uid;
      }

      final bool currentlyFav = await isFavorite(proId);
      final bool newStatus = !currentlyFav;

      if (newStatus) {
        _localFavoriteIds.add(proId);
        _localFavoritesList.removeWhere((p) => (p['id'] ?? p['uid']) == proId);
        _localFavoritesList.insert(0, Map<String, dynamic>.from(pro));
      } else {
        _localFavoriteIds.remove(proId);
        _localFavoritesList.removeWhere((p) => (p['id'] ?? p['uid']) == proId);
      }

      if (_isFirebaseInitialized && clientId != 'client_anon') {
        final favRef = FirebaseFirestore.instance
            .collection('users')
            .doc(clientId)
            .collection('favorites')
            .doc(proId);

        if (newStatus) {
          await favRef.set({
            ...pro,
            'id': proId,
            'favoritedAt': FieldValue.serverTimestamp(),
          });
        } else {
          await favRef.delete();
        }
      }

      return newStatus;
    } catch (e) {
      debugPrint('Erreur toggleFavorite: $e');
      final proId = (pro['id'] ?? pro['uid'] ?? '').toString();
      if (_localFavoriteIds.contains(proId)) {
        _localFavoriteIds.remove(proId);
        _localFavoritesList.removeWhere((p) => (p['id'] ?? p['uid']) == proId);
        return false;
      } else {
        _localFavoriteIds.add(proId);
        _localFavoritesList.insert(0, Map<String, dynamic>.from(pro));
        return true;
      }
    }
  }

  /// Écoute en temps réel la liste des artisans favoris du client
  Stream<List<Map<String, dynamic>>> streamFavorites() {
    String? clientId;
    if (_isFirebaseInitialized) {
      final user = FirebaseAuth.instance.currentUser;
      clientId = user?.uid;
    }

    if (_isFirebaseInitialized && clientId != null) {
      return FirebaseFirestore.instance
          .collection('users')
          .doc(clientId)
          .collection('favorites')
          .snapshots()
          .map((snapshot) {
        final list = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();

        _localFavoriteIds.clear();
        for (final item in list) {
          _localFavoriteIds.add(item['id'].toString());
        }
        return list;
      });
    }

    return Stream.value(List<Map<String, dynamic>>.from(_localFavoritesList));
  }
}
