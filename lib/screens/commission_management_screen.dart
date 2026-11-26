import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import '../models/commission_model.dart';
import '../providers/commission_provider.dart';
import '../services/commission_service.dart';

class CommissionManagementScreen extends StatefulWidget {
  const CommissionManagementScreen({super.key});

  @override
  State<CommissionManagementScreen> createState() =>
      _CommissionManagementScreenState();
}

class _CommissionManagementScreenState
    extends State<CommissionManagementScreen> {
  static const _forest = Color(0xFF14532D);
  final _percentageController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isActive = true;
  String _period = 'admin_commission_period_all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<CommissionProvider>().loadSettings();
    });
  }

  @override
  void dispose() {
    _percentageController.dispose();
    super.dispose();
  }

  Future<void> _save(CommissionSettings current) async {
    if (!_formKey.currentState!.validate()) return;
    final percentage = double.parse(
      _percentageController.text.trim().replaceAll(',', '.'),
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('admin_commission_confirm_title'.tr()),
        content: Text(
          'admin_commission_confirm_body'.tr(
            args: [
              percentage.toStringAsFixed(2),
              (_isActive
                      ? 'admin_commission_active'
                      : 'admin_commission_inactive')
                  .tr(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('confirm'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final ok = await context.read<CommissionProvider>().saveSettings(
      percentage: percentage,
      isActive: _isActive,
    );
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'admin_commission_saved'.tr()
              : 'admin_commission_save_failed'.tr(),
        ),
        backgroundColor: ok ? _forest : const Color(0xFFDC2626),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    return Scaffold(
      appBar: AppBar(title: Text('admin_commission_title'.tr())),
      body: Consumer<CommissionProvider>(
        builder: (context, provider, _) {
          final settings = provider.settings;
          if (_percentageController.text.isEmpty) {
            _percentageController.text = settings.commissionPercentage
                .toStringAsFixed(2);
            _isActive = settings.isActive;
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (provider.errorMessage != null)
                _ErrorBanner(message: provider.errorMessage!),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'admin_commission_global_rate'.tr(),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _percentageController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'admin_commission_rate'.tr(),
                            helperText: 'admin_commission_allowed_range'.tr(),
                            suffixText: '%',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final percentage = double.tryParse(
                              (value ?? '').trim().replaceAll(',', '.'),
                            );
                            if (percentage == null ||
                                percentage < 0 ||
                                percentage > 30) {
                              return 'admin_commission_validation'.tr();
                            }
                            return null;
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('admin_commission_active_title'.tr()),
                          subtitle: Text('admin_commission_active_help'.tr()),
                          value: _isActive,
                          activeThumbColor: _forest,
                          onChanged: (value) =>
                              setState(() => _isActive = value),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: provider.isSaving
                                ? null
                                : () => _save(settings),
                            icon: provider.isSaving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: Text('save'.tr()),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _PeriodSelector(
                value: _period,
                onChanged: (period) => setState(() => _period = period),
              ),
              const SizedBox(height: 12),
              StreamBuilder<List<CommissionRecord>>(
                stream: CommissionService().streamCommissions(
                  professionalOnly: false,
                ),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _ErrorBanner(
                      message: 'admin_commission_load_failed'.tr(),
                    );
                  }
                  final records = _filterRecords(
                    snapshot.data ?? const [],
                    _period,
                  );
                  final total = records.fold<double>(
                    0,
                    (sum, record) => sum + record.commissionAmount,
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _MetricCard(
                            label: 'admin_commission_revenue'.tr(),
                            value: '${total.toStringAsFixed(3)} TND',
                            color: _forest,
                          ),
                          _MetricCard(
                            label: 'transactions'.tr(),
                            value: '${records.length}',
                            color: const Color(0xFF2563EB),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _RevenueBars(records: records, textColor: textColor),
                      const SizedBox(height: 18),
                      Text(
                        'admin_commission_history'.tr(),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (records.isEmpty)
                        Text(
                          'admin_commission_empty'.tr(),
                          style: TextStyle(color: secondaryColor),
                        )
                      else
                        ...records.map(
                          (record) => Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isDark
                                    ? const Color(0xFF18382B)
                                    : const Color(0xFFE8F5E9),
                                child: const Icon(
                                  Icons.account_balance_wallet_outlined,
                                  color: _forest,
                                ),
                              ),
                              title: Text(
                                '${record.commissionAmount.toStringAsFixed(3)} ${record.currency} · ${record.commissionPercentage.toStringAsFixed(2)} %',
                              ),
                              subtitle: Text(
                                'admin_commission_service_amount'.tr(
                                  args: [
                                    record.grossAmount.toStringAsFixed(3),
                                    record.currency,
                                  ],
                                ),
                              ),
                              trailing: Text(
                                '${record.createdAt.day.toString().padLeft(2, '0')}/${record.createdAt.month.toString().padLeft(2, '0')}/${record.createdAt.year}',
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  List<CommissionRecord> _filterRecords(
    List<CommissionRecord> records,
    String period,
  ) {
    final now = DateTime.now();
    final days = switch (period) {
      'admin_commission_period_7' => 7,
      'admin_commission_period_30' => 30,
      _ => null,
    };
    if (days == null) return records;
    final start = now.subtract(Duration(days: days));
    return records
        .where((record) => !record.createdAt.isBefore(start))
        .toList();
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children:
          [
            'admin_commission_period_all',
            'admin_commission_period_7',
            'admin_commission_period_30',
          ].map((periodKey) {
            return ChoiceChip(
              label: Text(periodKey.tr()),
              selected: value == periodKey,
              onSelected: (_) => onChanged(periodKey),
            );
          }).toList(),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
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
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(color: color, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}

class _RevenueBars extends StatelessWidget {
  const _RevenueBars({required this.records, required this.textColor});

  final List<CommissionRecord> records;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final values = List<double>.generate(7, (index) {
      final date = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: 6 - index));
      return records
          .where(
            (record) =>
                record.createdAt.year == date.year &&
                record.createdAt.month == date.month &&
                record.createdAt.day == date.day,
          )
          .fold<double>(0, (sum, record) => sum + record.commissionAmount);
    });
    final maxValue = values.fold<double>(
      0,
      (max, value) => value > max ? value : max,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'admin_commission_chart_title'.tr(),
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 132,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (index) {
                  final date = now.subtract(Duration(days: 6 - index));
                  final height = maxValue == 0
                      ? 4.0
                      : 88 * values[index] / maxValue;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            height: height,
                            decoration: BoxDecoration(
                              color: const Color(0xFF14532D),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${date.day}/${date.month}',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(padding: const EdgeInsets.all(14), child: Text(message)),
    );
  }
}
