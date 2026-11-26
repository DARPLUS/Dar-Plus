import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';

import '../theme/app_theme.dart';
import '../services/call_service.dart';
import '../services/firebase_service.dart';
import 'booking_rating_screen.dart';
import '../widgets/booking_client_avatar.dart';
import 'booking_chat_screen.dart';
import '../widgets/booking_report_button.dart';
import '../core/localization/service_type_localizer.dart';

class ProRequestsScreen extends StatefulWidget {
  const ProRequestsScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<ProRequestsScreen> createState() => _ProRequestsScreenState();
}

class _ProRequestsScreenState extends State<ProRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  String? _expandedId;
  late Stream<List<Map<String, dynamic>>> _bookingsStream;

  static const List<Map<String, String?>> _tabs = [
    {'label': 'pro_req_tab_all', 'filter': null},
    {'label': 'pro_req_tab_new', 'filter': 'en_attente'},
    {'label': 'pro_req_tab_inprog', 'filter': 'confirmee'},
    {'label': 'pro_req_tab_done', 'filter': 'terminee'},
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
    _bookingsStream = FirebaseService().streamProBookings().asBroadcastStream();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'en_attente':
        return const Color(0xFFE05D38);
      case 'confirmee':
        return const Color(0xFF0D544E);
      case 'terminee':
        return const Color(0xFF10B981);
      case 'annulee':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF64748B);
    }
  }

  String _statusLabel(String s, BuildContext ctx) {
    switch (s) {
      case 'en_attente':
        return ctx.tr('pro_req_status_new');
      case 'confirmee':
        return ctx.tr('pro_req_status_confirmed');
      case 'terminee':
        return ctx.tr('pro_req_status_done');
      case 'annulee':
        return ctx.tr('tab_cancelled');
      default:
        return s;
    }
  }

  Future<void> _openRatingPage(Map<String, dynamic> booking) async {
    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BookingRatingScreen(
          booking: booking,
          isProfessional: true,
          alreadySubmitted: booking['proReviewSubmitted'] == true,
        ),
      ),
    );
    if (submitted == true && mounted) {
      booking['proReviewSubmitted'] = true;
      setState(() {});
    }
  }

  String _fmtDate(dynamic ts) {
    if (ts is Timestamp) {
      final dt = ts.toDate();
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return '${'today_short'.tr()} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      final diff = dt.difference(now);
      if (diff.inDays == 1) {
        return '${'tomorrow_short'.tr()} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    if (ts is String && ts.isNotEmpty) return ts;
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkBackground : const Color(0xFFFAF7F2);
    final titleColor = AppTheme.titleColorOf(context);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _bookingsStream,
      builder: (context, bookingSnapshot) {
        final bookings = bookingSnapshot.data ?? const <Map<String, dynamic>>[];
        final pendingCount = bookings
            .where(
              (booking) =>
                  _normalizeBookingStatus(booking['status']) == 'en_attente',
            )
            .length;
        return Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: isDark
                ? const Color(0xFF0F2D2A)
                : const Color(0xFF0F2D2A),
            foregroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              onPressed: widget.onBack ?? () => Navigator.maybePop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'pro_req_title'.tr(),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '$pendingCount ${'pro_req_new_subtitle'.tr()}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFFE05D38),
                  ),
                ),
              ],
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.filter_list_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
            bottom: TabBar(
              controller: _tabCtrl,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: const Color(0xFFE05D38),
              unselectedLabelColor: Colors.white60,
              indicatorColor: const Color(0xFFE05D38),
              indicatorWeight: 2.5,
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: const TextStyle(fontSize: 13),
              tabs: _tabs.map((t) {
                final filter = t['filter'];
                if (filter == 'en_attente') {
                  return Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(context.tr(t['label'] as String)),
                        if (pendingCount > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE05D38),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$pendingCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }
                return Tab(text: context.tr(t['label'] as String));
              }).toList(),
            ),
          ),
          body: TabBarView(
            controller: _tabCtrl,
            children: _tabs.map((tab) {
              final filter = tab['filter'];
              return _RequestTabView(
                allBookings: bookings,
                isLoading:
                    bookingSnapshot.connectionState == ConnectionState.waiting,
                hasError: bookingSnapshot.hasError,
                statusFilter: filter,
                expandedId: _expandedId,
                onExpand: (id) =>
                    setState(() => _expandedId = _expandedId == id ? null : id),
                onRefresh: () => setState(() {
                  _expandedId = null;
                  _bookingsStream = FirebaseService()
                      .streamProBookings()
                      .asBroadcastStream();
                }),
                statusColor: _statusColor,
                statusLabel: _statusLabel,
                fmtDate: _fmtDate,
                isDark: isDark,
                titleColor: titleColor,
                onCompleted: _openRatingPage,
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

String _normalizeBookingStatus(dynamic value) {
  final raw = value?.toString().trim().toLowerCase() ?? '';
  if (raw.contains('attente') || raw.contains('pending') || raw == 'new') {
    return 'en_attente';
  }
  if (raw.contains('confirm') ||
      raw.contains('accept') ||
      raw.contains('progress')) {
    return 'confirmee';
  }
  if (raw.contains('termin') || raw.contains('complet')) return 'terminee';
  if (raw.contains('annul') || raw.contains('cancel')) return 'annulee';
  return raw;
}

// ── Tab view ──────────────────────────────────────────────────────────────────
class _RequestTabView extends StatelessWidget {
  final List<Map<String, dynamic>> allBookings;
  final bool isLoading;
  final bool hasError;
  final String? statusFilter;
  final String? expandedId;
  final void Function(String) onExpand;
  final VoidCallback onRefresh;
  final Color Function(String) statusColor;
  final String Function(String, BuildContext) statusLabel;
  final String Function(dynamic) fmtDate;
  final bool isDark;
  final Color titleColor;
  final Future<void> Function(Map<String, dynamic>) onCompleted;

  const _RequestTabView({
    required this.allBookings,
    required this.isLoading,
    required this.hasError,
    required this.statusFilter,
    required this.expandedId,
    required this.onExpand,
    required this.onRefresh,
    required this.statusColor,
    required this.statusLabel,
    required this.fmtDate,
    required this.isDark,
    required this.titleColor,
    required this.onCompleted,
  });

  @override
  Widget build(BuildContext context) {
    if (hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 48,
                color: Color(0xFFE05D38),
              ),
              const SizedBox(height: 12),
              Text(
                'pro_req_load_error'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.subtitleColorOf(context),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded),
                label: Text('retry'.tr()),
              ),
            ],
          ),
        ),
      );
    }
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFE05D38)),
      );
    }
    final bookings = statusFilter == null
        ? allBookings
        : allBookings
              .where(
                (booking) =>
                    _normalizeBookingStatus(booking['status']) == statusFilter,
              )
              .toList();
    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_rounded, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'pro_req_empty'.tr(),
              style: TextStyle(
                fontSize: 15,
                color: AppTheme.subtitleColorOf(context),
              ),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      itemCount: bookings.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _BookingCard(
        booking: bookings[i],
        isExpanded: expandedId == bookings[i]['id'],
        onTap: () => onExpand(bookings[i]['id']?.toString() ?? ''),
        statusColor: statusColor,
        statusLabel: statusLabel,
        fmtDate: fmtDate,
        isDark: isDark,
        titleColor: titleColor,
        onCompleted: onCompleted,
      ),
    );
  }
}

