import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import '../providers/locale_provider.dart';
import '../core/localization/auth_message_localizer.dart';
import '../models/payment_model.dart';
import '../widgets/pro_avatar_widget.dart';
import '../widgets/booking_client_avatar.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import '../services/call_service.dart';
import '../services/firebase_service.dart';
import '../services/commission_service.dart';
import 'pro_requests_screen.dart';
import 'client_profile_screen.dart';
import 'map_screen.dart';
import 'pro_services_screen.dart';
import 'professional_earnings_screen.dart';
import 'availability_management_screen.dart';
import 'booking_chat_screen.dart';

class ProHomeScreen extends StatefulWidget {
  final String proName;
  final String serviceType;

  const ProHomeScreen({
    super.key,
    this.proName = 'Mohamed',
    this.serviceType = 'Plomberie & Sanitaire',
  });

  @override
  State<ProHomeScreen> createState() => _ProHomeScreenState();
}

class _WeeklyBookingsChart extends StatelessWidget {
  const _WeeklyBookingsChart({required this.bookings});
  final List<Map<String, dynamic>> bookings;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final totals = List<double>.generate(7, (i) {
      final day = start.add(Duration(days: i));
      return bookings
          .where((b) {
            if ((b['status'] ?? '').toString().toLowerCase() != 'terminee')
              return false;
            DateTime? date;
            for (final raw in [
              b['completedAt'],
              b['updatedAt'],
              b['scheduledDateKey'],
              b['scheduledDate'],
              b['createdAt'],
            ]) {
              if (raw is DateTime) date = raw;
              if (raw is String) date = DateTime.tryParse(raw);
              if (date == null && raw != null) {
                try {
                  date = (raw as dynamic).toDate() as DateTime;
                } catch (_) {}
              }
              if (date != null) break;
            }
            return date != null &&
                date.year == day.year &&
                date.month == day.month &&
                date.day == day.day;
          })
          .fold<double>(0, (sum, b) {
            final value = b['baseAmount'] ?? b['price'];
            if (value is num) return sum + value.toDouble();
            final match = RegExp(r'([0-9]+(?:[.,][0-9]+)?)')
                .firstMatch(value?.toString() ?? '');
            return sum +
                (match == null
                    ? 0
                    : double.tryParse(match.group(1)!.replaceAll(',', '.')) ??
                          0);
          });
    });
    final maxValue = totals.fold<double>(0, (a, b) => a > b ? a : b);
    const labels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'pro_chart_revenue'.tr(),
          style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (i) {
              final height = maxValue == 0
                  ? 3.0
                  : (totals[i] / maxValue * 70).clamp(3.0, 70.0).toDouble();
              return Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      totals[i] == 0 ? '' : totals[i].toStringAsFixed(0),
                      style: const TextStyle(fontSize: 9),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: height,
                      width: 18,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE05D38),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(labels[i], style: const TextStyle(fontSize: 10)),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _ProHomeScreenState extends State<ProHomeScreen> {
  bool _isAvailable = true;
  bool _isSharingLocation = false;
  bool _isLocationActionInProgress = false;
  int _currentBottomNavIndex = 0;
  String? _proPhotoBase64;
  String? _proPhotoUrl;
  int _unreadMessages = 0;
  double? _rating;
  late String _displayProName;
  StreamSubscription<int>? _unreadMessagesSub;
  late final Stream<Map<String, dynamic>> _ratingSummaryStream;

  @override
  void initState() {
    super.initState();
    _displayProName = widget.proName;
    _ratingSummaryStream = FirebaseService().streamCurrentUserRatingSummary();
    _loadProPhoto();
    _listenUnreadMessages();
  }

  void _listenUnreadMessages() {
    _unreadMessagesSub = FirebaseService()
        .streamUnreadMessageCount(isPro: true)
        .listen((count) {
          if (mounted) setState(() => _unreadMessages = count);
        });
  }

  @override
  void dispose() {
    _unreadMessagesSub?.cancel();
    super.dispose();
  }

  Future<void> _loadProPhoto() async {
    try {
      final data = await FirebaseService().getCurrentUserData();
      if (data != null && mounted) {
        final shouldResumeLocationSharing = data['isLocationSharing'] == true;
        final base64Photo = data['photoBase64']?.toString().trim() ?? '';
        final urlPhoto = data['photoUrl']?.toString().trim() ?? '';
        setState(() {
          final fullName = data['fullName']?.toString().trim() ?? '';
          if (fullName.isNotEmpty) _displayProName = fullName;
          _isAvailable = data['available'] as bool? ?? true;
          _isSharingLocation = data['isLocationSharing'] == true;
          final rating = data['rating'];
          _rating = rating is num
              ? rating.toDouble()
              : double.tryParse(rating?.toString() ?? '');
          _proPhotoBase64 = base64Photo.isEmpty ? null : base64Photo;
          _proPhotoUrl = urlPhoto.isEmpty ? null : urlPhoto;
        });
        if (shouldResumeLocationSharing) {
          final resumed = await FirebaseService().updateProfessionalLocation();
          if (!resumed && mounted) {
            await FirebaseService().stopProfessionalLocationSharing();
            if (mounted) setState(() => _isSharingLocation = false);
          }
        }
      }
    } catch (_) {}
  }

  final Stream<List<Map<String, dynamic>>> _bookingsStream = FirebaseService()
      .streamProBookings();
  final List<Map<String, dynamic>> _interventions = const [];
  final List<Map<String, dynamic>> _pendingRequests = const [];

  DateTime? _bookingDate(Map<String, dynamic> booking) {
    for (final value in [
      booking['scheduledDateKey'],
      booking['scheduledDate'],
      booking['completedAt'],
      booking['updatedAt'],
      booking['createdAt'],
    ]) {
      if (value is DateTime) return value;
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return parsed;
      }
      if (value != null) {
        try {
          return (value as dynamic).toDate() as DateTime;
        } catch (_) {}
      }
    }
    return null;
  }

