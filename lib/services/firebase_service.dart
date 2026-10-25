import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  final Map<String, Map<String, dynamic>> _localUsers = {
    'admin@darplus.tn': {
      'uid': 'mock_admin_root',
      'fullName': 'Super Admin DAR PLUS',
      'email': 'admin@darplus.tn',
      'phone': '+216 71 000 000',
      'password': 'admin123',
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
      'password': 'admin123',
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

    // Accès d'urgence admin@darplus.tn
    if (cleanEmail == 'admin@darplus.tn' &&
        (cleanPassword == 'admin123' || cleanPassword == 'password123')) {
      return {
        'success': true,
        'role': 'super_admin',
        'uid': 'root_admin_uid',
        'fullName': 'Super Admin DAR PLUS',
        'email': 'admin@darplus.tn',
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

        final UserCredential cred =
            await FirebaseAuth.instance.signInWithPopup(googleProvider);
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

  /// 11. Réinitialisation mot de passe (EmailJS + Firebase)
  Future<Map<String, dynamic>> resetPassword(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    try {
      String userName = cleanEmail.split('@').first;
      String? userDocId;

      if (_isFirebaseInitialized) {
        final q = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: cleanEmail)
            .limit(1)
            .get();

        if (q.docs.isNotEmpty) {
          final data = q.docs.first.data();
          userName = (data['fullName'] as String?) ?? userName;
          userDocId = q.docs.first.id;
        }
      }

      // Génération d'un mot de passe temporaire lisible et sécurisé (ex: DP-849201)
      final tempPassword = 'DP-${100000 + Random().nextInt(900000)}';

      if (_isFirebaseInitialized && userDocId != null) {
        await FirebaseFirestore.instance.collection('users').doc(userDocId).set({
          'tempPassword': tempPassword,
          'mustChangePassword': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (_localUsers.containsKey(cleanEmail)) {
        _localUsers[cleanEmail]!['tempPassword'] = tempPassword;
        _localUsers[cleanEmail]!['mustChangePassword'] = true;
      }

      // Envoi du bel email stylisé DAR PLUS avec le mot de passe temporaire via EmailJS
      final bool emailSent = await EmailService.sendPasswordResetEmail(
        toEmail: cleanEmail,
        userName: userName,
        temporaryPassword: tempPassword,
      );

      // Envoi en parallèle via Firebase Auth si supporté
      try {
        if (_isFirebaseInitialized) {
          await FirebaseAuth.instance.sendPasswordResetEmail(email: cleanEmail);
        }
      } catch (_) {}

      if (emailSent) {
        return {
          'success': true,
          'message': 'Un mot de passe temporaire a été envoyé à $cleanEmail.',
        };
      } else {
        return {
          'success': true,
          'message': 'Lien de réinitialisation envoyé à $cleanEmail.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Erreur lors de la réinitialisation : $e',
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

        return snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
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
}
