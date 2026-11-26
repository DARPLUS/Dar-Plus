import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';

import '../theme/app_theme.dart';

import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import '../providers/locale_provider.dart';
import '../core/localization/app_localizations.dart';
import '../services/call_service.dart';
import '../services/firebase_service.dart';
import '../widgets/pro_avatar_widget.dart';

class ServiceDetailScreen extends StatefulWidget {
  final Map<String, dynamic> proData;
  final bool openBookingOnArrival;

  const ServiceDetailScreen({
    super.key,
    required this.proData,
    this.openBookingOnArrival = false,
  });

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  bool _isFav = false;

  @override
  void initState() {
    super.initState();
    final proId =
        (widget.proData['id'] ??
                widget.proData['uid'] ??
                'pro_${widget.proData['name']}')
            .toString();
    FirebaseService().isFavorite(proId).then((val) {
      if (mounted) setState(() => _isFav = val);
    });
    if (widget.openBookingOnArrival &&
        widget.proData['hasStoredPrice'] != false) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showBookingSheet(
          context,
          widget.proData['name']?.toString() ?? 'Artisan Professionnel',
          widget.proData['serviceType']?.toString() ?? 'Service',
          widget.proData['price']?.toString() ?? '35 TND/h',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final proData = widget.proData;
    context.watch<ThemeProvider>();
    context.watch<LocaleProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    final proId = proData['id'] ?? 'pro_${proData['name']}';
    final name = proData['name'] ?? 'Artisan Professionnel';
    final serviceType = proData['serviceType'] ?? 'Service';
    final hasStoredPrice = proData['hasStoredPrice'] != false;
    final price = hasStoredPrice
        ? (proData['price'] ?? '35 TND/h').toString()
        : loc.translate('ai_price_unknown');
    final storedRating = proData['hasStoredRating'] == false
        ? null
        : proData['rating'];
    final storedReviewsCount = proData['hasStoredReviewCount'] == false
        ? null
        : proData['reviewsCount'];
    final location = proData['hasStoredLocation'] == false
        ? loc.translate('ai_location_unknown')
        : proData['location'] ?? 'Grand Tunis';
    final distance = proData['hasStoredDistance'] == false
        ? null
        : proData['distance'] ?? '2.0 km';
    final bio = proData['hasStoredBio'] == false
        ? loc.translate('ai_bio_unknown')
        : proData['bio'] ??
              'Professionnel qualifié et vérifié par DAR PLUS pour toutes vos interventions à domicile.';
    final specialties = proData['hasStoredSpecialties'] == false
        ? const <dynamic>[]
        : (proData['specialties'] as List<dynamic>?) ??
              [serviceType, 'Intervention rapide', 'Devis gratuit'];
    final badges = (proData['badges'] as List<dynamic>?) ?? ['Vérifié DAR+'];
    final hasAvailability = proData['hasStoredAvailability'] != false;
    final isAvailable = proData['available'] == true;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // 1. Sliver App Bar with Hero Image
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: const Color(0xFF0D544E),
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.black38,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black38,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isFav
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: _isFav ? const Color(0xFFEF4444) : Colors.white,
                    size: 20,
                  ),
                ),
                onPressed: () async {
                  final newStatus = await FirebaseService().toggleFavorite(
                    widget.proData,
                  );
                  if (!mounted) return;
                  setState(() => _isFav = newStatus);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        newStatus
                            ? '$name ajouté à vos favoris !'
                            : '$name retiré de vos favoris.',
                      ),
                      backgroundColor: newStatus
                          ? const Color(0xFF10B981)
                          : Colors.grey.shade700,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'pro_avatar_$proId',
                    child: SizedBox(
                      width: double.infinity,
                      height: double.infinity,
                      child: ProAvatarWidget(
                        name: name,
                        photoBase64: proData['photoBase64'] as String? ?? '',
                        photoUrl: proData['photoUrl'] as String? ?? '',
                        avatarAsset: proData['avatarAsset'] as String? ?? '',
                        size: 280,
                        borderRadius: 0,
                        showVerifiedBadge: false,
                        fill: true,
                      ),
                    ),
                  ),
                  // Gradient overlay
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.5, 1.0],
                        colors: [
                          Colors.black.withValues(alpha: 0.4),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.8),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    bottom: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D544E),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                serviceType,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: !hasAvailability
                                    ? Colors.grey.shade600
                                    : isAvailable
                                    ? const Color(0xFF10B981)
                                    : Colors.grey.shade600,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                !hasAvailability
                                    ? loc.translate('ai_availability_unknown')
                                    : (isAvailable
                                          ? loc.translate('available')
                                          : loc.translate('unavailable')),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              color: Colors.white70,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              distance == null
                                  ? location.toString()
                                  : '$location • à $distance',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Main Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Rating & Price Summary Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark
                            ? Colors.transparent
                            : const Color(0xFFEDE8E1),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.2 : 0.04,
                          ),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: StreamBuilder<Map<String, dynamic>>(
                      stream: FirebaseService().streamRatingSummary(
                        proId.toString(),
                      ),
                      builder: (context, snapshot) {
                        final summary =
                            snapshot.data ?? const <String, dynamic>{};
                        final count = summary['reviewsCount'] is num
                            ? (summary['reviewsCount'] as num).toInt()
                            : (storedReviewsCount is num
                                  ? storedReviewsCount.toInt()
                                  : 0);
                        final value = summary['rating'] is num
                            ? (summary['rating'] as num).toDouble()
                            : (storedRating is num
                                  ? storedRating.toDouble()
                                  : null);
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem(
                              'Note globale',
                              value == null
                                  ? '—'
                                  : '${value.toStringAsFixed(1)} ★',
                              Colors.amber,
                            ),
                            _buildVerticalDivider(isDark),
                            _buildStatItem(
                              'Avis clients',
                              '$count',
                              Colors.blue,
                            ),
                            _buildVerticalDivider(isDark),
                            _buildStatItem(
                              'Tarif horaire',
                              price,
                              const Color(0xFFDE6D1B),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Badges
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: badges.map((badge) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF0D544E).withValues(alpha: 0.25)
                              : const Color(0xFFD7F3EA),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF0D544E)
                                .withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.verified_rounded,
                              size: 16,
                              color: Color(0xFF0D544E),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$badge',
                              style: const TextStyle(
                                color: Color(0xFF0D544E),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),

                  // À propos
                  Text(
                    'service_about_pro'.tr(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppTheme.titleColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    bio,
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.5,
                      color: isDark
                          ? Colors.grey.shade300
                          : AppTheme.subtitleColor,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Prestations & Spécialités
                  Text(
                    'service_skills_title'.tr(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppTheme.titleColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...specialties.map((spec) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFF0D544E),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '$spec',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white
                                  : AppTheme.titleColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 24),

                  // Avis Clients récents
                  Text(
                    'client_reviews'.tr(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppTheme.titleColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Avis Clients réels depuis Firestore
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: FirebaseService().streamReviews(proId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF0D544E),
                          ),
                        );
                      }
                      final reviews = snapshot.data ?? [];
                      if (reviews.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark
                                  ? Colors.transparent
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.rate_review_outlined,
                                color: Colors.grey.shade400,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'chat_profile_no_reviews'.tr(),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return Column(
                        children: reviews.map((review) {
                          final author =
                              review['clientName'] as String? ?? 'Client';
                          final date = review['dateLabel'] as String? ?? '';
                          final rating = (review['rating'] is num)
                              ? (review['rating'] as num).toDouble()
                              : 5.0;
                          final comment = review['comment'] as String? ?? '';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _buildReviewCard(
                              author: author,
                              date: date,
                              rating: rating,
                              comment: comment,
                              isDark: isDark,
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),

                  const SizedBox(height: 100), // Spacing for bottom button
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              // Call Button
              OutlinedButton.icon(
                onPressed: proId.toString().isEmpty
                    ? null
                    : () => CallService.instance.startCall(
                        calleeId: proId.toString(),
                        calleeName: name.toString(),
                        serviceType: serviceType.toString(),
                      ),
                icon: const Icon(Icons.phone_in_talk_rounded, size: 20),
                label: Text(loc.translate('call')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0D544E),
                  side: const BorderSide(color: Color(0xFF0D544E), width: 1.5),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Book Now Button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: hasStoredPrice
                      ? () {
                          _showBookingSheet(context, name, serviceType, price);
                        }
                      : null,
                  icon: const Icon(Icons.calendar_month_rounded, size: 20),
                  label: Text(
                    hasStoredPrice
                        ? loc.translate('book_now')
                        : loc.translate('ai_price_unknown'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D544E),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildVerticalDivider(bool isDark) {
    return Container(
      height: 30,
      width: 1,
      color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
    );
  }

  Widget _buildReviewCard({
    required String author,
    required String date,
    required double rating,
    required String comment,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.transparent : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                author,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isDark ? Colors.white : AppTheme.titleColor,
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                  const SizedBox(width: 2),
                  Text(
                    '$rating',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            date,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 8),
          Text(
            comment,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey.shade300 : AppTheme.subtitleColor,
            ),
          ),
        ],
      ),
    );
  }

  void _showBookingSheet(
    BuildContext context,
    String proName,
    String serviceType,
    String price,
  ) {
    final addressCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final bookingFormKey = GlobalKey<FormState>();
    // Date/heure : sélection par jour glissant + créneaux
    DateTime selectedDay = DateTime.now();
    String selectedTime = '';
    final proId =
        (widget.proData['id'] ??
                widget.proData['uid'] ??
                'pro_${widget.proData['name']}')
            .toString();
    final reservedSlotIds = <String>{};
    final blockedSlotIds = <String>{};
    var availableSlotTimes = <String>[];
    var availabilityLoaded = false;

    // 14 jours dès aujourd'hui
    final List<DateTime> days = List.generate(
      14,
      (i) => DateTime.now().add(Duration(days: i)),
    );

    String dateKey(DateTime date) =>
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    bool isPastSlot(DateTime day, String slot) {
      final parts = slot.split(':');
      final candidate = DateTime(
        day.year,
        day.month,
        day.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
      return candidate.isBefore(DateTime.now());
    }

    bool isLocating = false;
    bool isSubmitting = false;
    double? clientLatitude;
    double? clientLongitude;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    final List<String> shortDays = [
      'Lun',
      'Mar',
      'Mer',
      'Jeu',
      'Ven',
      'Sam',
      'Dim',
    ];

    String buildScheduledDate() {
      final months = [
        'jan',
        'fév',
        'mar',
        'avr',
        'mai',
        'jun',
        'jul',
        'aoû',
        'sep',
        'oct',
        'nov',
        'déc',
      ];
      final label =
          '${shortDays[selectedDay.weekday - 1]} ${selectedDay.day} ${months[selectedDay.month - 1]}';
      if (selectedTime.isNotEmpty) return '$label · $selectedTime';
      return label;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 24,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Form(
                key: bookingFormKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── En-tête ──────────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${loc.translate("book_service")} — $serviceType',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : AppTheme.titleColor,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '$proName  •  $price',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? const Color(0xFF94A3B8)
                                        : AppTheme.subtitleColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: isSubmitting
                                ? null
                                : () => Navigator.pop(ctx),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),
                      StreamBuilder<Map<String, dynamic>>(
                        stream: FirebaseService().streamRatingSummary(proId),
                        builder: (context, snapshot) {
                          final summary =
                              snapshot.data ?? const <String, dynamic>{};
                          final score = summary['rating'] is num
                              ? summary['rating']
                              : widget.proData['rating'];
                          final reviews = summary['reviewsCount'] is num
                              ? (summary['reviewsCount'] as num).toInt()
                              : (widget.proData['reviewsCount'] is num
                                    ? (widget.proData['reviewsCount'] as num)
                                          .toInt()
                                    : 0);
                          return Row(
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                size: 16,
                                color: Color(0xFFF59E0B),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                score is num
                                    ? '${score.toStringAsFixed(1)}/5'
                                    : 'Pas encore noté',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? const Color(0xFFFBBF24)
                                      : const Color(0xFF92400E),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'reviews_count'.tr(
                                  namedArgs: {'count': '$reviews'},
                                ),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : AppTheme.subtitleColor,
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 20),

                      // ── Choisir le jour ──────────────────────────────
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'booking_choose_day'.tr(),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : AppTheme.titleColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 76,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: days.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (_, i) {
                            final day = days[i];
                            final isSelected =
                                day.year == selectedDay.year &&
                                day.month == selectedDay.month &&
                                day.day == selectedDay.day;
                            final dayNames = [
                              'Lun',
                              'Mar',
                              'Mer',
                              'Jeu',
                              'Ven',
                              'Sam',
                              'Dim',
                            ];
                            final dayName = dayNames[day.weekday - 1];
                            return GestureDetector(
                              onTap: () => setModalState(() {
                                selectedDay = day;
                                selectedTime = '';
                              }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 56,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF0D544E)
                                      : (isDark
                                            ? const Color(0xFF1E293B)
                                            : Colors.white),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF0D544E)
                                        : (isDark
                                              ? const Color(0xFF334155)
                                              : const Color(0xFFE2E8F0)),
                                  ),
                                  boxShadow: isSelected
                                      ? []
                                      : [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.03,
                                            ),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      dayName,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: isSelected
                                            ? Colors.white.withValues(
                                                alpha: 0.85,
                                              )
                                            : (isDark
                                                  ? const Color(0xFF94A3B8)
                                                  : const Color(0xFF64748B)),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${day.day}',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? Colors.white
                                            : (isDark
                                                  ? Colors.white
                                                  : AppTheme.titleColor),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── Choisir l'heure ──────────────────────────────
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'booking_choose_time'.tr(),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : AppTheme.titleColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      StreamBuilder<Map<String, dynamic>>(
                        stream: FirebaseService().streamProAvailabilitySettings(
                          proId,
                        ),
                        builder: (context, settingsSnapshot) =>
                            StreamBuilder<List<Map<String, dynamic>>>(
                              stream: FirebaseService().streamProReservedSlots(
                                proId,
                              ),
                              builder: (context, slotsSnapshot) {
                                availabilityLoaded =
                                    settingsSnapshot.hasData &&
                                    slotsSnapshot.hasData;
                                reservedSlotIds
                                  ..clear()
                                  ..addAll(
                                    (slotsSnapshot.data ?? const []).map(
                                      (slot) =>
                                          '${slot['dateKey']}_${(slot['time']?.toString() ?? '').replaceAll(':', '')}',
                                    ),
                                  );
                                final settings =
                                    settingsSnapshot.data ??
                                    const <String, dynamic>{};
                                final int startHour =
                                    (((settings['workStartMinutes'] as num?)
                                                    ?.toInt() ??
                                                540) ~/
                                            60)
                                        .clamp(0, 22)
                                        .toInt();
                                final int endHour =
                                    (((settings['workEndMinutes'] as num?)
                                                    ?.toInt() ??
                                                1020) ~/
                                            60)
                                        .clamp(startHour + 1, 23)
                                        .toInt();
                                blockedSlotIds
                                  ..clear()
                                  ..addAll(
                                    (settings['unavailableSlots'] as List? ??
                                            const [])
                                        .map((value) => value.toString()),
                                  );
                                availableSlotTimes = [
                                  for (
                                    var hour = startHour;
                                    hour <= endHour;
                                    hour++
                                  )
                                    '${hour.toString().padLeft(2, '0')}:00',
                                ];
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    GridView.count(
                                      crossAxisCount: 4,
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      crossAxisSpacing: 8,
                                      mainAxisSpacing: 8,
                                      childAspectRatio: 2.2,
                                      children: availableSlotTimes.map((slot) {
                                        final slotId =
                                            '${dateKey(selectedDay)}_${slot.replaceAll(':', '')}';
                                        final blockedId =
                                            '${dateKey(selectedDay)}_$slot';
                                        final isUnavailable =
                                            !availabilityLoaded ||
                                            reservedSlotIds.contains(slotId) ||
                                            blockedSlotIds.contains(
                                              blockedId,
                                            ) ||
                                            isPastSlot(selectedDay, slot);
                                        final isSelected =
                                            selectedTime == slot &&
                                            !isUnavailable;
                                        const unavailableColor = Color(
                                          0xFFDC2626,
                                        );
                                        return GestureDetector(
                                          onTap: isUnavailable
                                              ? null
                                              : () => setModalState(
                                                  () => selectedTime = slot,
                                                ),
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 180,
                                            ),
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? const Color(0xFF0D544E)
                                                  : isUnavailable
                                                  ? unavailableColor.withValues(
                                                      alpha: 0.10,
                                                    )
                                                  : (isDark
                                                        ? const Color(
                                                            0xFF1E293B,
                                                          )
                                                        : Colors.white),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: isSelected
                                                    ? const Color(0xFF0D544E)
                                                    : isUnavailable
                                                    ? unavailableColor
                                                    : (isDark
                                                          ? const Color(
                                                              0xFF334155,
                                                            )
                                                          : const Color(
                                                              0xFFE2E8F0,
                                                            )),
                                              ),
                                            ),
                                            child: Text(
                                              slot,
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                fontWeight:
                                                    isSelected || isUnavailable
                                                    ? FontWeight.bold
                                                    : FontWeight.w500,
                                                color: isSelected
                                                    ? Colors.white
                                                    : isUnavailable
                                                    ? unavailableColor
                                                    : (isDark
                                                          ? Colors.white
                                                          : AppTheme
                                                                .titleColor),
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      slotsSnapshot.hasError ||
                                              settingsSnapshot.hasError
                                          ? 'Impossible de charger les disponibilités.'
                                          : availabilityLoaded
                                          ? 'Rouge : indisponible ou déjà réservé'
                                          : 'Chargement des disponibilités…',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: availabilityLoaded
                                            ? const Color(0xFFDC2626)
                                            : AppTheme.subtitleColorOf(context),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                      ),

                      const SizedBox(height: 16),

                      // ── Adresse ──────────────────────────────────────
                      TextFormField(
                        controller: addressCtrl,
                        onChanged: (_) {
                          clientLatitude = null;
                          clientLongitude = null;
                        },
                        validator: (value) => (value ?? '').trim().length < 10
                            ? loc.translate('address_too_short')
                            : null,
                        decoration: InputDecoration(
                          labelText: loc.translate('intervention_address'),
                          hintText: loc.translate('address_hint'),
                          prefixIcon: const Icon(
                            Icons.home_work_rounded,
                            color: Color(0xFF0D544E),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          suffixIcon: isLocating
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF0D544E),
                                    ),
                                  ),
                                )
                              : IconButton(
                                  tooltip: 'Utiliser ma localisation',
                                  icon: const Icon(
                                    Icons.my_location_rounded,
                                    color: Color(0xFF0D544E),
                                  ),
                                  onPressed: () async {
                                    setModalState(() => isLocating = true);
                                    try {
                                      String detected = '';

                                      // ── Demande de permission ──────────────
                                      bool serviceEnabled =
                                          await Geolocator.isLocationServiceEnabled();
                                      if (!serviceEnabled) {
                                        if (modalContext.mounted) {
                                          ScaffoldMessenger.of(modalContext)
                                              .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'location_service_disabled'
                                                        .tr(),
                                                  ),
                                                  backgroundColor: Color(
                                                    0xFFD97706,
                                                  ),
                                                ),
                                              );
                                        }
                                        setModalState(() => isLocating = false);
                                        return;
                                      }

                                      LocationPermission permission =
                                          await Geolocator.checkPermission();
                                      if (permission ==
                                          LocationPermission.denied) {
                                        permission =
                                            await Geolocator.requestPermission();
                                      }
                                      if (permission ==
                                          LocationPermission.deniedForever) {
                                        if (modalContext.mounted) {
                                          ScaffoldMessenger.of(modalContext)
                                              .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'location_permission_denied'
                                                        .tr(),
                                                  ),
                                                  backgroundColor: Color(
                                                    0xFFDC2626,
                                                  ),
                                                ),
                                              );
                                        }
                                        setModalState(() => isLocating = false);
                                        return;
                                      }

                                      // ── Obtenir la position GPS ────────────
                                      final pos =
                                          await Geolocator.getCurrentPosition(
                                            locationSettings:
                                                const LocationSettings(
                                                  accuracy:
                                                      LocationAccuracy.high,
                                                  timeLimit: Duration(
                                                    seconds: 15,
                                                  ),
                                                ),
                                          );
                                      clientLatitude = pos.latitude;
                                      clientLongitude = pos.longitude;

                                      // ── Reverse geocoding ──────────────────
                                      if (kIsWeb) {
                                        // Web : Nominatim OpenStreetMap (pas de clé API)
                                        try {
                                          final uri = Uri.parse(
                                            'https://nominatim.openstreetmap.org/reverse'
                                            '?lat=${pos.latitude}&lon=${pos.longitude}'
                                            '&format=json&accept-language=fr',
                                          );
                                          final resp = await http.get(
                                            uri,
                                            headers: {
                                              'User-Agent': 'DarPlus/1.0 (contact@darplus.tn)',
                                            },
                                          );
                                          if (resp.statusCode == 200) {
                                            final data = jsonDecode(
                                              resp.body,
                                            ) as Map<String, dynamic>;
                                            final address =
                                                data['address']
                                                    as Map<String, dynamic>?;
                                            if (address != null) {
                                              final parts = <String>[
                                                if (address['road'] != null)
                                                  address['road'] as String,
                                                if (address['suburb'] != null)
                                                  address['suburb'] as String,
                                                if (address['city'] != null)
                                                  address['city'] as String
                                                else if (address['town'] !=
                                                    null)
                                                  address['town'] as String
                                                else if (address['village'] !=
                                                    null)
                                                  address['village'] as String,
                                              ].where((s) => s.isNotEmpty).toList();
                                              detected = parts.join(', ');
                                            }
                                          }
                                        } catch (_) {}
                                      } else {
                                        // Mobile : geocoding package (natif Android/iOS)
                                        try {
                                          final placemarks =
                                              await placemarkFromCoordinates(
                                                pos.latitude,
                                                pos.longitude,
                                              );
                                          if (placemarks.isNotEmpty) {
                                            final p = placemarks.first;
                                            final parts = [
                                              if (p.street != null &&
                                                  p.street!.isNotEmpty)
                                                p.street!,
                                              if (p.subLocality != null &&
                                                  p.subLocality!.isNotEmpty)
                                                p.subLocality!,
                                              if (p.locality != null &&
                                                  p.locality!.isNotEmpty)
                                                p.locality!,
                                            ];
                                            detected = parts.join(', ');
                                          }
                                        } catch (_) {}
                                      }

                                      // Fallback : coordonnées brutes
                                      if (detected.isEmpty) {
                                        detected =
                                            '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
                                      }

                                      setModalState(() {
                                        addressCtrl.text = detected;
                                        isLocating = false;
                                      });
                                    } catch (e) {
                                      setModalState(() => isLocating = false);
                                      if (modalContext.mounted) {
                                        ScaffoldMessenger.of(modalContext)
                                            .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'location_fetch_error'.tr(
                                                    namedArgs: {
                                                      'error': e.toString(),
                                                    },
                                                  ),
                                                ),
                                                backgroundColor: const Color(
                                                  0xFFDC2626,
                                                ),
                                              ),
                                            );
                                      }
                                    }
                                  },
                                ),
                        ),
                      ),

                      if (clientLatitude != null &&
                          clientLongitude != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 14,
                              color: Color(0xFF10B981),
                            ),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'booking_location_shared_notice'.tr(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 14),

                      // ── Description ──────────────────────────────────
                      TextFormField(
                        controller: descCtrl,
                        maxLines: 2,
                        maxLength: 500,
                        validator: (value) => (value ?? '').trim().length > 500
                            ? loc.translate('booking_description_too_long')
                            : null,
                        decoration: InputDecoration(
                          labelText: loc.translate('need_description'),
                          hintText: loc.translate('description_hint'),
                          prefixIcon: const Icon(
                            Icons.description_rounded,
                            color: Color(0xFF0D544E),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── Bouton confirmer ─────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle_outline_rounded),
                          label: isSubmitting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Text(
                                  loc.translate('confirm_booking'),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D544E),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  if (!(bookingFormKey.currentState
                                          ?.validate() ??
                                      false)) {
                                    return;
                                  }
                                  final address = addressCtrl.text.trim();
                                  if (selectedTime.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'booking_choose_slot_error'.tr(),
                                        ),
                                        backgroundColor: Color(0xFFD97706),
                                      ),
                                    );
                                    return;
                                  }
                                  if (!availabilityLoaded ||
                                      !availableSlotTimes.contains(
                                        selectedTime,
                                      ) ||
                                      reservedSlotIds.contains(
                                        '${dateKey(selectedDay)}_${selectedTime.replaceAll(':', '')}',
                                      ) ||
                                      blockedSlotIds.contains(
                                        '${dateKey(selectedDay)}_$selectedTime',
                                      ) ||
                                      isPastSlot(selectedDay, selectedTime)) {
                                    setModalState(() => selectedTime = '');
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'booking_slot_unavailable'.tr(),
                                        ),
                                        backgroundColor: Color(0xFFDC2626),
                                      ),
                                    );
                                    return;
                                  }

                                  // ── Récapitulatif ────────────────────
                                  final scheduledDate = buildScheduledDate();
                                  final confirmed = await showDialog<bool>(
                                    context: modalContext,
                                    builder: (dCtx) => AlertDialog(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      title: Row(
                                        children: [
                                          const Icon(
                                            Icons.receipt_long_rounded,
                                            color: Color(0xFF0D544E),
                                            size: 22,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            loc.translate('booking_recap'),
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _RecapRow(
                                            icon: Icons.person_rounded,
                                            label: loc.translate('booking_pro'),
                                            value: proName,
                                          ),
                                          _RecapRow(
                                            icon: Icons.build_rounded,
                                            label: 'Service',
                                            value: serviceType,
                                          ),
                                          _RecapRow(
                                            icon: Icons.schedule_rounded,
                                            label: loc.translate(
                                              'booking_date',
                                            ),
                                            value: scheduledDate,
                                          ),
                                          _RecapRow(
                                            icon: Icons.location_on_rounded,
                                            label: loc.translate(
                                              'booking_address',
                                            ),
                                            value: address,
                                          ),
                                          _RecapRow(
                                            icon: Icons.payments_rounded,
                                            label: 'Tarif',
                                            value: price,
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(dCtx, false),
                                          child: Text(
                                            'edit'.tr(),
                                            style: TextStyle(
                                              color: AppTheme.subtitleColorOf(
                                                context,
                                              ),
                                            ),
                                          ),
                                        ),
                                        ElevatedButton(
                                          onPressed: () =>
                                              Navigator.pop(dCtx, true),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFF0D544E,
                                            ),
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: Text(loc.translate('confirm')),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirmed != true) return;
                                  if (!modalContext.mounted) return;

                                  setModalState(() => isSubmitting = true);

                                  final proId =
                                      widget.proData['id'] ??
                                      widget.proData['uid'] ??
                                      'pro_${widget.proData['name']}';
                                  final proPhone =
                                      widget.proData['phone'] ?? '';

                                  final res = await FirebaseService()
                                      .createBooking(
                                        proId: proId.toString(),
                                        proName: proName,
                                        proPhone: proPhone.toString(),
                                        proPhotoBase64:
                                            widget.proData['photoBase64']
                                                ?.toString() ??
                                            '',
                                        proPhotoUrl:
                                            widget.proData['photoUrl']
                                                ?.toString() ??
                                            '',
                                        proLocation:
                                            widget.proData['location']
                                                ?.toString() ??
                                            '',
                                        proBio:
                                            widget.proData['bio']?.toString() ??
                                            '',
                                        proExperienceYears:
                                            widget.proData['experienceYears']
                                                is num
                                            ? (widget.proData['experienceYears']
                                                      as num)
                                                  .toInt()
                                            : null,
                                        serviceType: serviceType,
                                        price: price,
                                        address: address,
                                        description: descCtrl.text.trim(),
                                        scheduledDate: scheduledDate,
                                        scheduledDateKey: dateKey(selectedDay),
                                        scheduledTime: selectedTime,
                                        clientLatitude: clientLatitude,
                                        clientLongitude: clientLongitude,
                                      );

                                  if (!modalContext.mounted) return;
                                  Navigator.pop(ctx);

                                  final isSuccess = res['success'] == true;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        res['message']?.toString() ??
                                            (isSuccess
                                                ? loc.translate(
                                                    'booking_sent_success',
                                                  )
                                                : loc.translate('error')),
                                      ),
                                      backgroundColor: isSuccess
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFFDC2626),
                                    ),
                                  );
                                },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Widgets helpers pour le booking sheet ────────────────────────────────────

class _RecapRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _RecapRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF0D544E)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.subtitleColorOf(context),
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
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
