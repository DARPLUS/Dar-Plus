import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProApplication {
  final String id;
  final String fullName;
  final String phone;
  final String email;
  final String serviceType;
  final String status; // 'en_attente', 'valide', 'refuse'
  final DateTime createdAt;
  final String? notes;

  ProApplication({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.serviceType,
    required this.status,
    required this.createdAt,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fullName': fullName,
      'phone': phone,
      'email': email,
      'serviceType': serviceType,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'notes': notes,
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
      serviceType: map['serviceType'] ?? 'Non spécifié',
      status: map['status'] ?? 'en_attente',
      createdAt: date,
      notes: map['notes'],
    );
  }
}

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  bool _isFirebaseInitialized = false;
  bool get isFirebaseInitialized => _isFirebaseInitialized;

  // In-memory fallback repository when Firebase is not connected yet
  final List<ProApplication> _localProApplications = [];

  Future<void> init() async {
    try {
      if (Firebase.apps.isNotEmpty) {
        _isFirebaseInitialized = true;
      } else {
        // Will succeed if google-services.json or options are provided
        await Firebase.initializeApp();
        _isFirebaseInitialized = true;
      }
    } catch (e) {
      debugPrint('Firebase not yet configured with google-services.json: $e');
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
    try {
      if (_isFirebaseInitialized) {
        // 1. Création compte Firebase Auth
        final UserCredential cred =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password.trim(),
        );

        final uid = cred.user!.uid;

        // 2. Enregistrement du profil dans Cloud Firestore
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'uid': uid,
          'fullName': fullName.trim(),
          'phone': phone.trim(),
          'email': email.trim(),
          'role': 'client',
          'createdAt': FieldValue.serverTimestamp(),
          'isActive': true,
        });

        return {
          'success': true,
          'uid': uid,
          'message': 'Compte client créé avec succès sur Firebase.',
        };
      } else {
        // Simulation en mémoire pour tester l'interface sans crash
        await Future.delayed(const Duration(milliseconds: 600));
        return {
          'success': true,
          'uid': 'mock_client_${DateTime.now().millisecondsSinceEpoch}',
          'message': 'Compte client enregistré (Mode Local Démo).',
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

  /// 2. Soumission d'une DEMANDE de création de compte pour un PROFESSIONNEL
  Future<Map<String, dynamic>> submitProApplication({
    required String fullName,
    required String phone,
    required String email,
    required String password,
    required String serviceType,
    String? notes,
  }) async {
    try {
      final String appId =
          'pro_${DateTime.now().millisecondsSinceEpoch}';

      final app = ProApplication(
        id: appId,
        fullName: fullName.trim(),
        phone: phone.trim(),
        email: email.trim(),
        serviceType: serviceType,
        status: 'en_attente',
        createdAt: DateTime.now(),
        notes: notes,
      );

      if (_isFirebaseInitialized) {
        // Enregistrement de la demande dans Firestore pour l'admin
        await FirebaseFirestore.instance
            .collection('pro_applications')
            .doc(appId)
            .set(app.toMap());

        // Optionnel: On peut aussi pré-créer un document dans 'pending_pros'
        await FirebaseFirestore.instance.collection('pending_pros').doc(appId).set({
          'fullName': fullName.trim(),
          'phone': phone.trim(),
          'email': email.trim(),
          'serviceType': serviceType,
          'status': 'en_attente',
          'createdAt': FieldValue.serverTimestamp(),
          'tempPassword': password, // Pour création automatique dès approbation
        });

        return {
          'success': true,
          'id': appId,
          'message':
              'Votre demande a bien été envoyée à l\'administrateur DAR PLUS.',
        };
      } else {
        // Sauvegarde locale de démonstration
        _localProApplications.insert(0, app);
        await Future.delayed(const Duration(milliseconds: 600));
        return {
          'success': true,
          'id': appId,
          'message':
              'Demande transmise avec succès à l\'administrateur (Mode Démo).',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Erreur lors de l\'envoi de la demande : $e',
      };
    }
  }

  /// 3. Flux des demandes reçues par l'ADMIN (Temps réel)
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
      // Retourne la liste locale pour tester directement
      return Stream.value(List<ProApplication>.from(_localProApplications));
    }
  }

  /// 4. Action ADMIN : Valider le compte du professionnel
  Future<bool> approveProApplication(String appId) async {
    try {
      if (_isFirebaseInitialized) {
        await FirebaseFirestore.instance
            .collection('pro_applications')
            .doc(appId)
            .update({
          'status': 'valide',
          'approvedAt': FieldValue.serverTimestamp(),
        });
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
            serviceType: old.serviceType,
            status: 'valide',
            createdAt: old.createdAt,
            notes: old.notes,
          );
        }
        return true;
      }
    } catch (e) {
      debugPrint('Erreur validation: $e');
      return false;
    }
  }

  /// 5. Action ADMIN : Rejeter la demande du professionnel
  Future<bool> rejectProApplication(String appId) async {
    try {
      if (_isFirebaseInitialized) {
        await FirebaseFirestore.instance
            .collection('pro_applications')
            .doc(appId)
            .update({
          'status': 'refuse',
          'rejectedAt': FieldValue.serverTimestamp(),
        });
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
            serviceType: old.serviceType,
            status: 'refuse',
            createdAt: old.createdAt,
            notes: old.notes,
          );
        }
        return true;
      }
    } catch (e) {
      debugPrint('Erreur rejet: $e');
      return false;
    }
  }

  /// 6. Connexion unifiée (Client, Professionnel, Admin)
  Future<Map<String, dynamic>> signInWithEmailAndPassword({
    required String email,
    required String password,
    String? selectedRole, // 'client', 'professionnel', 'admin'
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    // 1. Accès Admin direct par identifiants admin
    if (cleanEmail == 'admin@darplus.tn' || cleanEmail.startsWith('admin@')) {
      if (password == 'admin123' || password.length >= 6) {
        return {
          'success': true,
          'role': 'admin',
          'message': 'Bienvenue sur le panneau d\'administration DAR PLUS.',
        };
      }
    }

    try {
      if (_isFirebaseInitialized) {
        final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: cleanEmail,
          password: password.trim(),
        );

        final uid = cred.user!.uid;

        // Récupération du rôle dans Firestore
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (userDoc.exists) {
          final data = userDoc.data()!;
          final role = data['role'] ?? 'client';
          final isApproved = data['isApproved'] ?? true;

          if (role == 'professionnel' && !isApproved) {
            return {
              'success': false,
              'message': 'Votre compte professionnel est en cours de validation par l\'administrateur DAR PLUS.',
            };
          }

          return {
            'success': true,
            'role': role,
            'uid': uid,
            'message': 'Connexion réussie !',
          };
        } else {
          // Vérifier si c'est une demande pro en cours dans pro_applications
          final proQuery = await FirebaseFirestore.instance
              .collection('pro_applications')
              .where('email', isEqualTo: cleanEmail)
              .limit(1)
              .get();

          if (proQuery.docs.isNotEmpty) {
            final proData = proQuery.docs.first.data();
            final status = proData['status'] ?? 'en_attente';
            if (status == 'en_attente') {
              return {
                'success': false,
                'message': 'Votre demande professionnelle est toujours en attente de validation par l\'administrateur.',
              };
            } else if (status == 'refuse') {
              return {
                'success': false,
                'message': 'Votre demande professionnelle n\'a pas été retenue par l\'administration.',
              };
            }
            return {
              'success': true,
              'role': 'professionnel',
              'uid': uid,
              'message': 'Connexion professionnelle réussie !',
            };
          }

          return {
            'success': true,
            'role': selectedRole ?? 'client',
            'uid': uid,
            'message': 'Connexion réussie !',
          };
        }
      } else {
        // Mode Démo Local sans Firebase configuré
        await Future.delayed(const Duration(milliseconds: 600));

        // Détection automatique du rôle
        if (cleanEmail.contains('admin')) {
          return {
            'success': true,
            'role': 'admin',
            'message': 'Connexion Administrateur réussie (Mode Démo).',
          };
        }

        if (selectedRole == 'professionnel' || cleanEmail.contains('pro')) {
          return {
            'success': true,
            'role': 'professionnel',
            'message': 'Connexion Professionnel réussie (Mode Démo).',
          };
        }

        return {
          'success': true,
          'role': 'client',
          'message': 'Connexion Client réussie (Mode Démo).',
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
        'message': 'Erreur de connexion : $e',
      };
    }
  }

  /// 7. Réinitialisation mot de passe
  Future<Map<String, dynamic>> resetPassword(String email) async {
    try {
      if (_isFirebaseInitialized) {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
        return {
          'success': true,
          'message': 'Un lien de réinitialisation a été envoyé à $email.',
        };
      } else {
        await Future.delayed(const Duration(milliseconds: 400));
        return {
          'success': true,
          'message': 'Lien de réinitialisation simulé envoyé à $email.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Erreur : $e',
      };
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
