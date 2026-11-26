import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/commission_model.dart';
import '../models/payment_model.dart';

class CommissionService {
  static final CommissionService _instance = CommissionService._internal();
  factory CommissionService() => _instance;
  CommissionService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<void> ensureDefaultSettings() async {
    await _functions.httpsCallable('getCommissionSettings').call();
  }

  Future<void> updateSettings({
    required double percentage,
    required bool isActive,
  }) async {
    await _functions.httpsCallable('updateCommissionSettings').call({
      'commissionPercentage': percentage,
      'isActive': isActive,
    });
  }

  Stream<CommissionSettings> streamSettings() {
    return _firestore
        .collection('platform_settings')
        .doc('commission')
        .snapshots()
        .map(
          (snapshot) => CommissionSettings.fromMap(
            snapshot.data() ?? const <String, dynamic>{},
          ),
        );
  }

  Stream<List<CommissionRecord>> streamCommissions({
    required bool professionalOnly,
  }) {
    Query<Map<String, dynamic>> query = _firestore.collection(
      'platform_commissions',
    );
    if (professionalOnly) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return Stream.value(const []);
      query = query.where('professionalId', isEqualTo: uid);
    }

    return query.snapshots().map((snapshot) {
      final records = snapshot.docs
          .map((doc) => CommissionRecord.fromMap(doc.data(), doc.id))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return records;
    });
  }

  Stream<List<PaymentModel>> streamPayments({
    required bool professionalOnly,
  }) {
    Query<Map<String, dynamic>> query = _firestore.collection('payments');
    if (professionalOnly) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return Stream.value(const []);
      query = query.where('proId', isEqualTo: uid);
    }

    return query.snapshots().map((snapshot) {
      final payments = snapshot.docs
          .map((doc) => PaymentModel.fromMap(doc.data(), doc.id))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return payments;
    });
  }

  Stream<List<Map<String, dynamic>>> streamAdminPaymentNotifications() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(const []);

    return _firestore
        .collection('notifications')
        .where('recipientId', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
          final notifications = snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .where((data) => data['type'] == 'payment_confirmed')
              .toList();
          notifications.sort((a, b) {
            final aTime = a['createdAt'];
            final bTime = b['createdAt'];
            if (aTime is Timestamp && bTime is Timestamp) {
              return bTime.compareTo(aTime);
            }
            return 0;
          });
          return notifications;
        });
  }

  Future<void> markNotificationRead(String notificationId) async {
    await _firestore
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }
}
