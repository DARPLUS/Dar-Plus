import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../theme/app_theme.dart';
import '../services/call_service.dart';
import '../services/firebase_service.dart';
import 'booking_chat_screen.dart';
import 'booking_rating_screen.dart';
import '../widgets/booking_report_button.dart';

import 'package:easy_localization/easy_localization.dart';

class BookingDetailScreen extends StatefulWidget {
  final Map<String, dynamic> booking;

  const BookingDetailScreen({super.key, required this.booking});

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  late final Map<String, dynamic> _booking;
  Map<String, dynamic> get booking => _booking;
  bool _hasSubmittedRating = false;
  bool _ratingPageOpen = false;

  @override
  void initState() {
    super.initState();
    _booking = Map<String, dynamic>.from(widget.booking);
    _hasSubmittedRating = booking['clientReviewSubmitted'] == true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prepareRatingPrompt();
    });
  }

  Future<void> _prepareRatingPrompt() async {
    final bookingId = booking['id']?.toString() ?? '';
    if (booking['status'] != 'terminee' || bookingId.isEmpty) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .get();
      if (snapshot.exists && mounted) {
        booking.addAll(snapshot.data()!);
        booking['id'] = bookingId;
        _hasSubmittedRating = booking['clientReviewSubmitted'] == true;
      }
    } catch (_) {}
    if (mounted && !_hasSubmittedRating) _openRatingPage();
  }

  Future<void> _openRatingPage() async {
    if (!mounted || _ratingPageOpen) return;
    _ratingPageOpen = true;
    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BookingRatingScreen(
          booking: booking,
          isProfessional: false,
          alreadySubmitted: _hasSubmittedRating,
        ),
      ),
    );
    _ratingPageOpen = false;
    if (submitted == true && mounted) {
      setState(() => _hasSubmittedRating = true);
    }
  }

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
        return 'tab_pending'.tr();
      case 'confirmee':
        return 'tab_confirmed'.tr();
      case 'terminee':
        return 'tab_completed'.tr();
      case 'annulee':
        return 'tab_cancelled'.tr();
      default:
        return status;
    }
  }

  String _formatDate(dynamic ts) {
    if (ts is Timestamp) {
      final dt = ts.toDate();
      final days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
      final months = [
        'janvier',
        'février',
        'mars',
        'avril',
        'mai',
        'juin',
        'juillet',
        'août',
        'septembre',
        'octobre',
        'novembre',
        'décembre',
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
    final proId = booking['proId']?.toString() ?? '';
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
    final canChat =
        status == 'confirmee' ||
        status == 'terminee' ||
        (status == 'annulee' && booking['acceptedAt'] is Timestamp);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'booking_detail_title'.tr(),
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
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D544E)
                                .withValues(alpha: 0.1),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
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
            _SectionTitle(
              title: 'booking_date'.tr(),
              icon: Icons.info_outline_rounded,
              titleColor: titleColor,
            ),
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
                    label: 'booking_id'.tr(),
                    value: bookingId.length > 12
                        ? '...${bookingId.substring(bookingId.length - 8)}'
                        : bookingId,
                    subColor: subColor,
                    titleColor: titleColor,
                  ),
                  _Divider(isDark: isDark),
                  _InfoRow(
                    icon: Icons.event_rounded,
                    label: 'booking_date'.tr(),
                    value: scheduledDate.isNotEmpty
                        ? scheduledDate
                        : createdDate,
                    subColor: subColor,
                    titleColor: titleColor,
                  ),
                  _Divider(isDark: isDark),
                  _InfoRow(
                    icon: Icons.location_on_rounded,
                    label: 'booking_address'.tr(),
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
                      label: 'need_description'.tr(),
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
            if (proPhone.isNotEmpty || proId.isNotEmpty) ...[
              _SectionTitle(
                title: 'contact_pro'.tr(),
                icon: Icons.phone_rounded,
                titleColor: titleColor,
              ),
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
                      child: const Icon(
                        Icons.phone_rounded,
                        color: Color(0xFF0D544E),
                        size: 20,
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
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: titleColor,
                            ),
                          ),
                          if (proPhone.isNotEmpty)
                            Text(
                              proPhone,
                              style: TextStyle(fontSize: 13, color: subColor),
                            ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: proId.isEmpty
                          ? null
                          : () => CallService.instance.startCall(
                              calleeId: proId,
                              calleeName: proName,
                              bookingId: bookingId,
                              serviceType: serviceType,
                            ),
                      icon: const Icon(Icons.call_rounded, size: 18),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0D544E),
                        side: const BorderSide(color: Color(0xFF0D544E)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      label: Text('call'.tr()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            if (status == 'terminee' && bookingId.isNotEmpty) ...[
              _SectionTitle(
                title: 'rating_page_title'.tr(),
                icon: Icons.star_rate_rounded,
                titleColor: titleColor,
              ),
              const SizedBox(height: 10),
              if (_hasSubmittedRating)
                Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF10B981),
                    ),
                    title: Text('${'rating_already_submitted'.tr()} $proName.'),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _openRatingPage,
                    icon: const Icon(Icons.star_rate_rounded),
                    label: Text('rating_rate_professional'.tr()),
                  ),
                ),
              const SizedBox(height: 20),
            ],
            if (canChat) ...[
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BookingChatScreen(booking: booking),
                    ),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                  label: Text(
                    'booking_chat_action'.tr(),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF14532D),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            BookingReportButton(booking: booking, isProfessional: false),
            const SizedBox(height: 20),

            // ── 4. Timeline statut ───────────────────────────────────
            if (!isCancelled) ...[
              _SectionTitle(
                title: 'status'.tr(),
                icon: Icons.timeline_rounded,
                titleColor: titleColor,
              ),
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
                    'booking_timeline_request'.tr(),
                    'booking_timeline_confirm'.tr(),
                    'booking_timeline_progress'.tr(),
                    'booking_timeline_done'.tr(),
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
                    'cancel_booking'.tr(),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFDC2626),
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              'booking_cancel_confirm'.tr(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'booking_cancel_warning'.tr(),
          style: TextStyle(color: AppTheme.subtitleColorOf(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'cancel'.tr(),
              style: TextStyle(color: AppTheme.subtitleColorOf(context)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final messenger = ScaffoldMessenger.of(context);
              final ok = await FirebaseService().cancelBooking(bookingId);
              if (context.mounted) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      ok ? 'booking_cancelled_success'.tr() : 'error'.tr(),
                    ),
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
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('confirm'.tr()),
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
  const _SectionTitle({
    required this.title,
    required this.icon,
    required this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF0D544E)),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: titleColor,
          ),
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
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.subColor,
    required this.titleColor,
  });

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
                Text(label, style: TextStyle(fontSize: 11, color: subColor)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                ),
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

  const _TimelineWidget({
    required this.currentStep,
    required this.isDark,
    required this.labels,
  });

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
                                color: const Color(0xFF0D544E)
                                    .withValues(alpha: 0.3),
                                width: 4,
                              )
                            : null,
                      ),
                      child: isDone
                          ? const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 14,
                            )
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
