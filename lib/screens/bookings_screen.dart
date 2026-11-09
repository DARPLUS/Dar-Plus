import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../core/localization/app_localizations.dart';
import '../services/firebase_service.dart';
import 'booking_detail_screen.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _tabs = [
    {'label': 'tab_all', 'filter': null},
    {'label': 'tab_pending', 'filter': 'en_attente'},
    {'label': 'tab_confirmed', 'filter': 'confirmee'},
    {'label': 'tab_completed', 'filter': 'terminee'},
    {'label': 'tab_cancelled', 'filter': 'annulee'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

  String _formatDate(dynamic createdAt) {
    if (createdAt is Timestamp) {
      final dt = createdAt.toDate();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = AppTheme.cardColorOf(context);
    final titleColor = AppTheme.titleColorOf(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          context.tr('my_bookings'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: titleColor,
          ),
        ),
        backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.background,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: const Color(0xFF0D544E),
          unselectedLabelColor: AppTheme.subtitleColorOf(context),
          indicatorColor: const Color(0xFF0D544E),
          indicatorWeight: 2.5,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontSize: 13),
          tabs: _tabs
              .map((t) => Tab(text: context.tr(t['label'] as String)))
              .toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs.map((tab) {
          final filter = tab['filter'];
          return _BookingTabView(
            statusFilter: filter,
            statusColor: _statusColor,
            statusLabel: _statusLabel,
            formatDate: _formatDate,
            cardColor: cardColor,
            titleColor: titleColor,
            isDark: isDark,
          );
        }).toList(),
      ),
    );
  }
}

class _BookingTabView extends StatelessWidget {
  final String? statusFilter;
  final Color Function(String) statusColor;
  final String Function(String, BuildContext) statusLabel;
  final String Function(dynamic) formatDate;
  final Color cardColor;
  final Color titleColor;
  final bool isDark;

  const _BookingTabView({
    required this.statusFilter,
    required this.statusColor,
    required this.statusLabel,
    required this.formatDate,
    required this.cardColor,
    required this.titleColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirebaseService()
          .streamClientBookings(statusFilter: statusFilter),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF0D544E)),
          );
        }

        final bookings = snapshot.data ?? [];

        if (bookings.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFD7F3EA).withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.calendar_today_outlined,
                    size: 44,
                    color: Color(0xFF0D544E),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  context.tr('no_bookings'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr('adjust_filters_hint'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.subtitleColorOf(context),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          itemCount: bookings.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final booking = bookings[index];
            return _BookingCard(
              booking: booking,
              statusColor: statusColor,
              statusLabel: statusLabel,
              formatDate: formatDate,
              cardColor: cardColor,
              titleColor: titleColor,
              isDark: isDark,
            );
          },
        );
      },
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final Color Function(String) statusColor;
  final String Function(String, BuildContext) statusLabel;
  final String Function(dynamic) formatDate;
  final Color cardColor;
  final Color titleColor;
  final bool isDark;

  const _BookingCard({
    required this.booking,
    required this.statusColor,
    required this.statusLabel,
    required this.formatDate,
    required this.cardColor,
    required this.titleColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final status = booking['status'] as String? ?? 'en_attente';
    final color = statusColor(status);
    final proName = booking['proName'] as String? ?? 'Professionnel';
    final serviceType = booking['serviceType'] as String? ?? '';
    final address = booking['address'] as String? ?? '';
    final scheduledDate = booking['scheduledDate'] as String? ?? '';
    final date = formatDate(booking['createdAt']);
    final bookingId = booking['id'] as String? ?? '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BookingDetailScreen(booking: booking),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? AppTheme.darkDivider
                  : const Color(0xFFEDE8E1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barre colorée statut
              Container(
                width: 5,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                  ),
                ),
              ),
              // Contenu
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              proName,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: titleColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              statusLabel(status, context),
                              style: TextStyle(
                                color: color,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
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
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0D544E),
                              ),
                            ),
                          ),
                          if (date.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.calendar_today_rounded,
                                size: 12,
                                color: AppTheme.subtitleColorOf(context)),
                            const SizedBox(width: 3),
                            Text(
                              date,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.subtitleColorOf(context),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (scheduledDate.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.access_time_rounded,
                                size: 13,
                                color: AppTheme.subtitleColorOf(context)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                scheduledDate,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.subtitleColorOf(context),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (address.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on_rounded,
                                size: 13,
                                color: AppTheme.subtitleColorOf(context)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                address,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.subtitleColorOf(context),
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ],
                      // Bouton annuler si en attente
                      if (status == 'en_attente') ...[
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () =>
                                _confirmCancel(context, bookingId),
                            icon: const Icon(Icons.cancel_outlined,
                                size: 16, color: Color(0xFFDC2626)),
                            label: Text(
                              context.tr('cancel_booking'),
                              style: const TextStyle(
                                color: Color(0xFFDC2626),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Flèche
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.subtitleColorOf(context),
                ),
              ),
            ],
          ),
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
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Color(0xFFDC2626), size: 24),
            const SizedBox(width: 8),
            Text(context.tr('booking_cancel_confirm'),
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Voulez-vous vraiment annuler cette réservation ? Cette action est irréversible.',
          style: TextStyle(
              fontSize: 14,
              color: AppTheme.subtitleColorOf(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('cancel'),
                style: TextStyle(
                    color: AppTheme.subtitleColorOf(context))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final messenger = ScaffoldMessenger.of(context);
              final successMsg = context.tr('booking_cancelled_success');
              final errorMsg = context.tr('error');
              final ok = await FirebaseService().cancelBooking(bookingId);
              messenger.showSnackBar(
                SnackBar(
                  content: Text(ok ? successMsg : errorMsg),
                  backgroundColor:
                      ok ? const Color(0xFF10B981) : const Color(0xFFDC2626),
                ),
              );
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
