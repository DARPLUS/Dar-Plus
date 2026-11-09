import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../core/localization/app_localizations.dart';
import '../services/firebase_service.dart';

class BookingDetailScreen extends StatelessWidget {
  final Map<String, dynamic> booking;

  const BookingDetailScreen({super.key, required this.booking});

  Color _statusColor(String status) {
    switch (status) {
      case 'en_attente':
        return const Color(0xFFDE6D1B);
      case 'confirmee':
        return const Color(0xFF2563EB);
      case 'terminee':
        return const Color(0xFF10B981);
      case 'annulee':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF64748B);
    }
  }

  String _statusLabel(String status, BuildContext context) {
    switch (status) {
      case 'en_attente':
        return context.tr('tab_pending');
      case 'confirmee':
        return context.tr('tab_confirmed');
      case 'terminee':
        return context.tr('tab_completed');
      case 'annulee':
        return context.tr('tab_cancelled');
      default:
        return status;
    }
  }

  String _formatDate(dynamic ts) {
    if (ts is Timestamp) {
      final dt = ts.toDate();
      final days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
      final months = [
        'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
        'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
      ];
      return '${days[dt.weekday - 1]} ${dt.day} ${months[dt.month - 1]} ${dt.year}';
    }
    return '';
  }

  int _timelineStep(String status) {
    switch (status) {
      case 'en_attente':
        return 0;
      case 'confirmee':
        return 1;
      case 'terminee':
        return 3;
      case 'annulee':
        return -1;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = AppTheme.cardColorOf(context);
    final titleColor = AppTheme.titleColorOf(context);
    final subColor = AppTheme.subtitleColorOf(context);
    final borderColor = AppTheme.borderColorOf(context);

    final status = booking['status'] as String? ?? 'en_attente';
    final color = _statusColor(status);
    final proName = booking['proName'] as String? ?? 'Professionnel';
    final proPhone = booking['proPhone'] as String? ?? '';
    final serviceType = booking['serviceType'] as String? ?? '';
    final price = booking['price'] as String? ?? '';
    final address = booking['address'] as String? ?? '';
    final description = booking['description'] as String? ?? '';
    final scheduledDate = booking['scheduledDate'] as String? ?? '';
    final createdDate = _formatDate(booking['createdAt']);
    final bookingId = booking['id'] as String? ?? '';
    final isCancellable = status == 'en_attente';
    final isCancelled = status == 'annulee';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          context.tr('booking_detail_title'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: titleColor,
          ),
        ),
        backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.background,
        elevation: 0,
        iconTheme: IconThemeData(color: titleColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. Header card ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Icône pro
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D544E).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Color(0xFF0D544E),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          proName,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: titleColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D544E).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            serviceType,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0D544E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statusLabel(status, context),
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── 2. Informations ──────────────────────────────────────
            _SectionTitle(title: context.tr('booking_date'), icon: Icons.info_outline_rounded, titleColor: titleColor),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.tag_rounded,
                    label: context.tr('booking_id'),
                    value: bookingId.length > 12
                        ? '...${bookingId.substring(bookingId.length - 8)}'
                        : bookingId,
                    subColor: subColor,
                    titleColor: titleColor,
                  ),
                  _Divider(isDark: isDark),
                  _InfoRow(
                    icon: Icons.event_rounded,
                    label: context.tr('booking_date'),
                    value: scheduledDate.isNotEmpty ? scheduledDate : createdDate,
                    subColor: subColor,
                    titleColor: titleColor,
                  ),
                  _Divider(isDark: isDark),
                  _InfoRow(
                    icon: Icons.location_on_rounded,
                    label: context.tr('booking_address'),
                    value: address,
                    subColor: subColor,
                    titleColor: titleColor,
                  ),
                  if (price.isNotEmpty) ...[
                    _Divider(isDark: isDark),
                    _InfoRow(
                      icon: Icons.payments_rounded,
                      label: 'Tarif',
                      value: price,
                      subColor: subColor,
                      titleColor: const Color(0xFFDE6D1B),
                    ),
                  ],
                  if (description.isNotEmpty) ...[
                    _Divider(isDark: isDark),
                    _InfoRow(
                      icon: Icons.description_rounded,
                      label: context.tr('need_description'),
                      value: description,
                      subColor: subColor,
                      titleColor: titleColor,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── 3. Contact pro ───────────────────────────────────────
            if (proPhone.isNotEmpty) ...[
              _SectionTitle(
                  title: context.tr('contact_pro'),
                  icon: Icons.phone_rounded,
                  titleColor: titleColor),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D544E).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.phone_rounded,
                          color: Color(0xFF0D544E), size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            proName,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: titleColor),
                          ),
                          Text(proPhone,
                              style: TextStyle(fontSize: 13, color: subColor)),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                '${context.tr("call_pro")} : $proPhone'),
                            backgroundColor: const Color(0xFF0D544E),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0D544E),
                        side: const BorderSide(color: Color(0xFF0D544E)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                      child: Text(context.tr('call')),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ── 4. Timeline statut ───────────────────────────────────
            if (!isCancelled) ...[
              _SectionTitle(
                  title: context.tr('status'),
                  icon: Icons.timeline_rounded,
                  titleColor: titleColor),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: _TimelineWidget(
                  currentStep: _timelineStep(status),
                  isDark: isDark,
                  labels: [
                    context.tr('booking_timeline_request'),
                    context.tr('booking_timeline_confirm'),
                    context.tr('booking_timeline_progress'),
                    context.tr('booking_timeline_done'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ── 5. Bouton annuler ────────────────────────────────────
            if (isCancellable) ...[
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => _confirmCancel(context, bookingId),
                  icon: const Icon(Icons.cancel_rounded),
                  label: Text(
                    context.tr('cancel_booking'),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmCancel(BuildContext context, String bookingId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.warning_amber_rounded,
              color: Color(0xFFDC2626), size: 24),
          const SizedBox(width: 8),
          Text(context.tr('booking_cancel_confirm'),
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
        content: Text(
          'Voulez-vous vraiment annuler cette réservation ?',
          style: TextStyle(color: AppTheme.subtitleColorOf(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('cancel'),
                style:
                    TextStyle(color: AppTheme.subtitleColorOf(context))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final messenger = ScaffoldMessenger.of(context);
              final ok = await FirebaseService().cancelBooking(bookingId);
              if (context.mounted) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? context.tr('booking_cancelled_success')
                        : context.tr('error')),
                    backgroundColor: ok
                        ? const Color(0xFF10B981)
                        : const Color(0xFFDC2626),
                  ),
                );
                if (ok) Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(context.tr('confirm')),
          ),
        ],
      ),
    );
  }
}

// ── Widgets helpers ───────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color titleColor;
  const _SectionTitle(
      {required this.title, required this.icon, required this.titleColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF0D544E)),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.bold, color: titleColor),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color subColor;
  final Color titleColor;
  const _InfoRow(
      {required this.icon,
      required this.label,
      required this.value,
      required this.subColor,
      required this.titleColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF0D544E)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(fontSize: 11, color: subColor)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: titleColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final bool isDark;
  const _Divider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      color: isDark ? AppTheme.darkDivider : const Color(0xFFEDE8E1),
    );
  }
}

class _TimelineWidget extends StatelessWidget {
  final int currentStep;
  final bool isDark;
  final List<String> labels;

  const _TimelineWidget(
      {required this.currentStep,
      required this.isDark,
      required this.labels});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(labels.length, (i) {
        final isDone = i <= currentStep;
        final isActive = i == currentStep;
        final isLast = i == labels.length - 1;

        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: isActive ? 32 : 24,
                      height: isActive ? 32 : 24,
                      decoration: BoxDecoration(
                        color: isDone
                            ? const Color(0xFF0D544E)
                            : (isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0)),
                        shape: BoxShape.circle,
                        border: isActive
                            ? Border.all(
                                color: const Color(0xFF0D544E).withValues(alpha: 0.3),
                                width: 4)
                            : null,
                      ),
                      child: isDone
                          ? const Icon(Icons.check_rounded,
                              color: Colors.white, size: 14)
                          : null,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      labels[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isActive
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isDone
                            ? const Color(0xFF0D544E)
                            : AppTheme.subtitleColorOf(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 24),
                    color: i < currentStep
                        ? const Color(0xFF0D544E)
                        : (isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0)),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}
