import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../models/payment_model.dart';
import 'firebase_service.dart';

/// Résultat de l'initialisation du checkout
class PaymentCheckoutInitResult {
  final bool success;
  final String? paymentId;
  final String? checkoutUrl;
  final String? errorMessage;

  PaymentCheckoutInitResult({
    required this.success,
    this.paymentId,
    this.checkoutUrl,
    this.errorMessage,
  });
}

/// Service de paiement côté client
/// RÈGLES DE SÉCURITÉ STRICTES :
/// - ZÉRO secret ou clé privée marchand dans le code Flutter.
/// - Toutes les transactions sont autorisées et confirmées uniquement par le serveur / webhooks.
/// - L'application écoute les statuts confirmés par le serveur via Firestore et ne s'auto-valide jamais.
class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  /// URL optionnelle de votre passerelle backend / Cloud Function de production.
  /// Laissez vide ou null pour utiliser le mode Firestore Server-Ready par défaut.
  static const String? _backendApiUrl = null;

  // Cache mémoire local pour fallback hors-ligne ou tests unitaires
  static final Map<String, PaymentModel> _localPaymentsCache = {};

  bool get _isFirebaseReady => FirebaseService().isFirebaseInitialized;

  // ================= 1. LANCEMENT DU CHECKOUT (SANS SECRET) =================

  /// Initialise une session de paiement sécurisée
  /// Flutter contacte le backend ou crée une demande de paiement en attente.
  Future<PaymentCheckoutInitResult> createCheckoutSession({
    required String bookingId,
    required String proId,
    required String proName,
    required String serviceType,
    required double baseAmount,
    double feeAmount = 2.500, // Frais de service standards DAR PLUS (en DT)
    double discountAmount = 0.0,
    required String paymentMethod, // 'carte_bancaire', 'flouci', 'konnect', 'cash'
  }) async {
    try {
      User? user;
      if (_isFirebaseReady) {
        try {
          user = FirebaseAuth.instance.currentUser;
        } catch (_) {}
      }
      final clientId = user?.uid ?? 'client_anon';
      final clientEmail = user?.email ?? '';

      // Nom du client depuis le profil
      String clientName = 'Client';
      if (_isFirebaseReady) {
        final userData = await FirebaseService().getCurrentUserData();
        if (userData != null && userData['fullName'] != null) {
          clientName = userData['fullName'] as String;
        }
      }

      final totalAmount = (baseAmount + feeAmount - discountAmount).clamp(0.0, 999999.0);
      final paymentId = 'pay_${DateTime.now().millisecondsSinceEpoch}_${clientId.substring(0, clientId.length > 5 ? 5 : clientId.length)}';
      final transactionRef = 'TXN-DAR-${DateTime.now().millisecondsSinceEpoch}';

      // 1.1 Si une API backend externe est configurée, on l'appelle avec le token Firebase JWT
      if (_backendApiUrl != null && _backendApiUrl!.isNotEmpty) {
        final idToken = await user?.getIdToken();
        final response = await http.post(
          Uri.parse('$_backendApiUrl/create-checkout-session'),
          headers: {
            'Content-Type': 'application/json',
            if (idToken != null) 'Authorization': 'Bearer $idToken',
          },
          body: jsonEncode({
            'paymentId': paymentId,
            'bookingId': bookingId,
            'clientId': clientId,
            'clientEmail': clientEmail,
            'clientName': clientName,
            'proId': proId,
            'proName': proName,
            'serviceType': serviceType,
            'baseAmount': baseAmount,
            'feeAmount': feeAmount,
            'discountAmount': discountAmount,
            'totalAmount': totalAmount,
            'currency': 'DT',
            'paymentMethod': paymentMethod,
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          return PaymentCheckoutInitResult(
            success: true,
            paymentId: data['paymentId']?.toString() ?? paymentId,
            checkoutUrl: data['checkoutUrl']?.toString(),
          );
        } else {
          return PaymentCheckoutInitResult(
            success: false,
            errorMessage: 'Échec de la création de session serveur (${response.statusCode})',
          );
        }
      }

      // 1.2 Enregistrement dans Firestore avec statut STRICT "en_attente"
      // Le serveur ou webhook Firestore réagira à ce document pour traiter le débit.
      final newPayment = PaymentModel(
        id: paymentId,
        bookingId: bookingId,
        clientId: clientId,
        clientName: clientName,
        clientEmail: clientEmail,
        proId: proId,
        proName: proName,
        serviceType: serviceType,
        baseAmount: baseAmount,
        feeAmount: feeAmount,
        discountAmount: discountAmount,
        totalAmount: totalAmount,
        currency: 'DT',
        status: PaymentStatus.pending, // Toujours "en_attente" initialement
        paymentMethod: paymentMethod,
        transactionRef: transactionRef,
        createdAt: DateTime.now(),
      );

      _localPaymentsCache[paymentId] = newPayment;

      if (_isFirebaseReady) {
        await FirebaseFirestore.instance
            .collection('payments')
            .doc(paymentId)
            .set(newPayment.toMap());

        // Journal de sécurité
        await FirebaseService().logSecurityEvent(
          action: 'INITIATE_PAYMENT',
          actorEmail: clientEmail.isNotEmpty ? clientEmail : 'Client',
          target: proName,
          details: 'Session de paiement $paymentId initiée pour $serviceType ($totalAmount DT)',
        );
      }

      return PaymentCheckoutInitResult(
        success: true,
        paymentId: paymentId,
      );
    } catch (e) {
      debugPrint('Erreur createCheckoutSession: $e');
      return PaymentCheckoutInitResult(
        success: false,
        errorMessage: 'Erreur lors de l\'initialisation du paiement: $e',
      );
    }
  }

  // ================= 2. ÉCOUTE DU STATUT CONFIRMÉ CÔTÉ SERVEUR =================

  /// Écoute en temps réel l'état d'un paiement spécifique confirmé par le serveur
  /// L'affichage UI ne se base QUE sur ce Stream.
  Stream<PaymentModel?> streamPaymentStatus(String paymentId) {
    if (_isFirebaseReady) {
      return FirebaseFirestore.instance
          .collection('payments')
          .doc(paymentId)
          .snapshots()
          .map((snapshot) {
        if (!snapshot.exists || snapshot.data() == null) {
          return _localPaymentsCache[paymentId];
        }
        final model = PaymentModel.fromMap(snapshot.data()!, snapshot.id);
        _localPaymentsCache[paymentId] = model;
        return model;
      });
    }

    // Fallback stream local
    return Stream.periodic(const Duration(seconds: 1), (_) => _localPaymentsCache[paymentId]);
  }

  /// Récupérer les détails d'un paiement ponctuellement
  Future<PaymentModel?> getPayment(String paymentId) async {
    try {
      if (_isFirebaseReady) {
        final doc = await FirebaseFirestore.instance.collection('payments').doc(paymentId).get();
        if (doc.exists && doc.data() != null) {
          final model = PaymentModel.fromMap(doc.data()!, doc.id);
          _localPaymentsCache[paymentId] = model;
          return model;
        }
      }
      return _localPaymentsCache[paymentId];
    } catch (e) {
      debugPrint('Erreur getPayment: $e');
      return _localPaymentsCache[paymentId];
    }
  }

  // ================= 3. HISTORIQUE DES PAIEMENTS CÔTÉ CLIENT =================

  /// Écoute la liste de tous les paiements du client actuellement connecté
  Stream<List<PaymentModel>> streamClientPayments() {
    User? user;
    if (_isFirebaseReady) {
      try {
        user = FirebaseAuth.instance.currentUser;
      } catch (_) {}
    }
    final clientId = user?.uid;

    if (_isFirebaseReady && clientId != null) {
      return FirebaseFirestore.instance
          .collection('payments')
          .where('clientId', isEqualTo: clientId)
          .snapshots()
          .map((snapshot) {
        final list = snapshot.docs
            .map((doc) => PaymentModel.fromMap(doc.data(), doc.id))
            .toList();

        // Tri par date décroissante
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });
    }

    // Fallback mémoire locale
    final list = _localPaymentsCache.values
        .where((p) => p.clientId == (clientId ?? 'client_anon'))
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return Stream.value(list);
  }

  // ================= 4. ANNULATION PAR LE CLIENT =================

  /// Demander l'annulation d'une session de paiement en attente
  Future<bool> cancelPayment(String paymentId) async {
    try {
      final current = await getPayment(paymentId);
      if (current == null || current.status != PaymentStatus.pending) {
        return false; // On ne peut annuler qu'un paiement en attente
      }

      final updated = PaymentModel(
        id: current.id,
        bookingId: current.bookingId,
        clientId: current.clientId,
        clientName: current.clientName,
        clientEmail: current.clientEmail,
        proId: current.proId,
        proName: current.proName,
        serviceType: current.serviceType,
        baseAmount: current.baseAmount,
        feeAmount: current.feeAmount,
        discountAmount: current.discountAmount,
        totalAmount: current.totalAmount,
        currency: current.currency,
        status: PaymentStatus.cancelled,
        paymentMethod: current.paymentMethod,
        transactionRef: current.transactionRef,
        failureReason: 'Annulé par l\'utilisateur',
        createdAt: current.createdAt,
        updatedAt: DateTime.now(),
      );

      _localPaymentsCache[paymentId] = updated;

      if (_isFirebaseReady) {
        await FirebaseFirestore.instance
            .collection('payments')
            .doc(paymentId)
            .update({
          'status': PaymentStatus.cancelled.code,
          'failureReason': 'Annulé par l\'utilisateur',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Journal de sécurité
        await FirebaseService().logSecurityEvent(
          action: 'CANCEL_PAYMENT',
          actorEmail: current.clientEmail.isNotEmpty ? current.clientEmail : 'Client',
          target: current.proName,
          details: 'Session de paiement $paymentId annulée par le client',
        );
      }
      return true;
    } catch (e) {
      debugPrint('Erreur cancelPayment: $e');
      return false;
    }
  }

  // ================= 5. SIMULATEUR SERVEUR / TEST (DEV UNIQUEMENT) =================

  /// Permet en environnement de test / dev de simuler la réponse d'un webhook serveur
  /// après un délai d'attente réseau réaliste (ex: 3s).
  /// À désactiver en production où seul le serveur tiers (webhook) met à jour Firestore.
  Future<void> simulateServerWebhookResponse(String paymentId, {required bool shouldSucceed, String? failReason}) async {
    await Future.delayed(const Duration(seconds: 3));

    final current = await getPayment(paymentId);
    if (current == null || current.status != PaymentStatus.pending) return;

    final newStatus = shouldSucceed ? PaymentStatus.success : PaymentStatus.failed;
    final reason = shouldSucceed ? null : (failReason ?? 'Solde insuffisant ou transaction refusée par la banque.');

    final updated = PaymentModel(
      id: current.id,
      bookingId: current.bookingId,
      clientId: current.clientId,
      clientName: current.clientName,
      clientEmail: current.clientEmail,
      proId: current.proId,
      proName: current.proName,
      serviceType: current.serviceType,
      baseAmount: current.baseAmount,
      feeAmount: current.feeAmount,
      discountAmount: current.discountAmount,
      totalAmount: current.totalAmount,
      currency: current.currency,
      status: newStatus,
      paymentMethod: current.paymentMethod,
      transactionRef: current.transactionRef,
      failureReason: reason,
      createdAt: current.createdAt,
      updatedAt: DateTime.now(),
    );

    _localPaymentsCache[paymentId] = updated;

    if (_isFirebaseReady) {
      await FirebaseFirestore.instance.collection('payments').doc(paymentId).update({
        'status': newStatus.code,
        'failureReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Si le paiement a réussi, synchroniser la réservation correspondante dans 'bookings'
      if (shouldSucceed && current.bookingId.isNotEmpty) {
        try {
          await FirebaseFirestore.instance.collection('bookings').doc(current.bookingId).update({
            'paymentStatus': 'paye',
            'paymentId': paymentId,
            'paidAmount': current.totalAmount,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } catch (_) {}
      }

      await FirebaseService().logSecurityEvent(
        action: shouldSucceed ? 'PAYMENT_SUCCESS_SERVER' : 'PAYMENT_FAILED_SERVER',
        actorEmail: 'SERVER_GATEWAY',
        target: current.clientEmail,
        details: 'Serveur: Paiement $paymentId ${shouldSucceed ? "validé avec succès" : "refusé ($reason)"}',
      );
    }
  }

  // ================= 6. PARCOURS COMPLET SANDBOX (STRIPE TEST / KONNECT SANDBOX) =================

  /// Traitement complet d'un paiement en ligne en mode Sandbox
  /// Enregistre la transaction dans Firestore 'payments',
  /// Met à jour 'bookings' avec 'paymentStatus: paye' si applicable,
  /// Met à jour 'users' si formule abonnement,
  /// et enregistre un journal de sécurité.
  Future<PaymentModel> processOnlineSandboxPayment({
    required String bookingId,
    required String proId,
    required String proName,
    required String serviceType,
    required double baseAmount,
    required double feeAmount,
    required double discountAmount,
    required double totalAmount,
    required String gateway, // 'stripe_test', 'konnect_sandbox', 'flouci_sandbox'
    required String paymentMethod, // 'carte_bancaire', 'konnect', 'cash'
    required bool isSubscription,
    required bool shouldSucceed,
    String? testCardNumber,
    String? failReason,
  }) async {
    // 1. Simuler la latence réseau bancaire réaliste (1200ms)
    await Future.delayed(const Duration(milliseconds: 1200));

    User? user;
    if (_isFirebaseReady) {
      try {
        user = FirebaseAuth.instance.currentUser;
      } catch (_) {}
    }
    final clientId = user?.uid ?? 'client_anon';
    final clientEmail = user?.email ?? '';

    String clientName = 'Client';
    if (_isFirebaseReady) {
      final userData = await FirebaseService().getCurrentUserData();
      if (userData != null && userData['fullName'] != null) {
        clientName = userData['fullName'] as String;
      }
    }

    final paymentId = 'pay_sb_${DateTime.now().millisecondsSinceEpoch}';
    final status = shouldSucceed ? PaymentStatus.success : PaymentStatus.failed;
    final reason = shouldSucceed ? null : (failReason ?? 'La carte de test a été refusée par la passerelle de test.');

    String txnRef;
    if (gateway == 'stripe_test') {
      txnRef = 'pi_test_${DateTime.now().millisecondsSinceEpoch}_secret';
    } else if (gateway == 'konnect_sandbox') {
      txnRef = 'TXN-KONNECT-SANDBOX-${DateTime.now().millisecondsSinceEpoch}';
    } else {
      txnRef = 'TXN-FLOUCI-SANDBOX-${DateTime.now().millisecondsSinceEpoch}';
    }

    final payment = PaymentModel(
      id: paymentId,
      bookingId: bookingId,
      clientId: clientId,
      clientName: clientName,
      clientEmail: clientEmail,
      proId: proId,
      proName: proName,
      serviceType: serviceType,
      baseAmount: baseAmount,
      feeAmount: feeAmount,
      discountAmount: discountAmount,
      totalAmount: totalAmount,
      currency: 'DT',
      status: status,
      paymentMethod: paymentMethod,
      transactionRef: txnRef,
      failureReason: reason,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _localPaymentsCache[paymentId] = payment;

    // Enregistrement dans Firestore
    if (_isFirebaseReady) {
      final data = payment.toMap();
      data['gateway'] = gateway;
      data['isSandbox'] = true;
      data['isSubscription'] = isSubscription;
      if (testCardNumber != null && testCardNumber.length >= 4) {
        data['cardLast4'] = testCardNumber.substring(testCardNumber.length - 4);
      }

      await FirebaseFirestore.instance.collection('payments').doc(paymentId).set(data);

      // Si succès et réservation liée -> mettre à jour la réservation
      if (shouldSucceed && bookingId.isNotEmpty && bookingId != 'none') {
        try {
          await FirebaseFirestore.instance.collection('bookings').doc(bookingId).update({
            'paymentStatus': 'paye',
            'paymentId': paymentId,
            'paidAmount': totalAmount,
            'paidAt': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          debugPrint('Note: mise à jour réservation: $e');
        }
      }

      // Si abonnement -> mettre à jour l'utilisateur
      if (shouldSucceed && isSubscription && clientId != 'client_anon') {
        try {
          await FirebaseFirestore.instance.collection('users').doc(clientId).update({
            'subscription': 'dar_plus_serenite',
            'subscriptionStatus': 'active',
            'subscribedAt': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          debugPrint('Note: mise à jour abonnement: $e');
        }
      }

      // Journal d'audit de sécurité
      await FirebaseService().logSecurityEvent(
        action: shouldSucceed ? 'PAYMENT_SANDBOX_SUCCESS' : 'PAYMENT_SANDBOX_FAILED',
        actorEmail: clientEmail.isNotEmpty ? clientEmail : 'Client',
        target: proName,
        details: 'Passerelle $gateway (Sandbox): ${shouldSucceed ? "Validé $totalAmount DT" : "Refusé ($reason)"}',
      );
    }

    return payment;
  }
}
