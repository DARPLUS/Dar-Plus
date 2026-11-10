import 'package:cloud_firestore/cloud_firestore.dart';

enum PaymentStatus {
  pending,
  success,
  failed,
  cancelled;

  static PaymentStatus fromString(String? val) {
    switch (val?.toLowerCase().trim()) {
      case 'succes':
      case 'success':
      case 'paye':
      case 'paid':
        return PaymentStatus.success;
      case 'echec':
      case 'failed':
      case 'refuse':
      case 'error':
        return PaymentStatus.failed;
      case 'annule':
      case 'annulee':
      case 'cancelled':
      case 'canceled':
        return PaymentStatus.cancelled;
      case 'en_attente':
      case 'pending':
      default:
        return PaymentStatus.pending;
    }
  }

  String get code {
    switch (this) {
      case PaymentStatus.success:
        return 'succes';
      case PaymentStatus.failed:
        return 'echec';
      case PaymentStatus.cancelled:
        return 'annule';
      case PaymentStatus.pending:
        return 'en_attente';
    }
  }

  String get labelFr {
    switch (this) {
      case PaymentStatus.success:
        return 'Payé';
      case PaymentStatus.failed:
        return 'Échoué';
      case PaymentStatus.cancelled:
        return 'Annulé';
      case PaymentStatus.pending:
        return 'En attente';
    }
  }
}

class PaymentModel {
  final String id;
  final String bookingId;
  final String clientId;
  final String clientName;
  final String clientEmail;
  final String proId;
  final String proName;
  final String serviceType;
  final double baseAmount;
  final double feeAmount;
  final double discountAmount;
  final double totalAmount;
  final String currency; // 'DT' ou 'TND'
  final PaymentStatus status;
  final String paymentMethod; // 'carte_bancaire', 'flouci', 'konnect', 'cash'
  final String? transactionRef;
  final String? failureReason;
  final String? checkoutUrl;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const PaymentModel({
    required this.id,
    required this.bookingId,
    required this.clientId,
    required this.clientName,
    required this.clientEmail,
    required this.proId,
    required this.proName,
    required this.serviceType,
    required this.baseAmount,
    required this.feeAmount,
    this.discountAmount = 0.0,
    required this.totalAmount,
    this.currency = 'DT',
    required this.status,
    required this.paymentMethod,
    this.transactionRef,
    this.failureReason,
    this.checkoutUrl,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isPending => status == PaymentStatus.pending;
  bool get isSuccess => status == PaymentStatus.success;
  bool get isFailed => status == PaymentStatus.failed;
  bool get isCancelled => status == PaymentStatus.cancelled;

  factory PaymentModel.fromMap(Map<String, dynamic> map, [String? id]) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) {
        return DateTime.tryParse(val) ?? DateTime.now();
      }
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return DateTime.now();
    }

    final double base = (map['baseAmount'] as num?)?.toDouble() ??
        (map['amount'] as num?)?.toDouble() ??
        0.0;
    final double fee = (map['feeAmount'] as num?)?.toDouble() ?? 2.5;
    final double discount = (map['discountAmount'] as num?)?.toDouble() ?? 0.0;
    final double total = (map['totalAmount'] as num?)?.toDouble() ?? (base + fee - discount);

    return PaymentModel(
      id: id ?? map['id']?.toString() ?? '',
      bookingId: map['bookingId']?.toString() ?? '',
      clientId: map['clientId']?.toString() ?? '',
      clientName: map['clientName']?.toString() ?? 'Client',
      clientEmail: map['clientEmail']?.toString() ?? '',
      proId: map['proId']?.toString() ?? '',
      proName: map['proName']?.toString() ?? 'Professionnel',
      serviceType: map['serviceType']?.toString() ?? 'Service',
      baseAmount: base,
      feeAmount: fee,
      discountAmount: discount,
      totalAmount: total,
      currency: map['currency']?.toString() ?? 'DT',
      status: PaymentStatus.fromString(map['status']?.toString()),
      paymentMethod: map['paymentMethod']?.toString() ?? 'carte_bancaire',
      transactionRef: map['transactionRef']?.toString(),
      failureReason: map['failureReason']?.toString(),
      checkoutUrl: map['checkoutUrl']?.toString(),
      createdAt: parseDate(map['createdAt']),
      updatedAt: map['updatedAt'] != null ? parseDate(map['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bookingId': bookingId,
      'clientId': clientId,
      'clientName': clientName,
      'clientEmail': clientEmail,
      'proId': proId,
      'proName': proName,
      'serviceType': serviceType,
      'baseAmount': baseAmount,
      'feeAmount': feeAmount,
      'discountAmount': discountAmount,
      'totalAmount': totalAmount,
      'currency': currency,
      'status': status.code,
      'paymentMethod': paymentMethod,
      'transactionRef': transactionRef,
      'failureReason': failureReason,
      'checkoutUrl': checkoutUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }
}
