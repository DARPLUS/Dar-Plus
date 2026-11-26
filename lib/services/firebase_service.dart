import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:geolocator/geolocator.dart';

import '../firebase_options.dart';
import 'firebase_emulator_config.dart';
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
  static String get _adminRootEmail =>
      (dotenv.env['ADMIN_ROOT_EMAIL'] ?? 'admin@darplus.tn')
          .trim()
          .toLowerCase();
  static String get _adminRootPass =>
      dotenv.env['ADMIN_ROOT_PASSWORD'] ?? 'admin123';
  static String get _adminRootFallback =>
      dotenv.env['ADMIN_ROOT_FALLBACK_PASSWORD'] ?? 'password123';

  bool _isFirebaseInitialized = false;
  bool get isFirebaseInitialized => _isFirebaseInitialized;
  static Future<void>? _googleSignInInitialization;
  StreamSubscription<Position>? _professionalLocationSubscription;

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
    'requireProfessionalApproval': true,
    'operationalNotifications': true,
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
    'client@darplus.tn': {
      'uid': 'mock_client_karim',
      'fullName': 'Karim Client',
      'email': 'client@darplus.tn',
      'phone': '+216 20 111 222',
      'password': 'password123',
      'role': 'client',
      'isActive': true,
      'isApproved': true,
      'mustChangePassword': false,
    },
    'ahmed.pro@darplus.tn': {
      'uid': 'mock_pro_ahmed',
      'fullName': 'Ahmed Pro',
      'email': 'ahmed.pro@darplus.tn',
      'phone': '+216 21 333 444',
      'password': 'password123',
      'role': 'professionnel',
      'serviceType': 'Plomberie & Sanitaire',
      'isActive': true,
      'isApproved': true,
      'status': 'valide',
      'mustChangePassword': false,
    },
    'sami.attente@darplus.tn': {
      'uid': 'mock_pro_sami',
      'fullName': 'Sami Pro',
      'email': 'sami.attente@darplus.tn',
      'phone': '+216 22 555 666',
      'password': 'password123',
      'role': 'professionnel',
      'serviceType': 'Plomberie & Sanitaire',
      'isActive': true,
      'isApproved': false,
      'status': 'en_attente',
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
      if (FirebaseEmulatorConfig.enabled) {
        final host = FirebaseEmulatorConfig.host;
        await FirebaseAuth.instance.useAuthEmulator(host, 9099);
        FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
        FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);
      }
      debugPrint(
        'Firebase connecté avec succès au projet '
        '${DefaultFirebaseOptions.currentPlatform.projectId} !',
      );
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
    String? languageCode,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanPassword = password.trim();

    try {
      if (_isFirebaseInitialized) {
        final UserCredential cred = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: cleanEmail,
              password: cleanPassword,
            );

        final user = cred.user!;
        final uid = user.uid;

        try {
          await user.updateDisplayName(fullName.trim());
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

        var emailSent = false;
        String? verificationMessage;
        try {
          final mailResult = await EmailService.sendFirebaseAuthEmail(
            type: 'emailVerification',
            toEmail: cleanEmail,
            userName: fullName.trim(),
            languageCode: languageCode ?? 'fr',
          );
          emailSent = mailResult.sent;
          verificationMessage = mailResult.error;
        } catch (e) {
          verificationMessage =
              'Impossible de préparer ou envoyer l\'e-mail : $e';
        }

        return {
          'success': true,
          'uid': uid,
          'emailSent': emailSent,
          'email': cleanEmail,
          'message': emailSent
              ? 'Compte créé. Vérifiez votre boîte mail pour confirmer votre adresse.'
              : 'Compte créé, mais l\'e-mail de vérification n\'a pas pu être envoyé. ${verificationMessage ?? ''}',
        };
      } else {
        await Future.delayed(const Duration(milliseconds: 400));
        return {
          'success': true,
          'uid': 'mock_client_${DateTime.now().millisecondsSinceEpoch}',
          'emailSent': false,
          'isDemo': true,
          'email': cleanEmail,
          'message': 'Compte client créé (Mode Démo).',
        };
      }
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'message': _getAuthErrorMessage(e.code)};
    } catch (e) {
      return {'success': false, 'message': 'Une erreur est survenue : $e'};
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
        if (FirebaseAuth.instance.currentUser == null) {
          return {
            'success': false,
            'message': 'Une session Super Admin est requise pour créer un administrateur.',
          };
        }

        final secondaryApps = Firebase.apps
            .where((app) => app.name == 'SecondaryApp')
            .toList();
        final tempApp = secondaryApps.isEmpty
            ? await Firebase.initializeApp(
                name: 'SecondaryApp',
                options: Firebase.app().options,
              )
            : secondaryApps.first;
        final tempAuth = FirebaseAuth.instanceFor(app: tempApp);
        String uid;
        UserCredential? credential;

        try {
          try {
            credential = await tempAuth.createUserWithEmailAndPassword(
              email: cleanEmail,
              password: cleanPassword,
            );
            final user = credential.user!;
            uid = user.uid;

            // Firestore must use the authenticated Super Admin from the default app.
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
          } catch (e) {
            if (credential?.user != null) {
              await credential!.user!.delete();
            }
            rethrow;
          }
        } finally {
          await tempAuth.signOut();
        }

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
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'message': _getAuthErrorMessage(e.code)};
    } catch (e) {
      return {'success': false, 'message': 'Erreur lors de la création : $e'};
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
        final secondaryApps = Firebase.apps
            .where((app) => app.name == 'SecondaryApp')
            .toList();
        final tempApp = secondaryApps.isEmpty
            ? await Firebase.initializeApp(
                name: 'SecondaryApp',
                options: Firebase.app().options,
              )
            : secondaryApps.first;
        final tempAuth = FirebaseAuth.instanceFor(app: tempApp);
        UserCredential? credential;

        try {
          try {
            credential = await tempAuth.createUserWithEmailAndPassword(
              email: cleanEmail,
              password: cleanPassword,
            );
            final uid = credential.user!.uid;
            final tempFirestore = FirebaseFirestore.instanceFor(app: tempApp);

            final batch = tempFirestore.batch();
            batch.set(
              tempFirestore.collection('pro_applications').doc(appId),
              app.toMap(),
            );
            batch.set(tempFirestore.collection('users').doc(uid), {
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
            await batch.commit();
          } catch (e) {
            if (credential?.user != null) {
              await credential!.user!.delete();
            }
            rethrow;
          }
        } finally {
          await tempAuth.signOut();
        }

        NotificationService().notifyAdminNewProApplication(app);
        return {
          'success': true,
          'id': appId,
          'message':
              'Votre demande a bien été envoyée à l\'administrateur DAR PLUS.',
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
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'message': _getAuthErrorMessage(e.code)};
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
  Future<bool> approveProApplication(
    String appId, {
    ProApplication? proApp,
    String? actorEmail,
  }) async {
    try {
      ProApplication? target = proApp;
      if (_isFirebaseInitialized) {
        if (target == null) {
          final appSnapshot = await FirebaseFirestore.instance
              .collection('pro_applications')
              .doc(appId)
              .get();
          if (!appSnapshot.exists || appSnapshot.data() == null) return false;
          target = ProApplication.fromMap(appSnapshot.data()!, appSnapshot.id);
        }
        if (target.status != 'en_attente') return false;

        final userSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: target.email.trim().toLowerCase())
            .limit(1)
            .get();
        if (userSnapshot.docs.isEmpty) return false;

        final now = FieldValue.serverTimestamp();
        final batch = FirebaseFirestore.instance.batch();
        batch.update(
          FirebaseFirestore.instance.collection('pro_applications').doc(appId),
          {'status': 'valide', 'approvedAt': now},
        );
        batch.update(userSnapshot.docs.first.reference, {
          'role': 'professionnel',
          'isApproved': true,
          'status': 'valide',
          'serviceType': target.serviceType,
          'fullName': target.fullName,
          'approvedAt': now,
        });
        await batch.commit();

        try {
          await EmailService.sendProApprovedEmail(
            toEmail: target.email,
            proName: target.fullName,
            serviceType: target.serviceType,
          );
        } catch (error) {
          debugPrint('Email de validation non envoyé: $error');
        }
        try {
          await FirebaseFirestore.instance.collection('notifications').add({
            'recipientId': userSnapshot.docs.first.id,
            'type': 'pro_application_approved',
            'title': 'Candidature acceptée !',
            'body':
                'Félicitations ${target.fullName} ! Votre compte professionnel DAR PLUS a été validé. Vous pouvez maintenant vous connecter.',
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } catch (error) {
          debugPrint('Notification de validation non créée: $error');
        }
        await logSecurityEvent(
          action: 'Validation Professionnel',
          actorEmail: actorEmail ?? 'Administrateur',
          target: target.email,
          details: 'Validation de ${target.fullName} (${target.serviceType})',
          severity: 'info',
        );
        return true;
      }

      final index = _localProApplications.indexWhere((app) => app.id == appId);
      if (index < 0 || _localProApplications[index].status != 'en_attente') {
        return false;
      }
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
      try {
        await EmailService.sendProApprovedEmail(
          toEmail: old.email,
          proName: old.fullName,
          serviceType: old.serviceType,
        );
      } catch (error) {
        debugPrint('Email de validation non envoyé: $error');
      }
      return true;
    } catch (error) {
      debugPrint('Erreur validation: $error');
      return false;
    }
  }

  Future<bool> rejectProApplication(
    String appId, {
    required String reason,
    ProApplication? proApp,
    String? actorEmail,
  }) async {
    final cleanReason = reason.trim();
    if (cleanReason.isEmpty) return false;
    try {
      ProApplication? target = proApp;
      if (_isFirebaseInitialized) {
        if (target == null) {
          final appSnapshot = await FirebaseFirestore.instance
              .collection('pro_applications')
              .doc(appId)
              .get();
          if (!appSnapshot.exists || appSnapshot.data() == null) return false;
          target = ProApplication.fromMap(appSnapshot.data()!, appSnapshot.id);
        }
        if (target.status != 'en_attente') return false;

        final userSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: target.email.trim().toLowerCase())
            .limit(1)
            .get();
        if (userSnapshot.docs.isEmpty) return false;

        final now = FieldValue.serverTimestamp();
        final batch = FirebaseFirestore.instance.batch();
        batch.update(
          FirebaseFirestore.instance.collection('pro_applications').doc(appId),
          {
            'status': 'refuse',
            'rejectionReason': cleanReason,
            'rejectedAt': now,
          },
        );
        batch.update(userSnapshot.docs.first.reference, {
          'isApproved': false,
          'status': 'refuse',
          'rejectionReason': cleanReason,
          'rejectedAt': now,
        });
        await batch.commit();

        try {
          await EmailService.sendProRejectedEmail(
            toEmail: target.email,
            proName: target.fullName,
            reason: cleanReason,
          );
        } catch (error) {
          debugPrint('Email de refus non envoyé: $error');
        }
        try {
          await FirebaseFirestore.instance.collection('notifications').add({
            'recipientId': userSnapshot.docs.first.id,
            'type': 'pro_application_rejected',
            'title': 'Candidature non retenue',
            'body':
                'Votre candidature DAR PLUS n\'a pas été retenue. Motif : $cleanReason',
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } catch (error) {
          debugPrint('Notification de refus non créée: $error');
        }
        await logSecurityEvent(
          action: 'Refus Professionnel',
          actorEmail: actorEmail ?? 'Administrateur',
          target: target.email,
          details: 'Motif de rejet : $cleanReason',
          severity: 'warning',
        );
        return true;
      }

      final index = _localProApplications.indexWhere((app) => app.id == appId);
      if (index < 0 || _localProApplications[index].status != 'en_attente') {
        return false;
      }
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
        rejectionReason: cleanReason,
      );
      if (_localUsers.containsKey(old.email.toLowerCase())) {
        _localUsers[old.email.toLowerCase()]!['isApproved'] = false;
        _localUsers[old.email.toLowerCase()]!['status'] = 'refuse';
        _localUsers[old.email.toLowerCase()]!['rejectionReason'] = cleanReason;
      }
      return true;
    } catch (error) {
      debugPrint('Erreur rejet: $error');
      return false;
    }
  }

  /// Retourne la candidature professionnelle VALIDÉE liée à cet email, si elle
  /// existe. Les candidatures sont lisibles par tout utilisateur connecté, ce
  /// qui permet de réparer un profil resté en "client" après validation.
  Future<Map<String, dynamic>?> _validatedProApplicationFor(
    String email,
  ) async {
    try {
      if (!_isFirebaseInitialized) return null;
      final cleanEmail = email.trim().toLowerCase();
      if (cleanEmail.isEmpty) return null;
      final q = await FirebaseFirestore.instance
          .collection('pro_applications')
          .where('email', isEqualTo: cleanEmail)
          .limit(10)
          .get();
      for (final doc in q.docs) {
        final data = doc.data();
        final status = (data['status'] as String?)?.toLowerCase();
        if (status == 'valide' || data['isApproved'] == true) {
          return <String, dynamic>{...data, 'id': doc.id, 'status': 'valide'};
        }
      }
    } catch (e) {
      debugPrint('Recherche candidature pro impossible : $e');
    }
    return null;
  }

  /// 6. Connexion unifiée
  Future<Map<String, dynamic>> signInWithEmailAndPassword({
    required String email,
    required String password,
    String? selectedRole,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanPassword = password.trim();

    // Keep the configured emergency credentials for local demo mode only.
    if (!_isFirebaseInitialized &&
        cleanEmail == _adminRootEmail &&
        (cleanPassword == _adminRootPass ||
            cleanPassword == _adminRootFallback)) {
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
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get();

          if (userDoc.exists) {
            final data = userDoc.data()!;
            var role = cleanEmail == _adminRootEmail
                ? 'super_admin'
                : ((data['role'] as String?)?.toLowerCase() ?? 'client');
            var isApproved = data['isApproved'] ?? true;
            var status =
                data['status'] ?? (isApproved ? 'valide' : 'en_attente');
            Map<String, dynamic>? validatedPro;

            // Filet de sécurité : une candidature professionnelle validée par
            // l'administrateur fait foi, même si le profil est resté "client"
            // (ancienne validation, profil orphelin, inscription client avant
            // la candidature pro, etc.).
            if (role == 'client') {
              validatedPro = await _validatedProApplicationFor(cleanEmail);
              if (validatedPro != null) {
                role = 'professionnel';
                status = 'valide';
                isApproved = true;
              }
            }

            if (role == 'client' && cred.user?.emailVerified != true) {
              return {
                'success': false,
                'code': 'EMAIL_NOT_VERIFIED',
                'message': 'Confirmez votre adresse e-mail avant de vous connecter. Vous pouvez renvoyer le lien de vérification.',
              };
            }
            if (role == 'client' && data['isEmailVerified'] != true) {
              try {
                await userDoc.reference.update({'isEmailVerified': true});
              } catch (e) {
                debugPrint(
                  'Mise à jour de la vérification e-mail impossible : $e',
                );
              }
            }

            if (role == 'professionnel') {
              if (status == 'en_attente' || !isApproved) {
                await FirebaseAuth.instance.signOut();
                return {
                  'success': false,
                  'code': 'PENDING_APPROVAL',
                  'message': 'Votre compte professionnel est en cours d\'examen par l\'administrateur DAR PLUS.',
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
              'fullName':
                  data['fullName'] ??
                  validatedPro?['fullName'] ??
                  (cleanEmail == _adminRootEmail
                      ? 'Super Admin DAR PLUS'
                      : cleanEmail.split('@').first),
              'email': data['email'] ?? cleanEmail,
              'phone': data['phone'] ?? (validatedPro?['phone'] ?? ''),
              'serviceType':
                  data['serviceType'] ??
                  validatedPro?['serviceType'] ??
                  'Plomberie & Sanitaire',
              'mustChangePassword': data['mustChangePassword'] == true,
              'message': 'Connexion réussie !',
            };
          } else {
            final validatedPro = cleanEmail == _adminRootEmail
                ? null
                : await _validatedProApplicationFor(cleanEmail);
            final effectiveRole = cleanEmail == _adminRootEmail
                ? 'super_admin'
                : (validatedPro != null
                      ? 'professionnel'
                      : (selectedRole ??
                            (cleanEmail.contains('admin')
                                ? 'admin'
                                : 'client')));
            if (effectiveRole == 'client' && cred.user?.emailVerified != true) {
              return {
                'success': false,
                'code': 'EMAIL_NOT_VERIFIED',
                'message': 'Confirmez votre adresse e-mail avant de vous connecter. Vous pouvez renvoyer le lien de vérification.',
              };
            }
            final displayName = cred.user?.displayName;
            final resolvedName = (displayName != null && displayName.isNotEmpty)
                ? displayName
                : (validatedPro?['fullName'] as String?) ??
                      cleanEmail.split('@').first;
            final resolvedPhone = validatedPro?['phone'] ?? '';

            // Crée le profil manquant : sans document, l'app retombait
            // silencieusement sur le rôle "client" à chaque connexion.
            if (effectiveRole == 'client' || effectiveRole == 'professionnel') {
              try {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .set({
                      'uid': uid,
                      'fullName': resolvedName,
                      'email': cleanEmail,
                      'phone': resolvedPhone,
                      'role': effectiveRole,
                      'isApproved': true,
                      'status': 'valide',
                      'isActive': true,
                      'createdAt': FieldValue.serverTimestamp(),
                      if (validatedPro?['serviceType'] != null)
                        'serviceType': validatedPro!['serviceType'],
                    }, SetOptions(merge: true));
              } catch (e) {
                debugPrint('Création du profil utilisateur impossible : $e');
              }
            }

            return {
              'success': true,
              'role': effectiveRole,
              'uid': uid,
              'fullName': resolvedName,
              'email': cleanEmail,
              'phone': resolvedPhone,
              'serviceType':
                  validatedPro?['serviceType'] ?? 'Plomberie & Sanitaire',
              'message': 'Connexion réussie !',
            };
          }
        } on FirebaseAuthException catch (authErr) {
          if (cleanEmail == _adminRootEmail) {
            return {
              'success': false,
              'message': _getAuthErrorMessage(authErr.code),
            };
          }

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
              final role = cleanEmail == _adminRootEmail
                  ? 'super_admin'
                  : ((data['role'] as String?)?.toLowerCase() ?? 'admin');

              if ((storedTemp != null && storedTemp == cleanPassword) ||
                  (storedPass != null && storedPass == cleanPassword) ||
                  (mustChange &&
                      (storedTemp == null || storedTemp == cleanPassword))) {
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
            final storedPassword = (local['password'] as String?)?.trim();
            if (storedPassword != null && storedPassword == cleanPassword) {
              return {
                'success': true,
                'role': cleanEmail == _adminRootEmail
                    ? 'super_admin'
                    : (local['role'] ?? 'admin'),
                'uid': local['uid'] ?? 'local_uid',
                'fullName': local['fullName'] ?? cleanEmail.split('@').first,
                'email': cleanEmail,
                'phone': local['phone'] ?? '',
                'serviceType': local['serviceType'] ?? 'Plomberie & Sanitaire',
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
          final storedPassword = (local['password'] as String?)?.trim();
          if (storedPassword != null && storedPassword == cleanPassword) {
            return {
              'success': true,
              'role': local['role'] ?? 'admin',
              'fullName': local['fullName'] ?? cleanEmail.split('@').first,
              'email': cleanEmail,
              'phone': local['phone'] ?? '',
              'serviceType': local['serviceType'] ?? 'Plomberie & Sanitaire',
              'mustChangePassword': local['mustChangePassword'] == true,
              'message': 'Connexion réussie !',
            };
          }
          return {
            'success': false,
            'message':
                'Identifiants invalides pour ce compte de démonstration.',
          };
        }
        return {
          'success': true,
          'role': cleanEmail == _adminRootEmail
              ? 'super_admin'
              : (selectedRole ??
                    (cleanEmail.contains('admin') ? 'admin' : 'client')),
          'fullName': cleanEmail == _adminRootEmail
              ? 'Super Admin DAR PLUS'
              : cleanEmail.split('@').first,
          'email': cleanEmail,
          'message': 'Connexion réussie (Mode Démo).',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Erreur de connexion : $e'};
    }
  }

  /// 6.1 Connexion avec Google
  Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      if (_isFirebaseInitialized) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');

        UserCredential? cred;
        if (kIsWeb) {
          // Reprendre un éventuel résultat de redirect avant d'ouvrir le popup.
          try {
            final redirectResult = await FirebaseAuth.instance
                .getRedirectResult();
            if (redirectResult.user != null) {
              cred = redirectResult;
            }
          } catch (_) {}

          cred ??= await FirebaseAuth.instance.signInWithPopup(googleProvider);
        } else {
          final googleSignIn = GoogleSignIn.instance;
          await (_googleSignInInitialization ??= googleSignIn.initialize());
          final googleUser = await googleSignIn.authenticate();
          final googleAuth = googleUser.authentication;
          final idToken = googleAuth.idToken;

          if (idToken == null || idToken.isEmpty) {
            return {
              'success': false,
              'message': 'Jeton Google manquant. Activez Google dans Firebase Authentication puis téléchargez le fichier google-services.json contenant le client OAuth Web.',
            };
          }

          final credential = GoogleAuthProvider.credential(idToken: idToken);
          cred = await FirebaseAuth.instance.signInWithCredential(credential);
        }

        final user = cred.user;

        if (user == null) {
          return {'success': false, 'message': 'Connexion Google annulée.'};
        }

        final uid = user.uid;
        final cleanEmail = (user.email ?? '').trim().toLowerCase();
        final fullName =
            (user.displayName != null && user.displayName!.isNotEmpty)
            ? user.displayName!
            : (cleanEmail.isNotEmpty
                  ? cleanEmail.split('@').first
                  : 'Utilisateur');

        // Vérifier si l'utilisateur existe déjà dans Firestore
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();

        if (userDoc.exists) {
          final data = userDoc.data()!;
          var role = (data['role'] as String?)?.toLowerCase() ?? 'client';
          var isApproved = data['isApproved'] ?? true;
          var status = data['status'] ?? (isApproved ? 'valide' : 'en_attente');
          Map<String, dynamic>? validatedPro;

          // Même filet de sécurité que la connexion email/mot de passe.
          if (role == 'client') {
            validatedPro = await _validatedProApplicationFor(cleanEmail);
            if (validatedPro != null) {
              role = 'professionnel';
              status = 'valide';
              isApproved = true;
            }
          }

          if (role == 'professionnel') {
            if (status == 'en_attente' || !isApproved) {
              await FirebaseAuth.instance.signOut();
              return {
                'success': false,
                'code': 'PENDING_APPROVAL',
                'message': 'Votre compte professionnel est en cours d\'examen par l\'administrateur DAR PLUS.',
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
            'serviceType':
                data['serviceType'] ??
                validatedPro?['serviceType'] ??
                'Plomberie & Sanitaire',
            'mustChangePassword': false,
            'message': 'Bienvenue $fullName !',
          };
        } else {
          // Nouvel utilisateur via Google : client par défaut, sauf si une
          // candidature professionnelle a déjà été validée avec cet email.
          final validatedPro = await _validatedProApplicationFor(cleanEmail);
          final role = validatedPro != null ? 'professionnel' : 'client';
          await FirebaseFirestore.instance.collection('users').doc(uid).set({
            'uid': uid,
            'fullName': fullName,
            'email': cleanEmail,
            'phone': user.phoneNumber ?? '',
            'photoUrl': user.photoURL ?? '',
            'role': role,
            'isApproved': true,
            'status': 'valide',
            'isActive': true,
            'createdAt': FieldValue.serverTimestamp(),
            if (validatedPro?['serviceType'] != null)
              'serviceType': validatedPro!['serviceType'],
          }, SetOptions(merge: true));

          return {
            'success': true,
            'role': role,
            'uid': uid,
            'fullName': fullName,
            'email': cleanEmail,
            'phone': user.phoneNumber ?? '',
            'serviceType':
                validatedPro?['serviceType'] ?? 'Plomberie & Sanitaire',
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
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return {
          'success': false,
          'message': 'La connexion Google a été annulée. Si cela se répète, vérifiez la configuration OAuth Firebase.',
        };
      }
      if (e.code == GoogleSignInExceptionCode.clientConfigurationError ||
          e.code == GoogleSignInExceptionCode.providerConfigurationError) {
        return {
          'success': false,
          'message': 'La configuration Google de cette plateforme est incomplète. Vérifiez les paramètres OAuth dans Firebase.',
        };
      }
      return {
        'success': false,
        'message': 'Erreur Google : ${e.description ?? e.toString()}',
      };
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
      return {'success': false, 'message': _getAuthErrorMessage(e.code)};
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
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
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

  /// Rôle effectif de l'utilisateur : une candidature professionnelle validée
  /// fait foi même si le profil Firestore est encore resté en "client".
  Future<String> resolveEffectiveRole({
    required String email,
    String? profileRole,
  }) async {
    final role = (profileRole ?? 'client').toLowerCase();
    if (role != 'client') return role;
    final proApp = await _validatedProApplicationFor(email);
    return proApp != null ? 'professionnel' : role;
  }

  Future<void> updateUserField(String uid, String field, dynamic value) async {
    try {
      if (_isFirebaseInitialized) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          field: value,
        });
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
          if (photoBase64 != null) {
            updates['photoBase64'] = photoBase64;
            // Une nouvelle photo locale remplace l'ancienne URL (Google/Storage)
            if (photoBase64.trim().isNotEmpty) {
              updates['photoUrl'] = FieldValue.delete();
            }
          }
          if (photoUrl != null) {
            updates['photoUrl'] = photoUrl;
            // Clear old base64 data when a proper URL is set
            updates['photoBase64'] = FieldValue.delete();
            try {
              await user.updatePhotoURL(photoUrl);
            } catch (_) {}
          }

          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set(updates, SetOptions(merge: true));
          return true;
        }
      }
      return true;
    } catch (e) {
      debugPrint('Erreur mise à jour profil: $e');
      return false;
    }
  }

  Future<bool> updateManagedClientProfile({
    required String uid,
    required String fullName,
    required String phone,
    required String governorate,
    required String actorEmail,
  }) async {
    try {
      if (!_isFirebaseInitialized || uid.trim().isEmpty) return false;
      final cleanName = fullName.trim();
      if (cleanName.isEmpty) return false;
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'fullName': cleanName,
        'phone': phone.trim(),
        'governorate': governorate.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await logSecurityEvent(
        action: 'Modification profil client',
        actorEmail: actorEmail,
        target: uid,
        details: 'Nom, téléphone ou localisation du client mis à jour.',
        severity: 'warning',
      );
      return true;
    } catch (error) {
      debugPrint('Erreur de modification du profil client: $error');
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
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => {...doc.data(), 'id': doc.id, 'uid': doc.id})
                .toList(),
          );
    } else {
      return Stream.value(_localUsers.values.toList());
    }
  }

  Future<bool> toggleUserStatus(
    String uid, [
    dynamic arg2,
    dynamic arg3,
    String? actorEmail,
  ]) async {
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
      if (email != null && email.trim().toLowerCase() == _adminRootEmail) {
        debugPrint(
          'Action refusée : le Super Admin principal ne peut pas être désactivé.',
        );
        return false;
      }

      if (_isFirebaseInitialized) {
        if (newStatus != null) {
          await FirebaseFirestore.instance.collection('users').doc(uid).update({
            'isActive': newStatus,
          });
        }
      }

      if (email != null &&
          _localUsers.containsKey(email.trim().toLowerCase())) {
        _localUsers[email.trim().toLowerCase()]!['isActive'] = newStatus;
      }

      await logSecurityEvent(
        action: newStatus == true
            ? 'Réactivation Utilisateur'
            : 'Suspension Utilisateur',
        actorEmail: actorEmail ?? 'Administrateur',
        target: email ?? uid,
        details:
            'Statut du compte passé à : ${newStatus == true ? "Actif" : "Suspendu"}',
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
      if (cleanEmail == _adminRootEmail) {
        debugPrint(
          'Action refusée : le Super Admin principal ne peut pas être supprimé.',
        );
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
    if (cleanEmail == _adminRootEmail && newRole != 'super_admin') {
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
    if (cleanEmail == _adminRootEmail) return 'super_admin';
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

  Stream<List<Map<String, dynamic>>> streamSecurityLogs({
    bool isSuperAdmin = false,
  }) {
    if (_isFirebaseInitialized) {
      return FirebaseFirestore.instance
          .collection('security_logs')
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map((snapshot) {
            final docs = snapshot.docs
                .map((d) => {'id': d.id, ...d.data()})
                .toList();
            if (isSuperAdmin) {
              return docs;
            } else {
              // Admin standard : vue limitée (masque les événements de gestion d'admin et critiques)
              return docs
                  .where(
                    (l) =>
                        l['severity'] != 'critical' &&
                        l['action'] != 'Création Administrateur' &&
                        l['action'] != 'Attribution de Rôle' &&
                        l['action'] != 'Modification Paramètres Globaux',
                  )
                  .toList();
            }
          });
    } else {
      final list = isSuperAdmin
          ? _localSecurityLogs
          : _localSecurityLogs
                .where(
                  (l) =>
                      l['severity'] != 'critical' &&
                      l['action'] != 'Création Administrateur' &&
                      l['action'] != 'Attribution de Rôle' &&
                      l['action'] != 'Modification Paramètres Globaux',
                )
                .toList();
      return Stream.value(list);
    }
  }

  /// 8.3 Paramètres globaux de la plateforme (Super Admin)
  Stream<Map<String, dynamic>> streamGlobalSettings() {
    if (_isFirebaseInitialized) {
      return FirebaseFirestore.instance
          .collection('platform_settings')
          .doc('global')
          .snapshots()
          .map(
            (doc) => doc.exists
                ? (doc.data() ?? _localGlobalSettings)
                : _localGlobalSettings,
          );
    } else {
      return Stream.value(_localGlobalSettings);
    }
  }

  Future<bool> updateGlobalSettings(
    Map<String, dynamic> newSettings, {
    String? actorEmail,
  }) async {
    _localGlobalSettings.addAll(newSettings);
    if (_isFirebaseInitialized) {
      try {
        await FirebaseFirestore.instance
            .collection('platform_settings')
            .doc('global')
            .set(newSettings, SetOptions(merge: true));
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
          'message':
              'Veuillez vous reconnecter avant de changer votre mot de passe.',
        };
      }
      return {'success': false, 'message': _getAuthErrorMessage(e.code)};
    } catch (e) {
      return {'success': false, 'message': 'Erreur : $e'};
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
      return {'success': false, 'message': 'Erreur : $e'};
    }
  }

  /// 10. Déconnexion
  Future<void> signOut() async {
    try {
      if (_isFirebaseInitialized) {
        if (_professionalLocationSubscription != null) {
          await stopProfessionalLocationSharing();
        }
        await FirebaseAuth.instance.signOut();
      }
    } catch (_) {}
  }

  /// 11. Envoie une demande de réinitialisation via le template EmailJS.
  Future<Map<String, dynamic>> resetPassword(
    String email, {
    String? languageCode,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    try {
      if (_isFirebaseInitialized) {
        final mailResult = await EmailService.sendFirebaseAuthEmail(
          type: 'passwordReset',
          toEmail: cleanEmail,
          userName: cleanEmail.split('@').first,
          languageCode: languageCode ?? 'fr',
        );
        if (mailResult.sent) {
          return {
            'success': true,
            'message': 'Si un compte correspond à cette adresse, un e-mail de réinitialisation sera envoyé.',
          };
        }
        return {
          'success': false,
          'message':
              mailResult.error ?? 'EmailJS n\'a pas pu envoyer l\'e-mail.',
        };
      }

      return {
        'success': false,
        'message': 'Impossible d\'envoyer l\'email de réinitialisation.',
      };
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'message': 'Erreur : ${e.message ?? e.code}'};
    } catch (e) {
      return {'success': false, 'message': 'Erreur lors de l\'envoi : $e'};
    }
  }

  /// 12. Gestion des Catégories de Métiers (Firestore Réel)
  static final List<Map<String, dynamic>> _defaultCategories = [
    {
      'id': 'cat_1',
      'name': 'Plomberie',
      'pros': 48,
      'isActive': true,
      'iconCode': Icons.plumbing.codePoint,
      'bgColorHex': 0xFFE8F0FE,
      'iconColorHex': 0xFF1E40AF,
    },
    {
      'id': 'cat_2',
      'name': 'Électricité',
      'pros': 41,
      'isActive': true,
      'iconCode': Icons.electrical_services.codePoint,
      'bgColorHex': 0xFFFEF3C7,
      'iconColorHex': 0xFFD97706,
    },
    {
      'id': 'cat_3',
      'name': 'Nettoyage',
      'pros': 63,
      'isActive': true,
      'iconCode': Icons.cleaning_services.codePoint,
      'bgColorHex': 0xFFD7F3EA,
      'iconColorHex': 0xFF0D544E,
    },
    {
      'id': 'cat_4',
      'name': 'Climatisation',
      'pros': 22,
      'isActive': true,
      'iconCode': Icons.ac_unit.codePoint,
      'bgColorHex': 0xFFE0EAFA,
      'iconColorHex': 0xFF2563EB,
    },
    {
      'id': 'cat_5',
      'name': 'Peinture',
      'pros': 17,
      'isActive': true,
      'iconCode': Icons.format_paint.codePoint,
      'bgColorHex': 0xFFFCE7F3,
      'iconColorHex': 0xFFBE185D,
    },
    {
      'id': 'cat_6',
      'name': 'Serrurerie',
      'pros': 12,
      'isActive': false,
      'iconCode': Icons.lock.codePoint,
      'bgColorHex': 0xFFF1F5F9,
      'iconColorHex': 0xFF64748B,
    },
    {
      'id': 'cat_7',
      'name': 'Bricolage',
      'pros': 35,
      'isActive': true,
      'iconCode': Icons.construction.codePoint,
      'bgColorHex': 0xFFFEF3C7,
      'iconColorHex': 0xFFB45309,
    },
    {
      'id': 'cat_8',
      'name': 'Jardinage',
      'pros': 19,
      'isActive': true,
      'iconCode': Icons.grass.codePoint,
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
            if (snapshot.docs.isEmpty) {
              if (!_categoriesSeeded &&
                  await _currentUserCanManageCategories()) {
                try {
                  final batch = FirebaseFirestore.instance.batch();
                  for (final cat in _defaultCategories) {
                    batch.set(
                      FirebaseFirestore.instance
                          .collection('categories')
                          .doc(cat['id'] as String),
                      {
                        'id': cat['id'],
                        'name': cat['name'],
                        'pros': cat['pros'],
                        'isActive': cat['isActive'],
                        'iconCode': cat['iconCode'],
                        'bgColorHex': cat['bgColorHex'],
                        'iconColorHex': cat['iconColorHex'],
                        'createdAt': FieldValue.serverTimestamp(),
                      },
                    );
                  }
                  await batch.commit();
                  _categoriesSeeded = true;
                } catch (error) {
                  debugPrint('Initialisation des catégories ignorée: $error');
                }
              }
              return _defaultCategories
                  .map((c) => _mapToCategoryModel(c))
                  .toList();
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
                final serviceType = (doc.data()['serviceType'] as String? ?? '')
                    .trim();
                if (serviceType.isNotEmpty) {
                  proCountByService[serviceType] =
                      (proCountByService[serviceType] ?? 0) + 1;
                }
              }
            } catch (_) {}

            return snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              final catName = (data['name'] as String? ?? '').trim();
              // Recherche insensible à la casse pour matcher nom catégorie ↔ serviceType
              final realCount = proCountByService.entries
                  .where(
                    (e) =>
                        e.key.toLowerCase() == catName.toLowerCase() ||
                        e.key.toLowerCase().contains(catName.toLowerCase()) ||
                        catName.toLowerCase().contains(e.key.toLowerCase()),
                  )
                  .fold<int>(0, (acc, e) => acc + e.value);
              data['pros'] = realCount > 0 ? realCount : (data['pros'] ?? 0);
              return _mapToCategoryModel(data);
            }).toList();
          });
    } else {
      if (_localCategories.isEmpty) {
        _localCategories.addAll(
          _defaultCategories.map((c) => _mapToCategoryModel(c)),
        );
      }
      return Stream.value(List<Map<String, dynamic>>.from(_localCategories));
    }
  }

  Future<bool> _currentUserCanManageCategories() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    try {
      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final role = userSnapshot.data()?['role']?.toString();
      if (role == 'super_admin') return true;
      if (role != 'admin') return false;
      final settings = await FirebaseFirestore.instance
          .collection('platform_settings')
          .doc('global')
          .get();
      return settings.data()?['adminCanManageCategories'] == true;
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic> _mapToCategoryModel(Map<String, dynamic> data) {
    final rawIcon = data['iconCode'];
    final name = (data['name'] ?? '').toString().toLowerCase();
    // Icône par nom de catégorie (prioritaire sur iconCode pour garantir la cohérence)
    int iconCode;
    if (name.contains('plomb')) {
      iconCode = Icons.plumbing.codePoint;
    } else if (name.contains('électroménager') ||
        name.contains('electromenager') ||
        name.contains('électro-ménager') ||
        name.contains('appareil')) {
      iconCode = Icons.kitchen.codePoint;
    } else if (name.contains('élec') || name.contains('elec')) {
      iconCode = Icons.electrical_services.codePoint;
    } else if (name.contains('nettoy') ||
        name.contains('ménage') ||
        name.contains('menage')) {
      iconCode = Icons.cleaning_services.codePoint;
    } else if (name.contains('clim') || name.contains('chauffage')) {
      iconCode = Icons.ac_unit.codePoint;
    } else if (name.contains('peint') || name.contains('décoration')) {
      iconCode = Icons.format_paint.codePoint;
    } else if (name.contains('menuis') || name.contains('bois')) {
      iconCode = Icons.carpenter.codePoint;
    } else if (name.contains('serrur') || name.contains('sécur')) {
      iconCode = Icons.lock.codePoint;
    } else if (name.contains('désinsect') ||
        name.contains('desinsect') ||
        name.contains('insect') ||
        name.contains('punais')) {
      iconCode = Icons.pest_control.codePoint;
    } else if (name.contains('cuisine') ||
        name.contains('chef') ||
        name.contains('repas')) {
      iconCode = Icons.restaurant.codePoint;
    } else if (name.contains('bricol') ||
        name.contains('handy') ||
        name.contains('montage')) {
      iconCode = Icons.construction.codePoint;
    } else if (name.contains('jardin')) {
      iconCode = Icons.grass.codePoint;
    } else {
      iconCode = rawIcon is int
          ? rawIcon
          : (rawIcon is IconData
                ? rawIcon.codePoint
                : Icons.category_rounded.codePoint);
    }
    final bgColorHex = data['bgColorHex'] as int? ?? 0xFFE8F0FE;
    final iconColorHex = data['iconColorHex'] as int? ?? 0xFF0D544E;

    return {
      'id': data['id'] ?? 'cat_${DateTime.now().millisecondsSinceEpoch}',
      'name': data['name'] ?? 'Catégorie',
      'pros': data['pros'] is int
          ? data['pros']
          : (int.tryParse('${data['pros']}') ?? 0),
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
        await FirebaseFirestore.instance
            .collection('categories')
            .doc(catId)
            .set({
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
        await FirebaseFirestore.instance
            .collection('categories')
            .doc(id)
            .update(updates);
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
        await FirebaseFirestore.instance
            .collection('categories')
            .doc(id)
            .delete();
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
        return 'Aucun compte DAR PLUS avec mot de passe n\'est associé à cette adresse. Si vous utilisez Google, appuyez sur « Continuer avec Google ».';
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

  static const Set<String> _legacyDemoProIds = {
    'pro_1',
    'pro_2',
    'pro_3',
    'pro_4',
    'pro_5',
  };

  static const List<String> _demoProfessionalNames = [
    'Malek Ben Salem',
    'Yassine Trabelsi',
    'Hichem Gharbi',
    'Amine Ben Youssef',
    'Nizar Jaziri',
    'Marouane Ben Amor',
    'Fares Chaabane',
    'Kais Bouazizi',
    'Youssef Mansour',
    'Bilel Khelifi',
    'Tarek Dridi',
    'Wajdi Kammoun',
    'Mehdi Saidi',
    'Anis Mabrouk',
    'Mohamed Ayari',
    'Seif Ben Romdhane',
    'Adel Jlassi',
    'Mourad Cherif',
    'Hatem Ben Salah',
    'Oussama Baccar',
    'Lotfi Mzoughi',
    'Ridha Mahjoub',
    'Rami Mahfoudh',
    'Ilyes Nafti',
    'Kamel Guesmi',
    'Samir Rekik',
    'Ghazi Hmida',
    'Aymen Karray',
    'Khaled Meddeb',
    'Firas Jebali',
    'Chokri Ktari',
    'Houcine Ben Fredj',
    'Faouzi Ben Mansour',
    'Rafik Mokni',
    'Zied Charfi',
    'Bassem Bouzid',
    'Houssem Ben Rejeb',
    'Moez Ben Abdallah',
    'Kamel Ghanmi',
    'Kais Chouchane',
    'Ahmed Ben Ali',
    'Marwen Hammami',
    'Chaker Khelil',
    'Yassine Bouguerra',
    'Noureddine Kefi',
    'Slim Ben Amor',
    'Skander Sassi',
  ];

  static final List<Map<String, dynamic>> _defaultPros = [
    {
      'id': 'pro_1',
      'name': _demoProfessionalNames[0],
      'serviceType': 'Plomberie',
      'rating': 4.9,
      'reviewsCount': 124,
      'price': '35 TND/h',
      'priceValue': 35,
      'location': 'El Menzah 9',
      'distance': '1.2 km',
      'available': true,
      'avatarAsset': '',
      'phone': '',
      'email': '',
      'experienceYears': 12,
      'bio': 'Profil de démonstration en plomberie à El Menzah.',
      'specialties': [
        'Débouchage',
        'Chauffe-eau',
        'Fuites d\'eau',
        'Rénovation SDB',
      ],
      'badges': ['Démo'],
      'latitude': 36.8562,
      'longitude': 10.1647,
      'demoProfile': true,
      'demoDistanceKm': 1.2,
      'demoBearingDegrees': 35.0,
      'demoReviews': _demoReviews('Plomberie', 4.9, 1),
    },
    {
      'id': 'pro_2',
      'name': _demoProfessionalNames[1],
      'serviceType': 'Électricité',
      'rating': 4.8,
      'reviewsCount': 98,
      'price': '40 TND/h',
      'priceValue': 40,
      'location': 'La Marsa',
      'distance': '2.5 km',
      'available': true,
      'avatarAsset': '',
      'phone': '',
      'email': '',
      'experienceYears': 8,
      'bio': 'Profil de démonstration en électricité à La Marsa.',
      'specialties': [
        'Tableaux électriques',
        'Court-circuit',
        'Éclairage LED',
        'Prises & Câblage',
      ],
      'badges': ['Démo'],
      'latitude': 36.8781,
      'longitude': 10.3247,
      'demoProfile': true,
      'demoDistanceKm': 3.5,
      'demoBearingDegrees': 115.0,
      'demoReviews': _demoReviews('Électricité', 4.8, 2),
    },
    {
      'id': 'pro_3',
      'name': _demoProfessionalNames[2],
      'serviceType': 'Climatisation',
      'rating': 4.7,
      'reviewsCount': 76,
      'price': '50 TND/h',
      'priceValue': 50,
      'location': 'Ennasr 2',
      'distance': '3.1 km',
      'available': true,
      'avatarAsset': '',
      'phone': '',
      'email': '',
      'experienceYears': 10,
      'bio': 'Profil de démonstration en climatisation à Ennasr 2.',
      'specialties': [
        'Entretien & Nettoyage',
        'Recharge Fréon',
        'Installation Split',
        'Dépannage Urgent',
      ],
      'badges': ['Démo'],
      'latitude': 36.8625,
      'longitude': 10.1781,
      'demoProfile': true,
      'demoDistanceKm': 8.0,
      'demoBearingDegrees': 195.0,
      'demoReviews': _demoReviews('Climatisation', 4.7, 3),
    },
    {
      'id': 'pro_4',
      'name': _demoProfessionalNames[3],
      'serviceType': 'Peinture',
      'rating': 4.6,
      'reviewsCount': 62,
      'price': '30 TND/h',
      'priceValue': 30,
      'location': 'Ariana Ville',
      'distance': '4.0 km',
      'available': false,
      'avatarAsset': '',
      'phone': '',
      'email': '',
      'experienceYears': 15,
      'bio': 'Profil de démonstration en peinture à Ariana Ville.',
      'specialties': [
        'Peinture Murale',
        'Enduit & Ponçage',
        'Anti-Humidité',
        'Décoration Stuc',
      ],
      'badges': ['Démo'],
      'latitude': 36.8620,
      'longitude': 10.1930,
      'demoProfile': true,
      'demoDistanceKm': 18.0,
      'demoBearingDegrees': 275.0,
      'demoReviews': _demoReviews('Peinture', 4.6, 4),
    },
    {
      'id': 'pro_5',
      'name': _demoProfessionalNames[4],
      'serviceType': 'Menuiserie',
      'rating': 4.9,
      'reviewsCount': 110,
      'price': '45 TND/h',
      'priceValue': 45,
      'location': 'Carthage',
      'distance': '5.2 km',
      'available': true,
      'avatarAsset': '',
      'phone': '',
      'email': '',
      'experienceYears': 9,
      'bio': 'Profil de démonstration en menuiserie à Carthage.',
      'specialties': [
        'Portes & Serrures',
        'Placards sur mesure',
        'Parquet',
        'Cuisines',
      ],
      'badges': ['Démo'],
      'latitude': 36.8530,
      'longitude': 10.3300,
      'demoProfile': true,
      'demoDistanceKm': 35.0,
      'demoBearingDegrees': 315.0,
      'demoReviews': _demoReviews('Menuiserie', 4.9, 5),
    },
    ..._makeDemoPros(),
  ];

  static List<Map<String, dynamic>> _demoReviews(
    String serviceType,
    double rating,
    int seed,
  ) => [
    {
      'clientName': 'Client démo ${seed.toString().padLeft(2, '0')}',
      'dateLabel': 'Avis de démonstration',
      'rating': rating,
      'comment':
          'Avis fictif pour tester les avis de $serviceType : intervention ponctuelle et explications claires.',
    },
    {
      'clientName': 'Client démo ${(seed + 1).toString().padLeft(2, '0')}',
      'dateLabel': 'Exemple',
      'rating': (rating - 0.2).clamp(1.0, 5.0),
      'comment': 'Témoignage de démonstration, ce commentaire ne correspond pas à un vrai client.',
    },
  ];

  /// Profils fictifs réservés à l'aperçu local quand aucun vrai pro n'est publié.
  static List<Map<String, dynamic>> _makeDemoPros() {
    const entries = <(String, String, double, double, int, int)>[
      ('Plomberie', 'Tunis', 36.8065, 10.1815, 35, 1),
      ('Plomberie', 'Ariana', 36.8625, 10.1956, 40, 2),
      ('Plomberie', 'Bizerte', 37.2744, 9.8739, 45, 3),
      ('Électricité', 'La Marsa', 36.8781, 10.3247, 40, 1),
      ('Électricité', 'Nabeul', 36.4513, 10.7357, 45, 2),
      ('Électricité', 'Hammamet', 36.4000, 10.6167, 42, 3),
      ('Nettoyage', 'Tunis', 36.8008, 10.1800, 25, 1),
      ('Nettoyage', 'Ben Arous', 36.7531, 10.2189, 28, 2),
      ('Nettoyage', 'Bizerte', 37.2744, 9.8739, 30, 3),
      ('Climatisation', 'Ariana', 36.8625, 10.1956, 50, 1),
      ('Climatisation', 'Hammamet', 36.4000, 10.6167, 55, 2),
      ('Climatisation', 'Sousse', 35.8256, 10.6369, 60, 3),
      ('Peinture', 'Tunis', 36.8065, 10.1815, 30, 1),
      ('Peinture', 'Nabeul', 36.4513, 10.7357, 35, 2),
      ('Peinture', 'Sousse', 35.8256, 10.6369, 38, 3),
      ('Serrurerie', 'Tunis', 36.8065, 10.1815, 35, 1),
      ('Serrurerie', 'Bizerte', 37.2744, 9.8739, 40, 2),
      ('Serrurerie', 'La Marsa', 36.8781, 10.3247, 38, 3),
      ('Bricolage', 'Ariana', 36.8625, 10.1956, 30, 1),
      ('Bricolage', 'Hammamet', 36.4000, 10.6167, 35, 2),
      ('Bricolage', 'Sousse', 35.8256, 10.6369, 40, 3),
      ('Jardinage', 'La Marsa', 36.8781, 10.3247, 30, 1),
      ('Jardinage', 'Nabeul', 36.4513, 10.7357, 35, 2),
      ('Jardinage', 'Sousse', 35.8256, 10.6369, 40, 3),
      ('Menuiserie', 'Tunis', 36.8065, 10.1815, 45, 1),
      ('Menuiserie', 'Hammamet', 36.4000, 10.6167, 50, 2),
      ('Réfrigérateur', 'Ariana', 36.8625, 10.1956, 45, 1),
      ('Réfrigérateur', 'Tunis', 36.8065, 10.1815, 50, 2),
      ('Réfrigérateur', 'Sousse', 35.8256, 10.6369, 55, 3),
      ('Machine à laver', 'Sousse', 35.8256, 10.6369, 48, 2),
      ('Machine à laver', 'Tunis', 36.8065, 10.1815, 45, 1),
      ('Machine à laver', 'Nabeul', 36.4513, 10.7357, 50, 3),
      ('Coiffure', 'Tunis', 36.8065, 10.1815, 25, 1),
      ('Coiffure', 'La Marsa', 36.8781, 10.3247, 30, 2),
      ('Coiffure', 'Hammamet', 36.4000, 10.6167, 35, 3),
      ('Nettoyage Canapé', 'La Marsa', 36.8781, 10.3247, 35, 2),
      ('Nettoyage Canapé', 'Tunis', 36.8065, 10.1815, 30, 1),
      ('Nettoyage Canapé', 'Bizerte', 37.2744, 9.8739, 40, 3),
      ('Ménage', 'Nabeul', 36.4513, 10.7357, 25, 3),
      ('Ménage', 'Tunis', 36.8065, 10.1815, 22, 1),
      ('Ménage', 'Hammamet', 36.4000, 10.6167, 28, 2),
    ];

    return List.generate(entries.length, (index) {
      final (service, city, latitude, longitude, price, variant) =
          entries[index];
      final id = 'demo_pro_${(index + 1).toString().padLeft(2, '0')}';
      final nameIndex = index + 5;
      final rating = 4.5 + (variant / 10);
      return {
        'id': id,
        'name': _demoProfessionalNames[nameIndex],
        'serviceType': service,
        'rating': rating,
        'reviewsCount': 8 + (index * 3),
        'price': '$price TND/h',
        'priceValue': price,
        'location': city,
        'distance': 'Calculée selon votre position',
        'available': variant != 3,
        'phone': '',
        'email': '',
        'experienceYears': 2 + variant,
        'bio':
            'Profil de démonstration pour la catégorie $service à $city. '
            'Les professionnels réels apparaîtront dès leur inscription et validation.',
        'specialties': [service],
        'badges': ['Démo'],
        'latitude': latitude,
        'longitude': longitude,
        'demoProfile': true,
        'demoDistanceKm': const [
          1.2,
          3.5,
          8.0,
          18.0,
          35.0,
          70.0,
          125.0,
          155.0,
        ][index % 8],
        'demoBearingDegrees': (index * 137.5) % 360,
        'demoReviews': _demoReviews(service, rating, index + 6),
      };
    });
  }

  /// Retourne uniquement les professionnels approuvés et leurs données réellement enregistrées.
  Future<List<Map<String, dynamic>>> getAiProfessionals() async {
    final user = FirebaseAuth.instance.currentUser;
    if (!_isFirebaseInitialized || user == null) {
      throw StateError(
        'Une session Firebase active est nécessaire pour les recommandations IA.',
      );
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'professionnel')
        .where('isApproved', isEqualTo: true)
        .get();

    return snapshot.docs
        .where(
          (doc) =>
              doc.data()['demoProfile'] != true &&
              !_legacyDemoProIds.contains(doc.id),
        )
        .map((doc) {
          final data = doc.data();
          final rawPrice = data['price'];
          final rawPriceValue = data['priceValue'];
          final parsedPrice = rawPriceValue != null
              ? _parseStoredPrice(rawPriceValue)
              : _parseStoredPrice(rawPrice);
          final priceLabel = rawPrice?.toString().trim().isNotEmpty == true
              ? rawPrice.toString()
              : rawPriceValue?.toString();
          final rawRating = data['rating'];
          final rawSpecialties = data['specialties'];

          return {
            'id': doc.id,
            'name': data['fullName']?.toString() ?? '',
            'serviceType': data['serviceType']?.toString() ?? '',
            'specialties': rawSpecialties is List
                ? rawSpecialties.map((value) => value.toString()).toList()
                : <String>[],
            'rating': rawRating is num ? rawRating.toDouble() : null,
            'reviewsCount': data['reviewsCount'] is num
                ? (data['reviewsCount'] as num).toInt()
                : null,
            'hasStoredReviewCount': data['reviewsCount'] is num,
            'priceValue': parsedPrice,
            'priceLabel': priceLabel,
            'price': priceLabel,
            'hasStoredPrice': parsedPrice != null,
            'location': data['location']?.toString(),
            'hasStoredLocation':
                data['location'] is String &&
                (data['location'] as String).trim().isNotEmpty,
            'available': data['available'] is bool ? data['available'] : null,
            'hasStoredAvailability': data['available'] is bool,
            'phone': data['phone']?.toString() ?? '',
            'hasStoredPhone':
                data['phone'] is String &&
                (data['phone'] as String).trim().isNotEmpty,
            'bio': data['bio']?.toString() ?? '',
            'hasStoredBio':
                data['bio'] is String &&
                (data['bio'] as String).trim().isNotEmpty,
            'photoBase64': data['photoBase64']?.toString() ?? '',
            'hasStoredRating': rawRating is num,
            'hasStoredSpecialties':
                rawSpecialties is List && rawSpecialties.isNotEmpty,
            'hasStoredDistance': false,
          };
        })
        .where((pro) {
          return (pro['name'] as String).trim().isNotEmpty &&
              (pro['serviceType'] as String).trim().isNotEmpty;
        })
        .toList();
  }

  double? _parseStoredPrice(Object? value) {
    if (value is num) return value.toDouble();
    if (value is! String) return null;
    final match = RegExp(r'\d+(?:[.,]\d+)?').firstMatch(value);
    if (match == null) return null;
    return double.tryParse(match.group(0)!.replaceAll(',', '.'));
  }

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
              final isDemoProfile =
                  data['demoProfile'] == true ||
                  _legacyDemoProIds.contains(doc.id);
              return {
                'id': doc.id,
                'name': data['fullName'] ?? 'Artisan',
                'serviceType': data['serviceType'] ?? 'Services divers',
                'rating': (data['rating'] is num)
                    ? (data['rating'] as num).toDouble()
                    : null,
                'reviewsCount': data['reviewsCount'] is num
                    ? (data['reviewsCount'] as num).toInt()
                    : null,
                'price': data['price'] ?? '35 TND/h',
                'priceValue': data['priceValue'] ?? 35,
                'location': data['location'] ?? 'Grand Tunis',
                'distance': data['distance'] ?? '2.0 km',
                'available': data['available'] ?? true,
                'phone': isDemoProfile ? '' : (data['phone'] ?? ''),
                'email': data['email'] ?? '',
                'bio':
                    data['bio'] ??
                    'Professionnel vérifié et certifié par DAR PLUS.',
                'experienceYears': data['experienceYears'],
                'specialties':
                    data['specialties'] ?? [data['serviceType'] ?? 'Artisan'],
                'badges': isDemoProfile ? ['Démo'] : ['Vérifié DAR+'],
                'demoProfile': isDemoProfile,
                'photoBase64': data['photoBase64'] ?? '',
                'photoUrl': data['photoUrl'] ?? '',
                'latitude': data['latitude'] is num
                    ? (data['latitude'] as num).toDouble()
                    : null,
                'longitude': data['longitude'] is num
                    ? (data['longitude'] as num).toDouble()
                    : null,
              };
            }).toList();

            final realPros = list
                .where((pro) => pro['demoProfile'] != true)
                .toList();
            // Les profils fictifs servent uniquement à prévisualiser toutes
            // les catégories pendant le développement.
            list = kDebugMode ? [...realPros, ..._defaultPros] : realPros;

            return _applyFilters(
              list,
              category,
              searchQuery,
              onlyAvailable,
              sortBy,
            );
          });
    }

    // Fallback Local
    return Stream.value(
      _applyFilters(
        kDebugMode ? List.from(_defaultPros) : <Map<String, dynamic>>[],
        category,
        searchQuery,
        onlyAvailable,
        sortBy,
      ),
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

    if (category != null &&
        category.isNotEmpty &&
        category.toLowerCase() != 'tous') {
      filtered = filtered
          .where(
            (p) => (p['serviceType'] as String).toLowerCase().contains(
              category.toLowerCase(),
            ),
          )
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
      filtered.sort(
        (a, b) => ((b['rating'] as num?)?.toDouble() ?? 0).compareTo(
          (a['rating'] as num?)?.toDouble() ?? 0,
        ),
      );
    } else if (sortBy == 'price_asc') {
      filtered.sort(
        (a, b) => (a['priceValue'] as num).compareTo(b['priceValue'] as num),
      );
    } else if (sortBy == 'price_desc') {
      filtered.sort(
        (a, b) => (b['priceValue'] as num).compareTo(a['priceValue'] as num),
      );
    }

    return filtered;
  }

  /// Demande la permission de localisation puis enregistre la position GPS
  /// actuelle du professionnel dans son profil (`users/{uid}`).
  /// Retourne `true` si la position a bien été enregistrée.
  Future<bool> updateProfessionalLocation() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      if (!await Geolocator.isLocationServiceEnabled()) return false;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return false;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'isLocationSharing': true,
        'locationUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _professionalLocationSubscription?.cancel();
      _professionalLocationSubscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 20,
            ),
          ).listen((updatedPosition) {
            final activeUser = FirebaseAuth.instance.currentUser;
            if (activeUser == null || activeUser.uid != user.uid) return;
            FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .set({
                  'latitude': updatedPosition.latitude,
                  'longitude': updatedPosition.longitude,
                  'isLocationSharing': true,
                  'locationUpdatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true))
                .catchError((Object _) {});
          }, onError: (Object _) {});

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Arrête le partage de position et retire les coordonnées visibles par les clients.
  Future<bool> stopProfessionalLocationSharing() async {
    await _professionalLocationSubscription?.cancel();
    _professionalLocationSubscription = null;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'latitude': FieldValue.delete(),
        'longitude': FieldValue.delete(),
        'locationUpdatedAt': FieldValue.delete(),
        'isLocationSharing': false,
      }, SetOptions(merge: true));
      return true;
    } catch (_) {
      return false;
    }
  }

  // ================= GESTION RÉELLE DES RÉSERVATIONS (COLLECTION 'bookings') =================

  static final List<Map<String, dynamic>> _localBookings = [];

  /// Créer une vraie réservation dans Firestore
  Future<Map<String, dynamic>> createBooking({
    required String proId,
    required String proName,
    required String proPhone,
    String proPhotoBase64 = '',
    String proPhotoUrl = '',
    String proLocation = '',
    String proBio = '',
    int? proExperienceYears,
    required String serviceType,
    required String price,
    required String address,
    required String description,
    String? scheduledDate,
    String? scheduledDateKey,
    String? scheduledTime,
    double? clientLatitude,
    double? clientLongitude,
    bool isUrgent = false,
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
        'baseAmount': _extractBookingAmount(price),
        'clientId': clientId,
        'clientName': clientName,
        'clientEmail': clientEmail,
        'clientPhone': clientPhone,
        'clientPhotoBase64': userData?['photoBase64']?.toString() ?? '',
        'clientPhotoUrl': userData?['photoUrl']?.toString() ?? '',
        'proId': proId,
        'proName': proName,
        'proPhone': proPhone,
        if (proPhotoBase64.trim().isNotEmpty)
          'proPhotoBase64': proPhotoBase64.trim(),
        if (proPhotoUrl.trim().isNotEmpty) 'proPhotoUrl': proPhotoUrl.trim(),
        if (proLocation.trim().isNotEmpty) 'proLocation': proLocation.trim(),
        if (proBio.trim().isNotEmpty) 'proBio': proBio.trim(),
        if (proExperienceYears != null)
          'proExperienceYears': proExperienceYears,
        'serviceType': serviceType,
        'price': price,
        'address': address.trim(),
        if (clientLatitude != null && clientLongitude != null) ...{
          'clientLatitude': clientLatitude,
          'clientLongitude': clientLongitude,
          'clientLocationShared': true,
        },
        'description': description.trim(),
        if (isUrgent || description.trimLeft().startsWith('🚨'))
          'isUrgent': true,
        'scheduledDate': scheduledDate ?? 'Dès que possible',
        if (scheduledDateKey != null) 'scheduledDateKey': scheduledDateKey,
        if (scheduledTime != null) 'scheduledTime': scheduledTime,
        'status':
            'en_attente', // 'en_attente', 'confirmee', 'terminee', 'annulee'
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (_isFirebaseInitialized) {
        final firestore = FirebaseFirestore.instance;
        final docRef = firestore.collection('bookings').doc();
        final slotId = scheduledDateKey != null && scheduledTime != null
            ? '${scheduledDateKey}_${scheduledTime.replaceAll(':', '')}'
            : null;
        final slotRef = slotId == null
            ? null
            : firestore
                  .collection('pro_availability')
                  .doc(proId)
                  .collection('slots')
                  .doc(slotId);
        await firestore.runTransaction((transaction) async {
          if (slotRef != null) {
            final slot = await transaction.get(slotRef);
            if (slot.exists) {
              throw StateError(
                'Ce créneau vient d’être réservé. Choisissez une autre heure.',
              );
            }
          }
          transaction.set(docRef, bookingData);
          if (slotRef != null) {
            transaction.set(slotRef, {
              'proId': proId,
              'bookingId': docRef.id,
              'clientId': clientId,
              'dateKey': scheduledDateKey,
              'time': scheduledTime,
              'status': 'reserved',
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
        });
        bookingData['id'] = docRef.id;
        _localBookings.insert(0, Map<String, dynamic>.from(bookingData));

        // Journal de sécurité
        await logSecurityEvent(
          action: 'CREATE_BOOKING',
          actorEmail: clientEmail.isNotEmpty ? clientEmail : 'Client',
          target: proName,
          details:
              'Réservation $serviceType créée pour $proName par $clientName (ID: ${docRef.id})',
        );

        // Notification in-app pour le pro
        try {
          await FirebaseFirestore.instance.collection('notifications').add({
            'recipientId': proId,
            'type': 'new_booking',
            'title': 'Nouvelle demande de service',
            'body': '$clientName demande "$serviceType" — $serviceType',
            'bookingId': docRef.id,
            'clientName': clientName,
            'serviceType': serviceType,
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } catch (_) {}

        return {
          'success': true,
          'id': docRef.id,
          'message': 'Réservation créée avec succès !',
        };
      } else {
        final mockId = 'booking_${DateTime.now().millisecondsSinceEpoch}';
        bookingData['id'] = mockId;
        _localBookings.insert(0, Map<String, dynamic>.from(bookingData));
        return {
          'success': true,
          'id': mockId,
          'message': 'Réservation créée (Mode local)',
        };
      }
    } catch (e) {
      debugPrint('Erreur createBooking: $e');
      return {
        'success': false,
        'message': 'Erreur lors de la réservation : $e',
      };
    }
  }

  Future<Map<String, dynamic>> resendClientVerificationEmail({
    String? languageCode,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (!_isFirebaseInitialized || user == null) {
      return {
        'success': false,
        'message': 'Reconnectez-vous pour renvoyer l\'e-mail de vérification.',
      };
    }
    try {
      await user.reload();
      final refreshedUser = FirebaseAuth.instance.currentUser ?? user;
      if (refreshedUser.emailVerified) {
        return {
          'success': true,
          'verified': true,
          'message': 'Cette adresse e-mail est déjà vérifiée.',
        };
      }
      final email = refreshedUser.email;
      if (email == null || email.trim().isEmpty) {
        return {
          'success': false,
          'message': 'Aucune adresse e-mail n\'est associée à ce compte.',
        };
      }
      final mailResult = await EmailService.sendFirebaseAuthEmail(
        type: 'emailVerification',
        toEmail: email,
        userName: refreshedUser.displayName ?? email.split('@').first,
        languageCode: languageCode ?? 'fr',
      );
      if (!mailResult.sent) {
        return {
          'success': false,
          'message':
              mailResult.error ?? 'EmailJS n\'a pas pu envoyer l\'e-mail.',
        };
      }
      return {
        'success': true,
        'message':
            'E-mail de vérification renvoyé. Consultez votre boîte mail.',
      };
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'message': _getAuthErrorMessage(e.code)};
    } catch (e) {
      return {
        'success': false,
        'message': 'Impossible d\'envoyer l\'e-mail : $e',
      };
    }
  }

  /// Créneaux réservés d’un professionnel, sans exposer les informations client.
  Stream<List<Map<String, dynamic>>> streamProReservedSlots(String proId) {
    if (_isFirebaseInitialized && proId.isNotEmpty) {
      return FirebaseFirestore.instance
          .collection('pro_availability')
          .doc(proId)
          .collection('slots')
          .snapshots()
          .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
    }
    return Stream.value(const <Map<String, dynamic>>[]);
  }

  Stream<List<Map<String, dynamic>>> streamCurrentProReservedSlots() {
    final proId = FirebaseAuth.instance.currentUser?.uid ?? '';
    return streamProReservedSlots(proId);
  }

  Future<Map<String, dynamic>> getCurrentProAvailabilitySettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (!_isFirebaseInitialized || user == null) return const {};
    final snapshot = await FirebaseFirestore.instance
        .collection('pro_availability')
        .doc(user.uid)
        .get();
    return snapshot.data() ?? const {};
  }

  Future<void> saveCurrentProAvailabilitySettings({
    required int workStartMinutes,
    required int workEndMinutes,
    required List<String> unavailableSlots,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (!_isFirebaseInitialized || user == null) {
      throw StateError('Connectez-vous pour enregistrer vos disponibilités.');
    }
    if (workStartMinutes < 0 ||
        workEndMinutes > 1440 ||
        workStartMinutes >= workEndMinutes ||
        unavailableSlots.length > 3000) {
      throw ArgumentError('Horaires ou créneaux invalides.');
    }
    await FirebaseFirestore.instance
        .collection('pro_availability')
        .doc(user.uid)
        .set({
          'workStartMinutes': workStartMinutes,
          'workEndMinutes': workEndMinutes,
          'unavailableSlots': unavailableSlots,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Stream<Map<String, dynamic>> streamProAvailabilitySettings(String proId) {
    if (_isFirebaseInitialized && proId.isNotEmpty) {
      return FirebaseFirestore.instance
          .collection('pro_availability')
          .doc(proId)
          .snapshots()
          .map((snapshot) => snapshot.data() ?? const <String, dynamic>{});
    }
    return Stream.value(const <String, dynamic>{});
  }

  /// Écoute en temps réel des réservations du client connecté
  Stream<List<Map<String, dynamic>>> streamClientBookings({
    String? statusFilter,
  }) {
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

        if (statusFilter != null &&
            statusFilter.isNotEmpty &&
            statusFilter != 'Toutes') {
          final filterNorm = _normalizeStatus(statusFilter);
          list = list
              .where(
                (b) =>
                    _normalizeStatus(b['status']?.toString() ?? '') ==
                    filterNorm,
              )
              .toList();
        }

        return list;
      });
    }

    // Fallback local en mémoire
    var list = List<Map<String, dynamic>>.from(_localBookings);
    if (statusFilter != null &&
        statusFilter.isNotEmpty &&
        statusFilter != 'Toutes') {
      final filterNorm = _normalizeStatus(statusFilter);
      list = list
          .where(
            (b) =>
                _normalizeStatus(b['status']?.toString() ?? '') == filterNorm,
          )
          .toList();
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
          return 'Auj. ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        }
        final diff = dt.difference(now);
        if (diff.inDays == 1)
          return 'Demain ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
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
          data['dateLabel'] = fmtDate(
            data['scheduledDate'] ?? data['createdAt'],
          );
          return data;
        }).toList();

        list.sort((a, b) {
          final aDate = a['createdAt'];
          final bDate = b['createdAt'];
          if (aDate is Timestamp && bDate is Timestamp)
            return bDate.compareTo(aDate);
          return 0;
        });

        if (statusFilter != null && statusFilter.isNotEmpty) {
          final f = _normalizeStatus(statusFilter);
          list = list
              .where(
                (b) => _normalizeStatus(b['status']?.toString() ?? '') == f,
              )
              .toList();
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
      list = list
          .where((b) => _normalizeStatus(b['status']?.toString() ?? '') == f)
          .toList();
    }
    return Stream.value(list);
  }

  /// Met à jour le statut d'une réservation (pro accepte / refuse) + notif client
  Future<bool> updateBookingStatus(String bookingId, String newStatus) async {
    try {
      if (_isFirebaseInitialized) {
        final firestore = FirebaseFirestore.instance;
        final bookingRef = firestore.collection('bookings').doc(bookingId);
        await firestore.runTransaction((transaction) async {
          final bookingSnapshot = await transaction.get(bookingRef);
          final data = bookingSnapshot.data();
          final proId = data?['proId']?.toString() ?? '';
          final dateKey = data?['scheduledDateKey']?.toString() ?? '';
          final time = data?['scheduledTime']?.toString() ?? '';
          transaction.update(bookingRef, {
            'status': newStatus,
            'updatedAt': FieldValue.serverTimestamp(),
            if (newStatus == 'confirmee')
              'acceptedAt': FieldValue.serverTimestamp(),
          });
          if (newStatus == 'annulee' &&
              proId.isNotEmpty &&
              dateKey.isNotEmpty &&
              time.isNotEmpty) {
            transaction.delete(
              firestore
                  .collection('pro_availability')
                  .doc(proId)
                  .collection('slots')
                  .doc('${dateKey}_${time.replaceAll(':', '')}'),
            );
          }
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
            final price = data['price'] as String? ?? '';
            final priceMatch = RegExp(r'(\d+([.,]\d+)?)').firstMatch(price);
            final baseAmount = priceMatch != null
                ? double.tryParse(priceMatch.group(1)!.replaceAll(',', '.')) ??
                      45.0
                : 45.0;

            if (clientId != null &&
                clientId.isNotEmpty &&
                clientId != 'client_anon') {
              String title = '';
              String body = '';

              if (newStatus == 'confirmee') {
                title = ' Demande acceptée';
                body =
                    '$proName a accepté votre demande de $serviceType. Appuyez ici pour procéder au paiement.';
              } else if (newStatus == 'annulee') {
                title = ' Demande refusée';
                body =
                    '$proName ne peut pas prendre en charge votre demande de $serviceType.';
              } else if (newStatus == 'terminee') {
                title = ' Intervention terminée';
                body =
                    '$proName a marqué l\'intervention "$serviceType" comme terminée.';
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
                      'proId': data['proId'],
                      'proName': proName,
                      'serviceType': serviceType,
                      'baseAmount': baseAmount,
                      'address': data['address'],
                      'scheduledDate': data['scheduledDate'],
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
              data['clientName'] =
                  data['reviewerName'] ?? data['clientName'] ?? 'Client';
              final ts = data['createdAt'];
              if (ts is Timestamp) {
                final dt = ts.toDate();
                final diff = DateTime.now().difference(dt);
                if (diff.inMinutes < 1)
                  data['timeLabel'] = 'À l\'instant';
                else if (diff.inMinutes < 60)
                  data['timeLabel'] = 'Il y a ${diff.inMinutes} min';
                else if (diff.inHours < 24)
                  data['timeLabel'] = 'Il y a ${diff.inHours}h';
                else
                  data['timeLabel'] = 'Il y a ${diff.inDays}j';
              } else {
                data['timeLabel'] = '';
              }
              return data;
            }).toList();
            // Tri côté client par createdAt décroissant
            list.sort((a, b) {
              final aTs = a['createdAt'];
              final bTs = b['createdAt'];
              if (aTs is Timestamp && bTs is Timestamp)
                return bTs.compareTo(aTs);
              return 0;
            });
            return list;
          });
    }
    return Stream.value([]);
  }

  Stream<Map<String, dynamic>> streamCurrentUserRatingSummary() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Stream.value({'rating': null, 'reviewsCount': 0});
    }
    return streamRatingSummary(uid);
  }

  Stream<Map<String, dynamic>> streamRatingSummary(String targetId) {
    final demoProfile = _findDemoProfile(targetId);
    if (demoProfile != null) {
      return Stream.value({
        'rating': demoProfile['rating'],
        'reviewsCount': demoProfile['reviewsCount'],
      });
    }
    if (!_isFirebaseInitialized || targetId.trim().isEmpty) {
      return Stream.value({'rating': null, 'reviewsCount': 0});
    }
    return FirebaseFirestore.instance
        .collection('reviews')
        .where('targetId', isEqualTo: targetId)
        .snapshots()
        .map((snapshot) {
          final ratings = snapshot.docs
              .map((doc) => doc.data()['rating'])
              .whereType<num>()
              .map((rating) => rating.toDouble())
              .toList();
          if (ratings.isEmpty) return {'rating': null, 'reviewsCount': 0};
          final total = ratings.fold<double>(0, (sum, value) => sum + value);
          return {
            'rating': (total / ratings.length * 10).round() / 10,
            'reviewsCount': ratings.length,
          };
        });
  }

  /// Nombre total de messages non lus pour l'utilisateur connecté.
  /// [isPro] = true → professionnel (compte unreadPro), sinon client (unreadClient).
  Stream<int> streamUnreadMessageCount({required bool isPro}) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    if (uid == null) return Stream.value(0);

    final field = isPro ? 'unreadPro' : 'unreadClient';
    final queryField = isPro ? 'proId' : 'clientId';

    return FirebaseFirestore.instance
        .collection('bookings')
        .where(queryField, isEqualTo: uid)
        .snapshots()
        .map((snap) {
          var total = 0;
          for (final d in snap.docs) {
            final v = d.data()[field];
            if (v is num) total += v.toInt();
          }
          return total;
        });
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
    final demoProfile = _findDemoProfile(proId);
    if (demoProfile != null) {
      final reviews = demoProfile['demoReviews'];
      return Stream.value(
        reviews is List
            ? reviews.cast<Map<String, dynamic>>()
            : const <Map<String, dynamic>>[],
      );
    }
    if (_isFirebaseInitialized) {
      return FirebaseFirestore.instance
          .collection('reviews')
          .where('proId', isEqualTo: proId)
          .orderBy('createdAt', descending: true)
          .limit(10)
          .snapshots()
          .map(
            (snap) => snap.docs.map((d) {
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
            }).toList(),
          );
    }
    return Stream.value([]);
  }

  Map<String, dynamic>? _findDemoProfile(String id) {
    for (final pro in _defaultPros) {
      if (pro['id'] == id) return pro;
    }
    return null;
  }

  Future<void> submitBookingRating({
    required String bookingId,
    required int rating,
    String comment = '',
    Map<String, int> categoryRatings = const {},
    List<String> tags = const [],
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (!_isFirebaseInitialized || user == null) {
      throw StateError('Connectez-vous pour envoyer une évaluation.');
    }
    final cleanComment = comment.trim();
    const allowedCategoryRatings = {
      'punctuality',
      'quality',
      'price',
      'communication',
    };
    const allowedTags = {
      'punctual',
      'professional',
      'clean',
      'fast',
      'fair_price',
    };
    if (bookingId.isEmpty ||
        rating < 1 ||
        rating > 5 ||
        cleanComment.length > 500 ||
        categoryRatings.keys.any(
          (key) => !allowedCategoryRatings.contains(key),
        ) ||
        categoryRatings.values.any((value) => value < 1 || value > 5) ||
        tags.length > allowedTags.length ||
        tags.any((tag) => !allowedTags.contains(tag))) {
      throw ArgumentError('Évaluation invalide.');
    }

    final firestore = FirebaseFirestore.instance;
    final bookingRef = firestore.collection('bookings').doc(bookingId);
    final reviewerRef = firestore.collection('users').doc(user.uid);
    final notificationRef = firestore.collection('notifications').doc();
    await firestore.runTransaction((transaction) async {
      final bookingSnapshot = await transaction.get(bookingRef);
      final reviewerSnapshot = await transaction.get(reviewerRef);
      if (!bookingSnapshot.exists || !reviewerSnapshot.exists) {
        throw StateError('Réservation ou profil introuvable.');
      }
      final booking = bookingSnapshot.data()!;
      final reviewer = reviewerSnapshot.data()!;
      if (booking['status'] != 'terminee') {
        throw StateError(
          'La réservation doit être terminée pour être évaluée.',
        );
      }

      final reviewerRole = booking['clientId'] == user.uid
          ? 'client'
          : booking['proId'] == user.uid
          ? 'professionnel'
          : null;
      if (reviewerRole == null || reviewer['role'] != reviewerRole) {
        throw StateError('Vous ne participez pas à cette réservation.');
      }
      final reviewId = '${bookingId}_$reviewerRole';
      final reviewRef = firestore.collection('reviews').doc(reviewId);
      final reviewSnapshot = await transaction.get(reviewRef);
      final submittedKey = reviewerRole == 'client'
          ? 'clientReviewSubmitted'
          : 'proReviewSubmitted';
      if (reviewSnapshot.exists || booking[submittedKey] == true) {
        throw StateError('Vous avez déjà évalué cette réservation.');
      }

      final targetId = reviewerRole == 'client'
          ? booking['proId']?.toString() ?? ''
          : booking['clientId']?.toString() ?? '';
      if (targetId.isEmpty) throw StateError('Profil à évaluer introuvable.');
      final targetRole = reviewerRole == 'client' ? 'professionnel' : 'client';
      transaction.set(reviewRef, {
        'bookingId': bookingId,
        'reviewerId': user.uid,
        'reviewerName': reviewer['fullName']?.toString() ?? 'Utilisateur',
        'reviewerRole': reviewerRole,
        'targetId': targetId,
        'targetRole': targetRole,
        'proId': booking['proId'],
        'rating': rating,
        'comment': cleanComment,
        if (categoryRatings.isNotEmpty) 'categoryRatings': categoryRatings,
        if (tags.isNotEmpty) 'tags': tags,
        'serviceType': booking['serviceType']?.toString() ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.update(bookingRef, {
        submittedKey: true,
        if (reviewerRole == 'client')
          'clientRating': rating
        else
          'proRating': rating,
      });
      final reviewerName = reviewer['fullName']?.toString() ?? 'Utilisateur';
      final serviceType = booking['serviceType']?.toString() ?? '';
      transaction.set(notificationRef, {
        'recipientId': targetId,
        'type': 'booking_review_received',
        'title': 'Nouvel avis reçu',
        'body': '$reviewerName vous a attribué $rating/5 pour $serviceType.',
        'bookingId': bookingId,
        'reviewerId': user.uid,
        'reviewerName': reviewerName,
        'reviewerRole': reviewerRole,
        'rating': rating,
        'serviceType': serviceType,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<Map<String, String>> getBookingClientPhoto(
    Map<String, dynamic> booking,
  ) {
    final base64Photo = booking['clientPhotoBase64']?.toString().trim() ?? '';
    final photoUrl = booking['clientPhotoUrl']?.toString().trim() ?? '';
    if (base64Photo.isNotEmpty || photoUrl.isNotEmpty) {
      return Future.value({'photoBase64': base64Photo, 'photoUrl': photoUrl});
    }
    // The booking already carries the client's consented photo snapshot.
    // Avoid a Cloud Function lookup here: that function may not be deployed,
    // and an avatar lookup must never prevent a professional from opening a
    // booking (especially an urgent request).
    return Future.value(const {});
  }

  /// Annuler une réservation
  Future<bool> cancelBooking(String bookingId) async {
    try {
      if (_isFirebaseInitialized) {
        final firestore = FirebaseFirestore.instance;
        final bookingRef = firestore.collection('bookings').doc(bookingId);
        await firestore.runTransaction((transaction) async {
          final bookingSnapshot = await transaction.get(bookingRef);
          final data = bookingSnapshot.data();
          final proId = data?['proId']?.toString() ?? '';
          final dateKey = data?['scheduledDateKey']?.toString() ?? '';
          final time = data?['scheduledTime']?.toString() ?? '';
          transaction.update(bookingRef, {
            'status': 'annulee',
            'cancelledAt': FieldValue.serverTimestamp(),
          });
          if (proId.isNotEmpty && dateKey.isNotEmpty && time.isNotEmpty) {
            transaction.delete(
              firestore
                  .collection('pro_availability')
                  .doc(proId)
                  .collection('slots')
                  .doc('${dateKey}_${time.replaceAll(':', '')}'),
            );
          }
        });
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
    if (lower.contains('attente') || lower.contains('pending'))
      return 'en_attente';
    if (lower.contains('confirm') || lower.contains('accept'))
      return 'confirmee';
    if (lower.contains('termin') || lower.contains('complet'))
      return 'terminee';
    if (lower.contains('annul') || lower.contains('cancel')) return 'annulee';
    return lower;
  }

  double _extractBookingAmount(String price) {
    final match = RegExp(r'(\d+([.,]\d+)?)').firstMatch(price);
    if (match == null) return 0;
    return double.tryParse(match.group(1)!.replaceAll(',', '.')) ?? 0;
  }

  Future<void> _seedDefaultProsToFirestore() async {
    try {
      // Les comptes fictifs ne doivent jamais être créés sur le projet Firebase réel.
      if (!_isFirebaseInitialized || !FirebaseEmulatorConfig.enabled) return;
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'professionnel')
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        debugPrint(
          'Ensemencement des professionnels initiaux dans Firestore...',
        );
        final batch = FirebaseFirestore.instance.batch();
        for (final pro in _defaultPros) {
          final doc = FirebaseFirestore.instance
              .collection('users')
              .doc(pro['id'] as String);
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
            'latitude': pro['latitude'],
            'longitude': pro['longitude'],
            'demoProfile': true,
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
      final proId = (pro['id'] ?? pro['uid'] ?? 'pro_${pro['name']}')
          .toString();
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

  // ── Disponibilité du Pro ──────────────────────────────────────────────────

  /// Met à jour le champ `available` du pro connecté dans Firestore
  Future<void> updateProAvailability(bool available) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      if (_isFirebaseInitialized) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
              'available': available,
              'updatedAt': FieldValue.serverTimestamp(),
            });
      }
    } catch (e) {
      debugPrint('Erreur updateProAvailability: $e');
      rethrow;
    }
  }

  // ── Services du Pro ───────────────────────────────────────────────────────

  /// Stream des services créés par le pro connecté
  Stream<List<Map<String, dynamic>>> streamMyServices() {
    final user = FirebaseAuth.instance.currentUser;
    if (_isFirebaseInitialized && user != null) {
      return FirebaseFirestore.instance
          .collection('pro_services')
          .where('proId', isEqualTo: user.uid)
          .snapshots()
          .map(
            (snap) => snap.docs.map((d) {
              final data = d.data();
              data['id'] = d.id;
              return data;
            }).toList(),
          );
    }
    return Stream.value([]);
  }

  /// Crée ou met à jour un service du pro connecté
  Future<void> saveMyService({
    String? id,
    required String name,
    required String description,
    required double price,
    String? photoUrl,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Non connecté');
    final data = {
      'proId': user.uid,
      'name': name.trim(),
      'description': description.trim(),
      'price': price,
      'photoUrl': photoUrl?.trim() ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (_isFirebaseInitialized) {
      if (id != null && id.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('pro_services')
            .doc(id)
            .update(data);
      } else {
        data['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('pro_services').add(data);
      }
    }
  }

  /// Supprime un service du pro connecté
  Future<void> deleteMyService(String serviceId) async {
    if (_isFirebaseInitialized) {
      await FirebaseFirestore.instance
          .collection('pro_services')
          .doc(serviceId)
          .delete();
    }
  }

  CollectionReference<Map<String, dynamic>> _aiConversations(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('ai_conversations');
  }

  User _requireAiUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (!_isFirebaseInitialized || user == null) {
      throw StateError(
        'Connectez-vous pour utiliser et enregistrer les conversations IA.',
      );
    }
    return user;
  }

  Future<String> createAiConversation({required String title}) async {
    final user = _requireAiUser();
    final reference = _aiConversations(user.uid).doc();
    await reference.set({
      'ownerId': user.uid,
      'title': title.trim().isEmpty ? 'Dar Plus AI' : title.trim(),
      'lastMessage': '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return reference.id;
  }

  Stream<List<Map<String, dynamic>>> streamAiConversations() {
    final user = _requireAiUser();
    return _aiConversations(user.uid)
        .orderBy('updatedAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => _mapAiDocument(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<List<Map<String, dynamic>>> streamAiMessages(String conversationId) {
    final user = _requireAiUser();
    return _aiConversations(user.uid)
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => _mapAiDocument(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<void> addAiConversationMessage({
    required String conversationId,
    required String role,
    required String text,
    required List<String> recommendationIds,
    String? priceEstimate,
    String? serviceType,
  }) async {
    final user = _requireAiUser();
    if (role != 'user' && role != 'assistant') {
      throw ArgumentError.value(role, 'role', 'Unsupported chat message role.');
    }
    if (text.trim().isEmpty || text.length > 4000) {
      throw ArgumentError.value(text.length, 'text', 'Invalid message length.');
    }

    final conversation = _aiConversations(user.uid).doc(conversationId);
    final message = conversation.collection('messages').doc();
    final batch = FirebaseFirestore.instance.batch();
    batch.set(message, {
      'role': role,
      'text': text.trim(),
      'recommendationIds': recommendationIds,
      if (priceEstimate != null) 'priceEstimate': priceEstimate,
      if (serviceType != null) 'serviceType': serviceType,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(conversation, {
      'lastMessage': text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Map<String, dynamic> _mapAiDocument(String id, Map<String, dynamic> data) {
    final createdAt = data['createdAt'];
    final updatedAt = data['updatedAt'];
    return {
      ...data,
      'id': id,
      if (createdAt is Timestamp) 'createdAt': createdAt.toDate(),
      if (updatedAt is Timestamp) 'updatedAt': updatedAt.toDate(),
    };
  }
}
