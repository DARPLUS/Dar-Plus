import 'package:cloud_firestore/cloud_firestore.dart';

class CommissionSettings {
  final double commissionPercentage;
  final bool isActive;
  final String updatedBy;
  final DateTime? updatedAt;

  const CommissionSettings({
    this.commissionPercentage = 10,
    this.isActive = true,
    this.updatedBy = '',
    this.updatedAt,
  });

  factory CommissionSettings.fromMap(Map<String, dynamic> map) {
    final timestamp = map['updatedAt'];
    return CommissionSettings(
      commissionPercentage:
          (map['commissionPercentage'] as num?)?.toDouble() ?? 10,
      isActive: map['isActive'] as bool? ?? true,
      updatedBy: map['updatedBy'] as String? ?? '',
      updatedAt: timestamp is Timestamp ? timestamp.toDate() : null,
    );
  }
}

class CommissionRecord {
  final String id;
  final String paymentId;
  final String bookingId;
  final String professionalId;
  final double grossAmount;
  final double commissionPercentage;
  final double commissionAmount;
  final double professionalNetAmount;
  final String currency;
  final bool isSandbox;
  final DateTime createdAt;

  const CommissionRecord({
    required this.id,
    required this.paymentId,
    required this.bookingId,
    required this.professionalId,
    required this.grossAmount,
    required this.commissionPercentage,
    required this.commissionAmount,
    required this.professionalNetAmount,
    required this.currency,
    required this.isSandbox,
    required this.createdAt,
  });

  factory CommissionRecord.fromMap(
    Map<String, dynamic> map,
    String id,
  ) {
    final timestamp = map['createdAt'];
    return CommissionRecord(
      id: id,
      paymentId: map['paymentId']?.toString() ?? '',
      bookingId: map['bookingId']?.toString() ?? '',
      professionalId: map['professionalId']?.toString() ?? '',
      grossAmount: (map['grossAmount'] as num?)?.toDouble() ?? 0,
      commissionPercentage:
          (map['commissionPercentage'] as num?)?.toDouble() ?? 0,
      commissionAmount: (map['commissionAmount'] as num?)?.toDouble() ?? 0,
      professionalNetAmount:
          (map['professionalNetAmount'] as num?)?.toDouble() ?? 0,
      currency: map['currency']?.toString() ?? 'TND',
      isSandbox: map['isSandbox'] == true,
      createdAt: timestamp is Timestamp ? timestamp.toDate() : DateTime.now(),
    );
  }
}
