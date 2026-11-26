import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../core/localization/service_type_localizer.dart';
import '../models/payment_model.dart';
import '../services/commission_service.dart';

enum _EarningsPeriod { week, month, year }

class ProfessionalEarningsScreen extends StatefulWidget {
  const ProfessionalEarningsScreen({super.key});

  @override
  State<ProfessionalEarningsScreen> createState() =>
      _ProfessionalEarningsScreenState();
}

class _ProfessionalEarningsScreenState
    extends State<ProfessionalEarningsScreen> {
  static const _forest = Color(0xFF123C39);
  static const _orange = Color(0xFFF1844C);
  static const _green = Color(0xFF10B981);
  static const _red = Color(0xFFDC2626);
  _EarningsPeriod _period = _EarningsPeriod.month;

  String _amount(double value) => '${value.toStringAsFixed(3)} TND';

  String _compactAmount(double value) {
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    return value.toStringAsFixed(0);
  }

  List<_RevenueBucket> _buildBuckets(List<PaymentModel> payments) {
    final now = DateTime.now();
    switch (_period) {
      case _EarningsPeriod.week:
        final monday = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: now.weekday - 1));
        final labels = [
          'weekday_mon_short',
          'weekday_tue_short',
          'weekday_wed_short',
          'weekday_thu_short',
          'weekday_fri_short',
          'weekday_sat_short',
          'weekday_sun_short',
        ].map((key) => key.tr()).toList();
        return List.generate(7, (index) {
          final day = monday.add(Duration(days: index));
          final value = payments
              .where(
                (p) =>
                    p.createdAt.year == day.year &&
                    p.createdAt.month == day.month &&
                    p.createdAt.day == day.day,
              )
              .fold<double>(0, (sum, p) => sum + p.professionalNetAmount);
          return _RevenueBucket(labels[index], value);
        });
      case _EarningsPeriod.month:
        final labels = _localizedMonthNames();
        return List.generate(6, (index) {
          final month = DateTime(now.year, now.month - (5 - index), 1);
          final value = payments
              .where(
                (p) =>
                    p.createdAt.year == month.year &&
                    p.createdAt.month == month.month,
              )
              .fold<double>(0, (sum, p) => sum + p.professionalNetAmount);
          return _RevenueBucket(labels[month.month - 1], value);
        });
      case _EarningsPeriod.year:
        final labels = _localizedMonthNames();
        return List.generate(12, (index) {
          final value = payments
              .where(
                (p) =>
                    p.createdAt.year == now.year &&
                    p.createdAt.month == index + 1,
              )
              .fold<double>(0, (sum, p) => sum + p.professionalNetAmount);
          return _RevenueBucket(labels[index], value);
        });
    }
  }

  List<String> _localizedMonthNames() => [
    'month_jan_short',
    'month_feb_short',
    'month_mar_short',
    'month_apr_short',
    'month_may_short',
    'month_jun_short',
    'month_jul_short',
    'month_aug_short',
    'month_sep_short',
    'month_oct_short',
    'month_nov_short',
    'month_dec_short',
  ].map((key) => key.tr()).toList();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFFAF7F4);
    final textColor = isDark ? Colors.white : const Color(0xFF172033);
    final secondary = isDark
        ? const Color(0xFF9AA6B8)
        : const Color(0xFF788094);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: pageColor,
      appBar: AppBar(
        backgroundColor: _forest,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'pro_earnings_title'.tr(),
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<List<PaymentModel>>(
        stream: CommissionService().streamPayments(professionalOnly: true),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'pro_earnings_load_error'.tr(
                    namedArgs: {'error': snapshot.error.toString()},
                  ),
                ),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final payments = snapshot.data ?? const <PaymentModel>[];
          final successful =
              payments.where((payment) => payment.isSuccess).toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          final pending = payments
              .where((payment) => payment.isPending)
              .toList();
          final gross = successful.fold<double>(
            0,
            (sum, p) => sum + p.grossAmount,
          );
          final commission = successful.fold<double>(
            0,
            (sum, p) => sum + p.commissionAmount,
          );
          final net = successful.fold<double>(
            0,
            (sum, p) => sum + p.professionalNetAmount,
          );
          final now = DateTime.now();
          final monthNet = successful
              .where(
                (p) =>
                    p.createdAt.year == now.year &&
                    p.createdAt.month == now.month,
              )
              .fold<double>(0, (sum, p) => sum + p.professionalNetAmount);
          final buckets = _buildBuckets(successful);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              _buildBalanceCard(
                net: net,
                gross: gross,
                commission: commission,
                monthNet: monthNet,
                pendingCount: pending.length,
              ),
              const SizedBox(height: 18),
              _buildPeriodSelector(isDark),
              const SizedBox(height: 16),
              _buildRevenueChart(
                context,
                buckets: buckets,
                cardColor: cardColor,
                textColor: textColor,
                secondary: secondary,
              ),
              const SizedBox(height: 22),
              Text(
                'pro_earnings_transactions'.tr(),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 10),
              if (payments.isEmpty)
                Card(
                  color: cardColor,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'pro_earnings_empty'.tr(),
                      style: TextStyle(color: secondary),
                    ),
                  ),
                )
              else
                ...payments.map(
                  (payment) => _buildTransactionCard(
                    payment,
                    cardColor: cardColor,
                    textColor: textColor,
                    secondary: secondary,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBalanceCard({
    required double net,
    required double gross,
    required double commission,
    required double monthNet,
    required int pendingCount,
  }) {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: const Color(0xFF24393D),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'pro_earnings_net_confirmed'.tr(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: .78),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _amount(net),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 29,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _BalanceDetail(
                  label: 'pro_earnings_gross_services'.tr(),
                  value: _amount(gross),
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _BalanceDetail(
                  label: 'pro_earnings_commission'.tr(),
                  value: _amount(commission),
                  color: const Color(0xFFFFC857),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _BalanceDetail(
                  label: 'pro_earnings_this_month'.tr(),
                  value: _amount(monthNet),
                  color: const Color(0xFF34D399),
                ),
              ),
            ],
          ),
          if (pendingCount > 0) ...[
            const SizedBox(height: 12),
            Text(
              'pro_earnings_pending_count'.tr(
                namedArgs: {'count': '$pendingCount'},
              ),
              style: const TextStyle(
                color: Color(0xFFFFC857),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPeriodSelector(bool isDark) {
    final labels = {
      _EarningsPeriod.week: 'pro_period_week'.tr(),
      _EarningsPeriod.month: 'pro_period_month'.tr(),
      _EarningsPeriod.year: 'pro_period_year'.tr(),
    };
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF0EDE9),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: _EarningsPeriod.values.map((period) {
          final selected = _period == period;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _period = period),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: selected
                      ? (isDark ? const Color(0xFF334155) : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  labels[period]!,
                  style: TextStyle(
                    color: selected
                        ? (isDark ? Colors.white : _forest)
                        : (isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF788094)),
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRevenueChart(
    BuildContext context, {
    required List<_RevenueBucket> buckets,
    required Color cardColor,
    required Color textColor,
    required Color secondary,
  }) {
    final maxValue = buckets.fold<double>(
      0,
      (max, bucket) => bucket.amount > max ? bucket.amount : max,
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final periodLabel = switch (_period) {
      _EarningsPeriod.week => 'pro_chart_net_week'.tr(),
      _EarningsPeriod.month => 'pro_chart_net_six_months'.tr(),
      _EarningsPeriod.year => 'pro_chart_net_year'.tr(),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 17, 16, 13),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: .35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            periodLabel,
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 148,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: buckets.map((bucket) {
                final height = maxValue == 0
                    ? 5.0
                    : (bucket.amount / maxValue * 92)
                          .clamp(5.0, 92.0)
                          .toDouble();
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          bucket.amount == 0
                              ? ''
                              : _compactAmount(bucket.amount),
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: TextStyle(
                            color: bucket.amount == maxValue && maxValue > 0
                                ? _orange
                                : secondary,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: height,
                          decoration: BoxDecoration(
                            color: bucket.amount == maxValue && maxValue > 0
                                ? _orange
                                : (isDark
                                      ? const Color(0xFF334155)
                                      : const Color(0xFFEAE7E3)),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          bucket.label,
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: TextStyle(
                            color: secondary,
                            fontSize: _period == _EarningsPeriod.year ? 8 : 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(
    PaymentModel payment, {
    required Color cardColor,
    required Color textColor,
    required Color secondary,
  }) {
    final color = payment.isSuccess
        ? _green
        : payment.isPending
        ? const Color(0xFFF59E0B)
        : _red;
    final day = payment.createdAt.day.toString().padLeft(2, '0');
    final months = _localizedMonthNames();
    return Card(
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 3),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: .12),
          child: Icon(
            payment.isSuccess
                ? Icons.check_rounded
                : payment.isPending
                ? Icons.hourglass_top_rounded
                : Icons.close_rounded,
            color: color,
            size: 20,
          ),
        ),
        title: Text(
          localizeServiceType(payment.serviceType),
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          '$day ${months[payment.createdAt.month - 1]} · ${'payment_status_${payment.status.code}'.tr()}${payment.isSandbox ? ' · ${'payment_test_badge'.tr()}' : ''}',
          style: TextStyle(color: secondary, fontSize: 11),
        ),
        trailing: Text(
          payment.isSuccess
              ? '+${_amount(payment.professionalNetAmount)}'
              : _amount(payment.grossAmount),
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _BalanceDetail extends StatelessWidget {
  const _BalanceDetail({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white.withValues(alpha: .68),
          fontSize: 10,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    ],
  );
}

class _RevenueBucket {
  const _RevenueBucket(this.label, this.amount);
  final String label;
  final double amount;
}