  double _bookingAmount(Map<String, dynamic> booking) {
    final value = booking['baseAmount'] ?? booking['price'];
    if (value is num) return value.toDouble();
    final match = RegExp(r'([0-9]+(?:[.,][0-9]+)?)')
        .firstMatch(value?.toString() ?? '');
    return match == null
        ? 0
        : double.tryParse(match.group(1)!.replaceAll(',', '.')) ?? 0;
  }

  bool _isSameDay(DateTime? a, DateTime b) =>
      a != null && a.year == b.year && a.month == b.month && a.day == b.day;
  bool _isCompleted(Map<String, dynamic> b) =>
      (b['status'] ?? '').toString().toLowerCase() == 'terminee';
  bool _isCancelled(Map<String, dynamic> b) =>
      (b['status'] ?? '').toString().toLowerCase() == 'annulee';
  bool _isPending(Map<String, dynamic> b) =>
      (b['status'] ?? '').toString().toLowerCase() == 'en_attente';

  String _bookingStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'en_attente':
        return 'pro_req_status_new'.tr();
      case 'confirmee':
        return 'pro_req_status_confirmed'.tr();
      case 'terminee':
        return 'pro_req_status_done'.tr();
      case 'annulee':
        return 'tab_cancelled'.tr();
      default:
        return status;
    }
  }

  Widget _buildBookingCard(BuildContext context, Map<String, dynamic> booking) {
    final status = (booking['status'] ?? 'en_attente').toString();
    final completed = _isCompleted(booking);
    final date = _bookingDate(booking);
    final time = date == null
        ? 'pro_time_to_confirm'.tr()
        : '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: BookingClientAvatar(booking: booking, size: 44),
        title: Text(
          (booking['clientName'] ?? booking['clientFullName'] ?? 'Client')
              .toString(),
        ),
        subtitle: Text(
          '${booking['serviceType'] ?? 'Service'} • $time\n${booking['address'] ?? 'pro_address_missing'.tr()}',
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${_bookingAmount(booking).toStringAsFixed(0)} TND',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              _bookingStatusLabel(status),
              style: TextStyle(
                fontSize: 11,
                color: completed ? Colors.green : const Color(0xFFE05D38),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>();
    context.watch<LocaleProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgCream = isDark ? const Color(0xFF0F172A) : const Color(0xFFFAF7F2);
    const orangeAccent = Color(0xFFE05D38);

    return Scaffold(
      backgroundColor: bgCream,
      body: _currentBottomNavIndex == 1
          ? ProRequestsScreen(
              onBack: () => setState(() => _currentBottomNavIndex = 0),
            )
          : _currentBottomNavIndex == 2
          ? const BookingConversationsScreen(isProfessional: true)
          : _currentBottomNavIndex == 3
          ? const ProfessionalEarningsScreen()
          : _currentBottomNavIndex == 5
          ? AvailabilityManagementScreen(
              onClose: () => setState(() => _currentBottomNavIndex = 4),
            )
          : _currentBottomNavIndex == 4
          ? FutureBuilder<Map<String, dynamic>?>(
              future: FirebaseService().getCurrentUserData(),
              builder: (context, snapshot) {
                final data = snapshot.data;
                final name = (data?['fullName'] ?? _displayProName).toString();
                final email = (data?['email'] ?? '').toString();
                final phone = (data?['phone'] ?? '').toString();
                return ClientProfileScreen(
                  userName: name,
                  userEmail: email,
                  userPhone: phone,
                  isProfessional: true,
                  onManageAvailability: () =>
                      setState(() => _currentBottomNavIndex = 5),
                  onViewStats: () => setState(() => _currentBottomNavIndex = 0),
                );
              },
            )
          : SafeArea(
              top: false,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. TOP DARK HEADER (matching screenshot)
                    _buildDarkHeader(context),

                    // 2. MAIN BODY (matching screenshot)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),

                          // Quick Action Buttons (Demandes, Dispo, Messages, Revenus)
                          _buildQuickActionCards(context),

                          const SizedBox(height: 12),
                          _buildLocationSharingButton(context),

                          const SizedBox(height: 14),

                          // Alert / Notification Banner (2 nouvelles demandes!)
                          _buildNotificationBanner(context),

                          const SizedBox(height: 20),

                          // Section Interventions d'aujourd'hui
                          _buildInterventionsSection(context),

                          const SizedBox(height: 20),

                          // Section Performance cette semaine (matching screenshot 2)
                          StreamBuilder<List<Map<String, dynamic>>>(
                            stream: _bookingsStream,
                            builder: (context, snapshot) =>
                                _buildPerformanceCard(
                                  snapshot.data ?? const [],
                                ),
                          ),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
      // 3. BOTTOM NAVIGATION BAR (matching screenshot)
      bottomNavigationBar: _buildBottomNavigationBar(orangeAccent),
    );
  }

  // ─── 1. DARK HEADER ────────────────────────────────────────────────────────
  Widget _buildDarkHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20,
        right: 20,
        bottom: 24,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF172633), Color(0xFF123B3A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row: Avatar, Greeting, Notifications & Settings
          Row(
            children: [
              // Pro Avatar with green online dot
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ProAvatarWidget(
                    name: widget.proName,
                    photoBase64: _proPhotoBase64 ?? '',
                    photoUrl: _proPhotoUrl ?? '',
                    size: 50,
                    borderRadius: 16,
                    showVerifiedBadge: false,
                  ),
                  Positioned(
                    right: -3,
                    bottom: -3,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: _isAvailable
                            ? const Color(0xFF22C55E)
                            : Colors.grey,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF172633),
                          width: 2.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              // Greeting
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${(DateTime.now().hour < 18 ? 'good_morning' : 'good_evening').tr()},',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          _displayProName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                    ),
                  ],
                ),
              ),
              // Bell Notification Button with orange badge
              GestureDetector(
                onTap: () => _showNotificationsDialog(context),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B413E),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: const Icon(
                        Icons.notifications_rounded,
                        color: Color(0xFFFBBF24),
                        size: 20,
                      ),
                    ),
                    Positioned(
                      top: 1,
                      right: 1,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF97316),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Settings Button
              GestureDetector(
                onTap: () => _showSettingsModal(context),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B413E),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: const Icon(
                    Icons.settings_rounded,
                    color: Colors.white70,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // "Vous êtes disponible" Toggle Card (matches screenshot)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0E4B3E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF156554), width: 1.2),
            ),
            child: Row(
              children: [
                // Pulse Indicator
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isAvailable
                        ? const Color(0xFF156554)
                        : Colors.white.withValues(alpha: 0.1),
                  ),
                  child: Center(
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isAvailable
                            ? const Color(0xFF22C55E)
                            : Colors.grey.shade400,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isAvailable
                            ? 'pro_status_available'.tr()
                            : 'pro_status_unavailable'.tr(),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isAvailable
                            ? 'pro_available_sub'.tr()
                            : 'pro_unavailable_sub'.tr(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                      ),
                    ],
                  ),
                ),
                // Switch
                Switch(
                  value: _isAvailable,
                  activeThumbColor: Colors.white,
                  activeTrackColor: const Color(0xFF22C55E),
                  inactiveThumbColor: Colors.grey.shade300,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
                  onChanged: (val) async {
                    final previous = _isAvailable;
                    setState(() => _isAvailable = val);
                    try {
                      await FirebaseService().updateProAvailability(val);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            val
                                ? 'pro_status_online_snack'.tr()
                                : 'pro_status_offline_snack'.tr(),
                          ),
                          backgroundColor: val
                              ? const Color(0xFF0E4B3E)
                              : Colors.grey.shade800,
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      setState(() => _isAvailable = previous);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'profile_availability_error'.tr(
                              namedArgs: {'error': e.toString()},
                            ),
                          ),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Indicateurs calculés depuis les réservations réelles.
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _bookingsStream,
            builder: (context, snapshot) {
              final bookings = snapshot.data ?? const <Map<String, dynamic>>[];
              final now = DateTime.now();
              final todayCount = bookings
                  .where(
                    (b) => _isSameDay(_bookingDate(b), now) && !_isCancelled(b),
                  )
                  .length;
              return Row(
                children: [
                  Expanded(
                    child: StreamBuilder<List<PaymentModel>>(
                      stream: CommissionService().streamPayments(
                        professionalOnly: true,
                      ),
                      builder: (context, paymentSnapshot) {
                        final payments =
                            paymentSnapshot.data ?? const <PaymentModel>[];
                        final monthNet = payments
                            .where(
                              (payment) =>
                                  payment.isSuccess &&
                                  payment.createdAt.year == now.year &&
                                  payment.createdAt.month == now.month,
                            )
                            .fold<double>(
                              0,
                              (sum, payment) =>
                                  sum + payment.professionalNetAmount,
                            );
                        return _buildDarkStatCard(
                          icon: Icons.savings_rounded,
                          iconColor: const Color(0xFFF59E0B),
                          value: paymentSnapshot.hasError
                              ? '—'
                              : '${monthNet.toStringAsFixed(0)} TND',
                          label: 'pro_stat_month'.tr(),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildDarkStatCard(
                      icon: Icons.check_box_rounded,
                      iconColor: const Color(0xFF10B981),
                      value: '$todayCount',
                      label: 'pro_stat_today'.tr(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StreamBuilder<Map<String, dynamic>>(
                      stream: _ratingSummaryStream,
                      builder: (context, snapshot) {
                        final value = snapshot.data?['rating'];
                        final rating = value is num
                            ? value.toDouble()
                            : (snapshot.hasData ? null : _rating);
                        return _buildDarkStatCard(
                          icon: Icons.star_rounded,
                          iconColor: const Color(0xFFF59E0B),
                          value: rating == null
                              ? '—'
                              : '${rating.toStringAsFixed(1)}/5',
                          label: 'pro_stat_rating'.tr(),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // Helper for Dark Stat Cards
  Widget _buildDarkStatCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF203C40),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 2. QUICK ACTION CARDS (Demandes, Dispo, Messages, Revenus) ────────────
  Widget _buildQuickActionCards(BuildContext context) {
    return Row(
      children: [
        // 1. Demandes (with badge 2)
        Expanded(
          child: _buildActionCard(
            context: context,
            icon: Icons.assignment_outlined,
            iconColor: const Color(0xFF475569),
            label: 'pro_action_requests'.tr(),
            badgeCount: null,
            onTap: () => setState(() => _currentBottomNavIndex = 1),
          ),
        ),
        const SizedBox(width: 10),
        // 2. Dispo.
        Expanded(
          child: _buildActionCard(
            context: context,
            icon: Icons.calendar_month_rounded,
            iconColor: const Color(0xFF3B82F6),
            label: 'pro_action_availability'.tr(),
            onTap: () => setState(() => _currentBottomNavIndex = 5),
          ),
        ),
        const SizedBox(width: 10),
        // 3. Messages
        Expanded(
          child: _buildActionCard(
            context: context,
            icon: Icons.chat_bubble_outline_rounded,
            iconColor: const Color(0xFF8B5CF6),
            label: 'pro_action_messages'.tr(),
            onTap: () => setState(() => _currentBottomNavIndex = 2),
          ),
        ),
        const SizedBox(width: 10),
        // 4. Revenus
        Expanded(
          child: _buildActionCard(
            context: context,
            icon: Icons.savings_rounded,
            iconColor: const Color(0xFFF59E0B),
            label: 'pro_action_revenue'.tr(),
            onTap: () => setState(() => _currentBottomNavIndex = 3),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationSharingButton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final actionColor = _isSharingLocation
        ? const Color(0xFFCE4935)
        : const Color(0xFF0D7A72);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isLocationActionInProgress ? null : _toggleLocationSharing,
        icon: _isLocationActionInProgress
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                _isSharingLocation
                    ? Icons.location_off_rounded
                    : Icons.my_location_rounded,
              ),
        label: Text(
          _isLocationActionInProgress
              ? 'pro_location_loading'.tr()
              : _isSharingLocation
              ? 'pro_location_stop'.tr()
              : 'pro_share_location'.tr(),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: actionColor,
          backgroundColor: isDark
              ? const Color(0xFF142B35)
              : (_isSharingLocation ? const Color(0xFFFFF1EE) : Colors.white),
          side: BorderSide(
            color: isDark
                ? const Color(0xFF28535B)
                : (_isSharingLocation
                      ? const Color(0xFFF2B6AA)
                      : const Color(0xFFB8DCD7)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleLocationSharing() async {
    final wasSharing = _isSharingLocation;
    setState(() => _isLocationActionInProgress = true);
    final ok = wasSharing
        ? await FirebaseService().stopProfessionalLocationSharing()
        : await FirebaseService().updateProfessionalLocation();
    if (!mounted) return;
    setState(() {
      _isLocationActionInProgress = false;
      if (ok) _isSharingLocation = !wasSharing;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          !ok
              ? 'pro_location_failed'.tr()
              : (_isSharingLocation
                    ? 'pro_location_shared'.tr()
                    : 'pro_location_stopped'.tr()),
        ),
        backgroundColor: ok
            ? (_isSharingLocation
                  ? const Color(0xFF10B981)
                  : const Color(0xFF64748B))
            : const Color(0xFFEF4444),
      ),
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String label,
    int? badgeCount,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFEFE8DE);
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 78,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: iconColor, size: 24),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
            if (badgeCount != null && badgeCount > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 17,
                  height: 17,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE05D38),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$badgeCount',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── 3. NOTIFICATION BANNER (2 nouvelles demandes!) ────────────────────────
  Widget _buildNotificationBanner(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _bookingsStream,
      builder: (context, snapshot) {
        final pendingCount = (snapshot.data ?? const <Map<String, dynamic>>[])
            .where(_isPending)
            .length;
        if (pendingCount == 0) return const SizedBox.shrink();
        return GestureDetector(
          onTap: () => setState(() => _currentBottomNavIndex = 1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A1B14) : const Color(0xFFFEF2E8),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF7C2D12)
                    : const Color(0xFFFCDCC5),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF431407)
                        : const Color(0xFFFEE0CB),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    color: Color(0xFFEA580C),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$pendingCount ${pendingCount == 1 ? 'pro_new_request_banner'.tr() : 'pro_new_requests_banner'.tr()}',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE05D38),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'pro_respond_fast'.tr(),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? const Color(0xFFA8A29E)
                              : const Color(0xFF78716C),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFE05D38),
                  size: 20,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── 4. INTERVENTIONS D'AUJOURD'HUI ─────────────────────────────────────────
  Widget _buildInterventionsSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 16,
                  color: Color(0xFFE05D38),
                ),
                const SizedBox(width: 8),
                Text(
                  'pro_today_interventions_title'.tr(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: () => setState(() => _currentBottomNavIndex = 1),
              child: Text(
                'see_all'.tr(),
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE05D38),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _bookingsStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) return Text('pro_bookings_load_error'.tr());
            if (!snapshot.hasData)
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            final today = snapshot.data!
                .where(
                  (b) =>
                      _isSameDay(_bookingDate(b), DateTime.now()) &&
                      !_isCancelled(b),
                )
                .toList();
            if (today.isEmpty)
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(child: Text('pro_no_jobs_today'.tr())),
              );
            return Column(
              children: today
                  .map((b) => _buildBookingCard(context, b))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildInterventionCard(
    BuildContext context,
    Map<String, dynamic> item,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFEFE8DE);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return GestureDetector(
      onTap: () => _showInterventionDetails(context, item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Client Avatar
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                item['avatarAsset'],
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 52,
                  height: 52,
                  color: const Color(0xFFE2DDD5),
                  child: const Icon(Icons.person_rounded),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Client Name & Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['client'],
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded, size: 12),
                      const SizedBox(width: 3),
                      Text(
                        item['time'],
                        style: TextStyle(
                          fontSize: 12,
                          color: subColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '•',
                        style: TextStyle(
                          color: isDark
                              ? const Color(0xFF64748B)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.location_on_rounded, size: 12),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          item['location'],
                          style: TextStyle(fontSize: 12, color: subColor),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Status Pill & Price
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: item['statusBg'],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    item['status'],
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: item['statusColor'],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item['price'],
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE05D38),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── 5. PERFORMANCE CETTE SEMAINE (matching screenshot 2) ──────────────────
  Widget _buildPerformanceCard(List<Map<String, dynamic>> bookings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFEFE8DE);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.bar_chart_rounded,
                size: 18,
                color: Color(0xFFE05D38),
              ),
              const SizedBox(width: 8),
              Text(
                'pro_weekly_performance_title'.tr(),
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          SizedBox(
            height: 150,
            child: _WeeklyBookingsChart(bookings: bookings),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceBar({
    required String title,
    required String valueText,
    required Color valueColor,
    required double progress,
    required Color barColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final trackColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: TextStyle(fontSize: 13, color: subColor)),
            Text(
              valueText,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 7,
            backgroundColor: trackColor,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }

  // ─── 6. BOTTOM NAVIGATION BAR (matching screenshot) ────────────────────────
  Widget _buildBottomNavigationBar(Color orangeAccent) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: navBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentBottomNavIndex == 5 ? 4 : _currentBottomNavIndex,
        onTap: (index) {
          setState(() {
            _currentBottomNavIndex = index;
          });
          if (index == 0) _loadProPhoto();
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: navBg,
        selectedItemColor: orangeAccent,
        unselectedItemColor: isDark
            ? const Color(0xFF94A3B8)
            : const Color(0xFF64748B),
        selectedLabelStyle: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.grid_view_rounded),
            label: 'pro_tab_dashboard'.tr(),
          ),
          BottomNavigationBarItem(
            icon: StreamBuilder<List<Map<String, dynamic>>>(
              stream: FirebaseService().streamProBookings(
                statusFilter: 'en_attente',
              ),
              builder: (_, snap) {
                final count = snap.data?.length ?? 0;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.calendar_today_rounded),
                    if (count > 0)
                      Positioned(
                        top: -4,
                        right: -6,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Color(0xFFE05D38),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$count',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            label: 'pro_tab_requests'.tr(),
          ),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: _unreadMessages > 0,
              label: Text(
                _unreadMessages > 9 ? '9+' : '$_unreadMessages',
                style: const TextStyle(fontSize: 9, color: Colors.white),
              ),
              child: const Icon(Icons.chat_bubble_outline_rounded),
            ),
            label: 'pro_tab_messages'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.attach_money_rounded),
            label: 'pro_tab_revenue'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline_rounded),
            label: 'pro_tab_account'.tr(),
          ),
        ],
      ),
    );
  }

  // ─── 7. MODALS & DIALOGS ───────────────────────────────────────────────────
  void _showInterventionDetails(
    BuildContext context,
    Map<String, dynamic> item,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final innerBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFFAF7F2);
    final textColor = isDark ? Colors.white : AppTheme.titleColor;
    final subColor = isDark ? const Color(0xFF94A3B8) : AppTheme.subtitleColor;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2DDD5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        item['avatarAsset'],
                        width: 58,
                        height: 58,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['client'],
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item['service'],
                            style: TextStyle(fontSize: 13, color: subColor),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      item['price'],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE05D38),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: innerBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            size: 18,
                            color: Color(0xFF0F2D2A),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Scheduled time: Today at ${item['time']}',
                            style: TextStyle(color: textColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            size: 18,
                            color: Color(0xFFE05D38),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Adresse : ${item['location']}',
                            style: TextStyle(color: textColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.phone_rounded,
                            size: 18,
                            color: Color(0xFF10B981),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Phone: ${item['phone']}',
                            style: TextStyle(color: textColor),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          final clientId = (item['clientId'] ?? '')
                              .toString()
                              .trim();
                          Navigator.pop(context);
                          if (clientId.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('call_demo_only'.tr()),
                                backgroundColor: const Color(0xFF0F2D2A),
                              ),
                            );
                            return;
                          }
                          CallService.instance.startCall(
                            calleeId: clientId,
                            calleeName: (item['client'] ?? 'Client').toString(),
                          );
                        },
                        icon: const Icon(Icons.phone_in_talk_rounded, size: 18),
                        label: Text('pro_call_client'.tr()),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0F2D2A),
                          side: const BorderSide(color: Color(0xFF0F2D2A)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const MapScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.navigation_rounded, size: 18),
                        label: Text('pro_directions'.tr()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F2D2A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPendingRequestsSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final innerBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFFAF7F2);
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFEFE8DE);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2DDD5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                Text(
                  'pro_pending_sheet_title'.tr(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 14),
                ..._pendingRequests.map(
                  (req) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: innerBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.asset(
                                req['avatarAsset'],
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    req['client'],
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                  Text(
                                    '${req['time']} • ${req['location']}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: subColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              req['price'],
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFE05D38),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          req['service'],
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? const Color(0xFFCBD5E1)
                                : const Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  setState(() => _currentBottomNavIndex = 1);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'pro_manage_request_hint'.tr(),
                                      ),
                                      backgroundColor: Color(0xFF0F2D2A),
                                    ),
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: isDark
                                      ? const Color(0xFFCBD5E1)
                                      : Colors.grey.shade700,
                                  side: BorderSide(
                                    color: isDark
                                        ? const Color(0xFF475569)
                                        : Colors.grey.shade300,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text('pro_decline'.tr()),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  setState(() => _currentBottomNavIndex = 1);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'pro_manage_request_hint'.tr(),
                                      ),
                                      backgroundColor: Color(0xFF10B981),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F2D2A),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text('pro_accept'.tr()),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLanguageDialog(BuildContext context) {
    final currentCode = context.locale.languageCode;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget buildLangTile(BuildContext ctx, String code, String name) {
      final isSelected = currentCode == code;
      return InkWell(
        onTap: () async {
          final newLoc = Locale(code);
          await context.setLocale(newLoc);
          if (context.mounted) {
            try {
              context.read<LocaleProvider>().setLocale(newLoc);
            } catch (_) {}
          }
          if (ctx.mounted) Navigator.pop(ctx);
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF0F2D2A) : const Color(0xFFE8F5F3))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? const Color(0xFF1B413E) : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF1B413E),
                  size: 20,
                ),
            ],
          ),
        ),
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('choose_language'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildLangTile(ctx, 'fr', 'Français'),
            buildLangTile(ctx, 'en', 'English'),
            buildLangTile(ctx, 'ar', 'العربية'),
          ],
        ),
      ),
    );
  }

  void _showThemeDialog(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('theme_choose'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThemeOptionTile(
              ctx: ctx,
              provider: themeProvider,
              mode: ThemeMode.system,
              icon: Icons.brightness_auto_rounded,
              iconColor: const Color(0xFF64748B),
              title: 'theme_system'.tr(),
              subtitle: 'theme_subtitle_system'.tr(),
              isDark: isDark,
            ),
            _buildThemeOptionTile(
              ctx: ctx,
              provider: themeProvider,
              mode: ThemeMode.light,
              icon: Icons.light_mode_rounded,
              iconColor: const Color(0xFFE05D38),
              title: 'theme_light'.tr(),
              isDark: isDark,
            ),
            _buildThemeOptionTile(
              ctx: ctx,
              provider: themeProvider,
              mode: ThemeMode.dark,
              icon: Icons.dark_mode_rounded,
              iconColor: const Color(0xFF6366F1),
              title: 'theme_dark'.tr(),
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOptionTile({
    required BuildContext ctx,
    required ThemeProvider provider,
    required ThemeMode mode,
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required bool isDark,
  }) {
    final isSelected = provider.themeMode == mode;

    return InkWell(
      onTap: () {
        provider.setThemeMode(mode);
        Navigator.pop(ctx);
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF0F2D2A) : const Color(0xFFE8F5F3))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFF1B413E) : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w600,
                      fontSize: 14,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  if (subtitle != null && subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF1B413E),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  void _showNotificationsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(
              Icons.notifications_active_rounded,
              color: Color(0xFFE05D38),
            ),
            const SizedBox(width: 8),
            Text('pro_notif_title'.tr()),
          ],
        ),
        content: SizedBox(
          width: 380,
          height: 360,
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: FirebaseService().streamClientNotifications(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Erreur : ${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final notifications = [...snapshot.data!]
                ..sort((a, b) {
                  final aDate = a['createdAt'];
                  final bDate = b['createdAt'];
                  final aTime = aDate is Timestamp
                      ? aDate.millisecondsSinceEpoch
                      : 0;
                  final bTime = bDate is Timestamp
                      ? bDate.millisecondsSinceEpoch
                      : 0;
                  return bTime.compareTo(aTime);
                });
              if (notifications.isEmpty) {
                return Center(child: Text('pro_no_notifications'.tr()));
              }
              return ListView.separated(
                itemCount: notifications.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  final isRead = notification['isRead'] == true;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      notification['type'] == 'payment_received'
                          ? Icons.payments_rounded
                          : notification['type'] == 'booking_review_received'
                          ? Icons.star_rounded
                          : Icons.notifications_rounded,
                      color: isRead ? Colors.grey : const Color(0xFFE05D38),
                    ),
                    title: Text(
                      notification['title']?.toString() ?? 'Notification',
                      style: TextStyle(
                        fontWeight: isRead
                            ? FontWeight.normal
                            : FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(notification['body']?.toString() ?? ''),
                    trailing: Text(notification['timeLabel']?.toString() ?? ''),
                    onTap: isRead
                        ? null
                        : () => FirebaseService().markNotificationRead(
                            notification['id']?.toString() ?? '',
                          ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'pro_close'.tr(),
              style: const TextStyle(color: Color(0xFF0F2D2A)),
            ),
          ),
        ],
      ),
    );
  }

  void _showSettingsModal(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final iconColor = isDark
        ? const Color(0xFF10B981)
        : const Color(0xFF0F2D2A);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2DDD5),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              ListTile(
                leading: Icon(Icons.person_outline_rounded, color: iconColor),
                title: Text(
                  'pro_settings_edit_profile'.tr(),
                  style: TextStyle(color: textColor),
                ),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: Icon(
                  _isSharingLocation
                      ? Icons.location_off_rounded
                      : Icons.my_location_rounded,
                  color: iconColor,
                ),
                title: Text(
                  _isSharingLocation
                      ? 'pro_location_stop'.tr()
                      : 'pro_share_location'.tr(),
                  style: TextStyle(color: textColor),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _toggleLocationSharing();
                },
              ),
              ListTile(
                leading: Icon(Icons.handyman_outlined, color: iconColor),
                title: Text(
                  'pro_services_title'.tr(),
                  style: TextStyle(color: textColor),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ProServicesScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.attach_money_rounded, color: iconColor),
                title: Text(
                  'pro_settings_rates'.tr(),
                  style: TextStyle(color: textColor),
                ),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: Icon(Icons.language_rounded, color: iconColor),
                title: Text(
                  'language'.tr(),
                  style: TextStyle(color: textColor),
                ),
                trailing: Text(
                  context.locale.languageCode == 'fr'
                      ? 'Français'
                      : (context.locale.languageCode == 'en'
                            ? 'English'
                            : 'العربية'),
                  style: const TextStyle(
                    color: Color(0xFFE05D38),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showLanguageDialog(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.brightness_6_rounded, color: iconColor),
                title: Text(
                  'theme_mode'.tr(),
                  style: TextStyle(color: textColor),
                ),
                trailing: Builder(
                  builder: (ctx) {
                    final themeMode = Provider.of<ThemeProvider>(ctx).themeMode;
                    final text = themeMode == ThemeMode.system
                        ? 'theme_system'.tr()
                        : (themeMode == ThemeMode.light
                              ? 'theme_light'.tr()
                              : 'theme_dark'.tr());
                    return Text(
                      text,
                      style: const TextStyle(
                        color: Color(0xFFE05D38),
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showThemeDialog(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.lock_reset_rounded, color: iconColor),
                title: Text(
                  'security_and_password'.tr(),
                  style: TextStyle(color: textColor),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showChangePasswordDialog();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.logout_rounded,
                  color: Colors.redAccent,
                ),
                title: Text(
                  'pro_logout'.tr(),
                  style: const TextStyle(color: Colors.redAccent),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDarkDialog = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.lock_reset_rounded,
                  color: isDarkDialog
                      ? const Color(0xFF5EEAD4)
                      : const Color(0xFF0F2D2A),
                  size: 24,
                ),
                SizedBox(width: 10),
                Text(
                  'profile_security_title'.tr(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.titleColorOf(context),
                  ),
                ),
              ],
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'profile_password_description'.tr(),
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.subtitleColorOf(context),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isDarkDialog
                              ? const Color(0xFF4C1D24)
                              : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              color: isDarkDialog
                                  ? const Color(0xFFFCA5A5)
                                  : const Color(0xFFDC2626),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDarkDialog
                                      ? const Color(0xFFFCA5A5)
                                      : const Color(0xFFDC2626),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    TextFormField(
                      controller: currentPassCtrl,
                      obscureText: obscureCurrent,
                      decoration: InputDecoration(
                        labelText: 'profile_current_password'.tr(),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureCurrent
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () => setDialogState(
                            () => obscureCurrent = !obscureCurrent,
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'profile_current_password_required'.tr()
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: newPassCtrl,
                      obscureText: obscureNew,
                      decoration: InputDecoration(
                        labelText: 'profile_new_password'.tr(),
                        prefixIcon: const Icon(Icons.key_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureNew
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () =>
                              setDialogState(() => obscureNew = !obscureNew),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty)
                          return 'profile_new_password_required'.tr();
                        if (v.trim().length < 6)
                          return 'password_min_length'.tr();
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: confirmPassCtrl,
                      obscureText: obscureConfirm,
                      decoration: InputDecoration(
                        labelText: 'profile_confirm_password'.tr(),
                        prefixIcon: const Icon(Icons.key_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureConfirm
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () => setDialogState(
                            () => obscureConfirm = !obscureConfirm,
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      validator: (v) {
                        if (v != newPassCtrl.text)
                          return 'passwords_do_not_match'.tr();
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: Text(
                  'cancel'.tr(),
                  style: TextStyle(color: AppTheme.subtitleColorOf(context)),
                ),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() {
                          isSaving = true;
                          errorMessage = null;
                        });

                        final messenger = ScaffoldMessenger.of(context);
                        final result = await FirebaseService().changePassword(
                          currentPassword: currentPassCtrl.text.trim(),
                          newPassword: newPassCtrl.text.trim(),
                        );

                        if (result['success'] == true) {
                          if (ctx.mounted) Navigator.pop(ctx);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                localizePasswordChangeMessage(
                                  result['message'] as String?,
                                ),
                              ),
                              backgroundColor: const Color(0xFF0F2D2A),
                            ),
                          );
                        } else {
                          setDialogState(() {
                            isSaving = false;
                            errorMessage = localizePasswordChangeMessage(
                              result['message'] as String?,
                            );
                          });
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F2D2A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text('update'.tr()),
              ),
            ],
          );
        },
      ),
    );
  }
}