// ── Booking Card ──────────────────────────────────────────────────────────────
class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final bool isExpanded;
  final VoidCallback onTap;
  final Color Function(String) statusColor;
  final String Function(String, BuildContext) statusLabel;
  final String Function(dynamic) fmtDate;
  final bool isDark;
  final Color titleColor;
  final Future<void> Function(Map<String, dynamic>) onCompleted;

  const _BookingCard({
    required this.booking,
    required this.isExpanded,
    required this.onTap,
    required this.statusColor,
    required this.statusLabel,
    required this.fmtDate,
    required this.isDark,
    required this.titleColor,
    required this.onCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final status = _normalizeBookingStatus(booking['status']);
    final color = statusColor(status);
    final clientName =
        booking['clientName']?.toString().trim().isNotEmpty == true
        ? booking['clientName'].toString().trim()
        : 'pro_req_client'.tr();
    final description = booking['description']?.toString() ?? '';
    final serviceType = localizeServiceType(booking['serviceType']?.toString());
    final address = booking['address']?.toString() ?? '';
    final price = booking['price']?.toString() ?? '';
    final dateLabel = fmtDate(booking['scheduledDate'] ?? booking['createdAt']);
    final bookingId = booking['id']?.toString() ?? '';
    final isPending = status == 'en_attente';
    final isUrgent =
        booking['isUrgent'] == true || description.trimLeft().startsWith('🚨');

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isPending
                  ? color.withValues(alpha: 0.5)
                  : AppTheme.borderColorOf(context),
              width: isPending ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    // Avatar client
                    BookingClientAvatar(
                      booking: booking,
                      size: 46,
                      borderRadius: 23,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  clientName,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: titleColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  statusLabel(status, context),
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (isUrgent) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDC2626)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.emergency_rounded,
                                    size: 13,
                                    color: Color(0xFFDC2626),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'pro_req_urgent_badge'.tr(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFDC2626),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 2),
                          if (serviceType.isNotEmpty)
                            Text(
                              serviceType,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AppTheme.subtitleColorOf(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_rounded,
                                size: 12,
                                color: Color(0xFF64748B),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                flex: 4,
                                child: Text(
                                  dateLabel,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFF64748B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.location_on_rounded,
                                size: 12,
                                color: Color(0xFFE05D38),
                              ),
                              const SizedBox(width: 2),
                              Flexible(
                                flex: 3,
                                child: Text(
                                  address,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFF64748B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                flex: 2,
                                child: Text(
                                  price,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFE05D38),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        Icons.expand_more_rounded,
                        color: AppTheme.subtitleColorOf(context),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Détails expandables ─────────────────────────────
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: _ExpandedDetails(
                  booking: booking,
                  bookingId: bookingId,
                  serviceType: serviceType,
                  address: address,
                  dateLabel: dateLabel,
                  price: price,
                  description: description,
                  status: status,
                  isDark: isDark,
                  context: context,
                  onCompleted: onCompleted,
                ),
                crossFadeState: isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 220),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Détails expandables ───────────────────────────────────────────────────────
class _ExpandedDetails extends StatelessWidget {
  final Map<String, dynamic> booking;
  final String bookingId;
  final String serviceType;
  final String address;
  final String dateLabel;
  final String price;
  final String description;
  final String status;
  final bool isDark;
  final BuildContext context;
  final Future<void> Function(Map<String, dynamic>) onCompleted;

  const _ExpandedDetails({
    required this.booking,
    required this.bookingId,
    required this.serviceType,
    required this.address,
    required this.dateLabel,
    required this.price,
    required this.description,
    required this.status,
    required this.isDark,
    required this.context,
    required this.onCompleted,
  });

  @override
  Widget build(BuildContext ctx) {
    final divColor = isDark ? AppTheme.darkDivider : const Color(0xFFF1F5F9);
    final canChat =
        status == 'confirmee' ||
        status == 'terminee' ||
        (status == 'annulee' && booking['acceptedAt'] is Timestamp);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(height: 1, color: divColor),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Grille infos
              Row(
                children: [
                  _InfoChip(
                    icon: Icons.location_on_rounded,
                    label: address,
                    color: const Color(0xFFE05D38),
                  ),
                  const SizedBox(width: 10),
                  _InfoChip(
                    icon: Icons.schedule_rounded,
                    label: dateLabel,
                    color: const Color(0xFF0D544E),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _InfoChip(
                    icon: Icons.build_rounded,
                    label: localizeServiceType(serviceType),
                    color: const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 10),
                  _InfoChip(
                    icon: Icons.payments_rounded,
                    label: price,
                    color: const Color(0xFFE05D38),
                  ),
                ],
              ),
              if (description.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: booking['isUrgent'] == true
                        ? const Color(0xFFDC2626).withValues(alpha: 0.07)
                        : (isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF8FAFC)),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: booking['isUrgent'] == true
                          ? const Color(0xFFDC2626).withValues(alpha: 0.25)
                          : (isDark
                                ? AppTheme.darkDivider
                                : const Color(0xFFE2E8F0)),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'pro_req_description_label'.tr(),
                        style: TextStyle(
                          color: booking['isUrgent'] == true
                              ? const Color(0xFFDC2626)
                              : AppTheme.subtitleColorOf(ctx),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description
                            .trimLeft()
                            .replaceFirst('🚨', '')
                            .trimLeft(),
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.titleColorOf(ctx),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (booking['clientLocationShared'] == true &&
                  booking['clientLatitude'] is num &&
                  booking['clientLongitude'] is num) ...[
                const SizedBox(height: 8),
                _InfoChip(
                  icon: Icons.my_location_rounded,
                  label:
                      '${'pro_req_shared_location'.tr()}: '
                      '${(booking['clientLatitude'] as num).toStringAsFixed(5)}, '
                      '${(booking['clientLongitude'] as num).toStringAsFixed(5)}',
                  color: const Color(0xFF0D9488),
                ),
              ],
              BookingReportButton(booking: booking, isProfessional: true),
              const SizedBox(height: 14),
              // Boutons Refuser / Accepter (si en attente)
              if (status == 'en_attente') ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _updateStatus(ctx, 'annulee'),
                        icon: const Icon(Icons.close_rounded, size: 16),
                        label: Text(ctx.tr('pro_req_refuse')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFDC2626),
                          side: const BorderSide(color: Color(0xFFDC2626)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _updateStatus(ctx, 'confirmee'),
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: Text(ctx.tr('pro_req_accept')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE05D38),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (status == 'confirmee') ...[
                // Bouton Terminer
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _updateStatus(ctx, 'terminee'),
                    icon: const Icon(Icons.done_all_rounded, size: 16),
                    label: Text(ctx.tr('pro_req_mark_done')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ),
              ],
              if (status == 'terminee' && bookingId.isNotEmpty) ...[
                if (booking['proReviewSubmitted'] == true)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF10B981),
                    ),
                    title: Text(
                      '${'rating_already_submitted'.tr()} ${booking['clientName'] ?? 'pro_req_client'.tr()}',
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => onCompleted(booking),
                      icon: const Icon(Icons.star_rate_rounded),
                      label: Text('rating_rate_client'.tr()),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0D544E),
                        side: BorderSide(
                          color: Theme.of(ctx).colorScheme.outlineVariant,
                        ),
                        shape: const StadiumBorder(),
                        minimumSize: const Size.fromHeight(52),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
              ],
              if (canChat) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(ctx).push(
                      MaterialPageRoute(
                        builder: (_) => BookingChatScreen(booking: booking),
                      ),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline_rounded),
                    label: Text(ctx.tr('booking_chat_action')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF14532D),
                      side: const BorderSide(color: Color(0xFF14532D)),
                      shape: const StadiumBorder(),
                      minimumSize: const Size.fromHeight(52),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: (booking['clientId']?.toString() ?? '').isEmpty
                        ? null
                        : () => CallService.instance.startCall(
                            calleeId: booking['clientId'].toString(),
                            calleeName:
                                booking['clientName']?.toString() ??
                                'pro_req_client'.tr(),
                            bookingId: bookingId,
                            serviceType: serviceType,
                          ),
                    icon: const Icon(Icons.call_rounded),
                    label: Text(ctx.tr('call_client')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0D544E),
                      side: const BorderSide(color: Color(0xFF0D544E)),
                      shape: const StadiumBorder(),
                      minimumSize: const Size.fromHeight(52),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _updateStatus(BuildContext ctx, String newStatus) async {
    final messenger = ScaffoldMessenger.of(ctx);
    final successMessage = newStatus == 'confirmee'
        ? ctx.tr('pro_req_accepted_snack')
        : newStatus == 'terminee'
        ? ctx.tr('pro_req_done_snack')
        : ctx.tr('pro_req_refused_snack');
    final errorMessage = ctx.tr('error');
    final ok = await FirebaseService().updateBookingStatus(
      bookingId,
      newStatus,
    );
    final msg = ok ? successMessage : errorMessage;
    messenger.showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: ok
            ? (newStatus == 'annulee'
                  ? const Color(0xFFDC2626)
                  : const Color(0xFF10B981))
            : const Color(0xFFDC2626),
        duration: const Duration(seconds: 2),
      ),
    );
    if (ok && newStatus == 'terminee') {
      final completedBooking = Map<String, dynamic>.from(booking)
        ..['status'] = 'terminee';
      await onCompleted(completedBooking);
    }
  }
}

// ── Info Chip ─────────────────────────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? AppTheme.darkDivider : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.titleColorOf(context),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
