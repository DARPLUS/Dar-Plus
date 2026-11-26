import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../models/payment_model.dart';
import '../services/commission_service.dart';

class PaymentTransactionScreen extends StatelessWidget {
  const PaymentTransactionScreen({super.key});

  static const _forest = Color(0xFF14532D);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      appBar: AppBar(title: Text('payment_transactions_title'.tr())),
      body: StreamBuilder<List<PaymentModel>>(
        stream: CommissionService().streamPayments(professionalOnly: false),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _Message(
              message: 'Accès aux transactions impossible : ${snapshot.error}',
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final payments = snapshot.data ?? const <PaymentModel>[];
          final successful = payments.where((payment) => payment.isSuccess);
          final commissionTotal = successful.fold<double>(
            0,
            (total, payment) => total + payment.commissionAmount,
          );
          final paidTotal = successful.fold<double>(
            0,
            (total, payment) => total + payment.totalAmount,
          );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _PaymentAdminNotifications(
                isDark: isDark,
                cardColor: cardColor,
                textColor: textColor,
                secondaryColor: secondaryColor,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _StatCard(
                    label: 'Paiements confirmés',
                    value: '${successful.length}',
                    icon: Icons.check_circle_outline_rounded,
                    color: _forest,
                  ),
                  _StatCard(
                    label: 'Total payé',
                    value: '${paidTotal.toStringAsFixed(3)} TND',
                    icon: Icons.payments_outlined,
                    color: const Color(0xFF2563EB),
                  ),
                  _StatCard(
                    label: 'Commissions comptabilisées',
                    value: '${commissionTotal.toStringAsFixed(3)} TND',
                    icon: Icons.account_balance_wallet_outlined,
                    color: const Color(0xFFB45309),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'payment_history_title'.tr(),
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(color: textColor, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              if (payments.isEmpty)
                const _Message(message: 'Aucune transaction enregistrée.')
              else
                ...payments.map(
                  (payment) => _PaymentCard(
                    payment: payment,
                    isDark: isDark,
                    cardColor: cardColor,
                    textColor: textColor,
                    secondaryColor: secondaryColor,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PaymentAdminNotifications extends StatelessWidget {
  const _PaymentAdminNotifications({
    required this.isDark,
    required this.cardColor,
    required this.textColor,
    required this.secondaryColor,
  });

  final bool isDark;
  final Color cardColor;
  final Color textColor;
  final Color secondaryColor;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: CommissionService().streamAdminPaymentNotifications(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }
        final notifications = snapshot.data ?? const [];
        if (notifications.isEmpty) return const SizedBox.shrink();

        return Card(
          color: cardColor,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.notifications_active_rounded,
                      color: Color(0xFF14532D),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'payment_notifications_title'.tr(),
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...notifications.take(5).map((notification) {
                  final read = notification['isRead'] == true;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      read
                          ? Icons.receipt_long_outlined
                          : Icons.fiber_new_rounded,
                      color: read ? secondaryColor : const Color(0xFF14532D),
                    ),
                    title: Text(
                      notification['title'] as String? ??
                          'payment_online_confirmed'.tr(),
                      style: TextStyle(
                        color: textColor,
                        fontWeight: read ? FontWeight.w500 : FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      notification['body'] as String? ?? '',
                      style: TextStyle(color: secondaryColor),
                    ),
                    onTap: read
                        ? null
                        : () => CommissionService().markNotificationRead(
                            notification['id'].toString(),
                          ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    required this.payment,
    required this.isDark,
    required this.cardColor,
    required this.textColor,
    required this.secondaryColor,
  });

  final PaymentModel payment;
  final bool isDark;
  final Color cardColor;
  final Color textColor;
  final Color secondaryColor;

  @override
  Widget build(BuildContext context) {
    final statusColor = payment.isSuccess
        ? const Color(0xFF16A34A)
        : payment.isPending
        ? const Color(0xFFD97706)
        : const Color(0xFFDC2626);

    return Card(
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        leading: Icon(Icons.receipt_long_rounded, color: statusColor),
        title: Text(
          payment.serviceType,
          style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${payment.clientName} · ${payment.status.labelFr}',
          style: TextStyle(color: secondaryColor),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        children: [
          _DetailLine('Client', payment.clientName, textColor, secondaryColor),
          _DetailLine(
            'Professionnel',
            payment.proName,
            textColor,
            secondaryColor,
          ),
          _DetailLine(
            'Prix de la prestation',
            '${payment.baseAmount.toStringAsFixed(3)} ${payment.currency}',
            textColor,
            secondaryColor,
          ),
          _DetailLine(
            'Prestation après réduction',
            '${payment.grossAmount.toStringAsFixed(3)} ${payment.currency}',
            textColor,
            secondaryColor,
          ),
          _DetailLine(
            'Taux de commission',
            '${payment.commissionPercentage.toStringAsFixed(2)} %',
            textColor,
            secondaryColor,
          ),
          _DetailLine(
            'Commission Dar Plus',
            '${payment.commissionAmount.toStringAsFixed(3)} ${payment.currency}',
            textColor,
            secondaryColor,
          ),
          _DetailLine(
            'Net professionnel',
            '${payment.professionalNetAmount.toStringAsFixed(3)} ${payment.currency}',
            textColor,
            secondaryColor,
          ),
          _DetailLine(
            'Frais client affichés',
            '${payment.feeAmount.toStringAsFixed(3)} ${payment.currency}',
            textColor,
            secondaryColor,
          ),
          _DetailLine(
            'Total payé',
            '${payment.totalAmount.toStringAsFixed(3)} ${payment.currency}',
            textColor,
            secondaryColor,
          ),
          _DetailLine(
            'Paiement',
            '${payment.paymentMethod}${payment.paymentProvider == null ? '' : ' · ${payment.paymentProvider}'}',
            textColor,
            secondaryColor,
          ),
          _DetailLine(
            'Référence',
            payment.transactionRef ?? payment.id,
            textColor,
            secondaryColor,
          ),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine(
    this.label,
    this.value,
    this.textColor,
    this.secondaryColor,
  );

  final String label;
  final String value;
  final Color textColor;
  final Color secondaryColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: secondaryColor)),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 10),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
