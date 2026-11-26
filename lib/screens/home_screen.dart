import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

import '../services/firebase_service.dart';
import '../theme/app_theme.dart';
import '../core/localization/app_localizations.dart';
import '../widgets/pro_avatar_widget.dart';

import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import '../providers/locale_provider.dart';
import 'client_profile_screen.dart';
import 'catalog_search_screen.dart';
import 'urgency_screen.dart';
import 'map_screen.dart';
import 'service_detail_screen.dart';
import 'estimate_screen.dart';
import '../widgets/client_banner_ad.dart';
import '../core/routing/app_routes.dart';
import 'booking_chat_screen.dart';
import 'booking_detail_screen.dart';
import 'client_messages_screen.dart';
import 'booking_rating_screen.dart';

class HomeScreen extends StatefulWidget {
  final String userName;
  final String? userEmail;
  final String? userPhone;
  final int initialTab;

  const HomeScreen({
    super.key,
    this.userName = 'Client',
    this.userEmail,
    this.userPhone,
    this.initialTab = 0,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentBottomNavIndex = 0;
  String? _clientPhotoBase64;
  String? _clientPhotoUrl;
  late String _displayName;
  final Set<String> _favIds = {};

  StreamSubscription<List<Map<String, dynamic>>>? _categoriesSub;
  StreamSubscription<int>? _unreadMessagesSub;
  StreamSubscription<List<Map<String, dynamic>>>? _completedBookingsSub;
  final Set<String> _ratingPromptedBookingIds = {};
  final Map<String, String> _observedBookingStatuses = {};
  bool _hasLoadedInitialBookingStatuses = false;
  Map<String, dynamic>? _nextRatingPrompt;
  bool _isRatingPromptOpen = false;
  int _unreadMessages = 0;

  String _getLocalizedCategoryName(String original) {
    final lower = original.trim().toLowerCase();
    if (lower.contains('plomb')) return 'cat_plumbing'.tr();
    if (lower.contains('élec') || lower.contains('elec')) {
      return 'cat_electricity'.tr();
    }
    if (lower.contains('clim')) return 'cat_ac'.tr();
    if (lower.contains('peint')) return 'cat_paint'.tr();
    if (lower.contains('menuis')) return 'cat_carpentry'.tr();
    if (lower.contains('nettoy')) return 'cat_cleaning'.tr();
    if (lower.contains('jardin')) return 'cat_gardening'.tr();
    if (lower.contains('serrur')) return 'cat_locksmith'.tr();
    if (lower == 'plus' || lower.contains('autre')) return 'cat_more'.tr();
    return original;
  }

  @override
  void initState() {
    super.initState();
    _displayName = widget.userName;
    _currentBottomNavIndex = widget.initialTab;
    _loadProfilePhoto();
    _listenToCategories();
    _loadFavorites();
    _listenUnreadMessages();
    _listenCompletedBookingsForRating();
  }

  void _listenToCategories() {
    _categoriesSub = FirebaseService().streamCategories().listen((list) {
      if (mounted && list.isNotEmpty) {
        final activeCategories = list
            .where((c) => c['isActive'] == true)
            .toList();
        if (activeCategories.isNotEmpty) {
          setState(() {
            _categories.clear();
            for (final cat in activeCategories) {
              _categories.add({
                'name': cat['name'],
                'icon': cat['icon'],
                'bgColor': cat['bgColor'],
                'iconColor': cat['iconColor'],
              });
            }
            // Always keep the "Plus" button at the end
            _categories.add({
              'name': 'Plus',
              'icon': Icons.add_rounded,
              'bgColor': const Color(0xFFF1EDE6),
              'iconColor': const Color(0xFF64748B),
            });
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _categoriesSub?.cancel();
    _unreadMessagesSub?.cancel();
    _completedBookingsSub?.cancel();
    super.dispose();
  }

  void _listenCompletedBookingsForRating() {
    _completedBookingsSub = FirebaseService().streamClientBookings().listen(
      (bookings) {
        if (!_hasLoadedInitialBookingStatuses) {
          _hasLoadedInitialBookingStatuses = true;
          for (final booking in bookings) {
            final id = booking['id']?.toString() ?? '';
            if (id.isNotEmpty) {
              _observedBookingStatuses[id] =
                  booking['status']?.toString() ?? '';
            }
          }
          return;
        }
        for (final booking in bookings) {
          final bookingId = booking['id']?.toString() ?? '';
          if (bookingId.isEmpty) continue;
          final previousStatus = _observedBookingStatuses[bookingId];
          final currentStatus = booking['status']?.toString() ?? '';
          _observedBookingStatuses[bookingId] = currentStatus;
          if (currentStatus != 'terminee' ||
              previousStatus == 'terminee' ||
              booking['clientReviewSubmitted'] == true ||
              _ratingPromptedBookingIds.contains(bookingId))
            continue;
          _ratingPromptedBookingIds.add(bookingId);
          _nextRatingPrompt = booking;
          break;
        }
        _openNextRatingPrompt();
      },
      onError: (Object error) {
        debugPrint('Erreur écoute des interventions terminées : $error');
      },
    );
  }

  void _openNextRatingPrompt() {
    if (!mounted || _isRatingPromptOpen || _nextRatingPrompt == null) return;
    final booking = _nextRatingPrompt!;
    _nextRatingPrompt = null;
    _isRatingPromptOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _isRatingPromptOpen = false;
        return;
      }
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => BookingRatingScreen(
            booking: booking,
            isProfessional: false,
            alreadySubmitted: false,
          ),
        ),
      );
      _isRatingPromptOpen = false;
      _openNextRatingPrompt();
    });
  }

  void _listenUnreadMessages() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _unreadMessagesSub = FirebaseService()
        .streamUnreadMessageCount(isPro: false)
        .listen((count) {
          if (mounted) setState(() => _unreadMessages = count);
        });
  }

  Future<void> _loadProfilePhoto() async {
    try {
      final data = await FirebaseService().getCurrentUserData();
      if (data != null && mounted) {
        final base64Photo = data['photoBase64']?.toString().trim() ?? '';
        final urlPhoto = data['photoUrl']?.toString().trim() ?? '';
        setState(() {
          final fullName = data['fullName']?.toString().trim() ?? '';
          if (fullName.isNotEmpty) _displayName = fullName;
          _clientPhotoBase64 = base64Photo.isEmpty ? null : base64Photo;
          _clientPhotoUrl = urlPhoto.isEmpty ? null : urlPhoto;
        });
      }
    } catch (_) {}
  }

  /// Affiche la photo du client (base64 ou URL Storage/Google), sinon ses initiales.
  Widget _buildClientAvatarContent() {
    final raw = _clientPhotoBase64?.trim() ?? '';
    if (raw.isNotEmpty) {
      try {
        return Image.memory(
          base64Decode(raw),
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _buildClientAvatarUrl(),
        );
      } catch (_) {}
    }
    return _buildClientAvatarUrl();
  }

  Widget _buildClientAvatarUrl() {
    final url = _clientPhotoUrl?.trim() ?? '';
    if (url.isNotEmpty) {
      return Image.network(
        url,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildClientInitials(),
      );
    }
    return _buildClientInitials();
  }

  Widget _buildClientInitials() {
    return Text(
      _displayName.isNotEmpty ? _displayName[0].toUpperCase() : 'C',
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 18,
      ),
    );
  }

  Future<void> _loadFavorites() async {
    try {
      FirebaseService().streamFavorites().listen((list) {
        if (mounted) {
          setState(() {
            _favIds.clear();
            for (final p in list) {
              final id = (p['id'] ?? p['uid'] ?? '').toString();
              if (id.isNotEmpty) _favIds.add(id);
            }
          });
        }
      });
    } catch (_) {}
  }

  // Quick actions shown below the home header.
  final List<Map<String, dynamic>> _quickActions = [
    {
      'id': 'urgent',
      'title': 'Urgence',
      'icon': Icons.notifications_active_rounded,
      'color': const Color(0xFFDC3522),
    },
    {
      'id': 'ai',
      'title': 'IA',
      'icon': Icons.smart_toy_rounded,
      'color': const Color(0xFF148C84),
    },
    {
      'id': 'estimate',
      'title': 'Estimer',
      'icon': Icons.paid_rounded,
      'color': const Color(0xFFDE6D1B),
    },
    {
      'id': 'map',
      'title': 'Carte',
      'icon': Icons.map_rounded,
      'color': const Color(0xFF1D83E0),
    },
  ];

  // Exact 9 categories shown in the design mockup
  final List<Map<String, dynamic>> _categories = [
    {
      'name': 'Plomberie',
      'icon': Icons.plumbing,
      'bgColor': const Color(0xFFEEF2FF),
      'iconColor': const Color(0xFF6366F1),
    },
    {
      'name': 'Ménage',
      'icon': Icons.cleaning_services_rounded,
      'bgColor': const Color(0xFFECFDF5),
      'iconColor': const Color(0xFF10B981),
    },
    {
      'name': 'Nettoyage\nCanapé',
      'icon': Icons.weekend_rounded,
      'bgColor': const Color(0xFFF3E8FF),
      'iconColor': const Color(0xFF9333EA),
    },
    {
      'name': 'Coiffure',
      'icon': Icons.content_cut_rounded,
      'bgColor': const Color(0xFFFCE7F3),
      'iconColor': const Color(0xFFEC4899),
    },
    {
      'name': 'Climatisation',
      'icon': Icons.ac_unit_rounded,
      'bgColor': const Color(0xFFE0F2FE),
      'iconColor': const Color(0xFF0284C7),
    },
    {
      'name': 'Électricité',
      'icon': Icons.electrical_services,
      'bgColor': const Color(0xFFFEF3C7),
      'iconColor': const Color(0xFFD97706),
    },
    {
      'name': 'Réfrigérateur',
      'icon': Icons.kitchen_rounded,
      'bgColor': const Color(0xFFE0F2FE),
      'iconColor': const Color(0xFF2563EB),
    },
    {
      'name': 'Machine à laver',
      'icon': Icons.local_laundry_service_rounded,
      'bgColor': const Color(0xFFCCFBF1),
      'iconColor': const Color(0xFF0D9488),
    },
    {
      'name': 'Plus',
      'icon': Icons.add_rounded,
      'bgColor': const Color(0xFFF1EDE6),
      'iconColor': const Color(0xFF64748B),
    },
  ];

  void _showProDetails(Map<String, dynamic> pro) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ServiceDetailScreen(proData: pro)),
    );
  }

  void _showCategoryDetails(String name) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CatalogSearchScreen(initialCategory: name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>();
    context.watch<LocaleProvider>();
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _buildCurrentBody(topPadding),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [const ClientBannerAd(), _buildBottomNav()],
      ),
    );
  }

  Widget _buildCurrentBody(double topPadding) {
    if (_currentBottomNavIndex == 5) {
      return ClientProfileScreen(
        userName: _displayName,
        userEmail: widget.userEmail ?? '',
        userPhone: widget.userPhone ?? '',
      );
    }
    if (_currentBottomNavIndex == 1) {
      return const CatalogSearchScreen();
    }
    if (_currentBottomNavIndex == 2) {
      return _buildFavoritesScreenPlaceholder(topPadding);
    }
    if (_currentBottomNavIndex == 3) {
      return const ClientMessagesScreen(embedded: true);
    }
    if (_currentBottomNavIndex == 4) {
      return _buildHistoryScreenPlaceholder(topPadding);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : AppTheme.titleColor;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final subColor = isDark ? const Color(0xFF94A3B8) : AppTheme.subtitleColor;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Dark Teal Top Header (matches screenshot)
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: topPadding + 14,
              left: 20,
              right: 20,
              bottom: 20,
            ),
            decoration: const BoxDecoration(color: Color(0xFF0D544E)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Greetings + Bell + Avatar
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              'assets/images/logo.png',
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFE89838),
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: const Text(
                                      'D+',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (DateTime.now().hour < 18
                                          ? 'good_morning'
                                          : 'good_evening')
                                      .tr(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 13,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        _displayName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      children: [
                        // Notification Bell - opens a notifications panel (not admin)
                        GestureDetector(
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? const Color(0xFF1E293B)
                                  : Colors.white,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(24),
                                ),
                              ),
                              builder: (sheetCtx) => _NotificationsSheet(
                                isDark:
                                    Theme.of(context).brightness ==
                                    Brightness.dark,
                                clientName: _displayName,
                              ),
                            );
                          },
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: StreamBuilder<List<Map<String, dynamic>>>(
                              stream: FirebaseService()
                                  .streamClientNotifications(),
                              builder: (_, snap) {
                                final unread = (snap.data ?? [])
                                    .where((n) => n['isRead'] != true)
                                    .length;
                                return Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    const Icon(
                                      Icons.notifications_rounded,
                                      color: Color(0xFFE8834F),
                                      size: 24,
                                    ),
                                    if (unread > 0)
                                      Positioned(
                                        right: 8,
                                        top: 8,
                                        child: Container(
                                          width: unread > 9 ? 16 : 14,
                                          height: 14,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFDE6D1B),
                                            shape: BoxShape.circle,
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            unread > 9 ? '9+' : '$unread',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 8,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Avatar circle
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _currentBottomNavIndex = 5;
                            });
                          },
                          child: Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.2),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 2,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _buildClientAvatarContent(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Search Bar Input (matches screenshot)
                Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF17605A),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search_rounded,
                        color: Color(0xFF38BDF8),
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          style: const TextStyle(color: Colors.white),
                          onSubmitted: (val) {
                            if (val.trim().isNotEmpty) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CatalogSearchScreen(
                                    initialSearch: val.trim(),
                                  ),
                                ),
                              );
                            }
                          },
                          decoration: InputDecoration(
                            hintText: 'search_hint'.tr(),
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. Quick action cards
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: _quickActions.map((action) {
                final actionId = action['id'] as String;
                final color = action['color'] as Color;
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    height: 72,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          if (actionId == 'urgent') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const UrgencyScreen(),
                              ),
                            );
                          } else if (actionId == 'ai') {
                            Navigator.of(context)
                                .pushNamed(AppRoutes.aiAssistant);
                          } else if (actionId == 'map') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const MapScreen(),
                              ),
                            );
                          } else if (actionId == 'estimate') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const EstimateScreen(),
                              ),
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              action['icon'] as IconData,
                              color: Colors.white,
                              size: 24,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              switch (actionId) {
                                'urgent' => 'action_urgent'.tr(),
                                'ai' => 'action_ai'.tr(),
                                'estimate' => 'action_estimate'.tr(),
                                _ => 'action_map'.tr(),
                              },
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // 3. Real active promotion (when available)
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('promotions')
                .where('isActive', isEqualTo: true)
                .snapshots(),
            builder: (context, snapshot) {
              final active = snapshot.data?.docs ?? [];
              if (active.isEmpty) return const SizedBox.shrink();
              final promotion = active.first.data();
              final code = (promotion['code'] ?? '').toString();
              final description = (promotion['description'] ?? '').toString();
              if (code.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 135),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    image: const DecorationImage(
                      image: AssetImage('assets/images/slide_3_bg.png'),
                      fit: BoxFit.cover,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF0D544E).withValues(alpha: 0.92),
                          const Color(0xFF0D544E).withValues(alpha: 0.45),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.celebration_rounded,
                              color: Color(0xFFFFD166),
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'client_limited_offer'.tr(),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: code));
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'home_promo_copied'.tr(
                                    namedArgs: {'code': code},
                                  ),
                                ),
                                backgroundColor: Color(0xFFDE6D1B),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDE6D1B),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            code,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // 5. Catégories Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'categories'.tr(),
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CatalogSearchScreen(),
                      ),
                    );
                  },
                  child: Text(
                    'see_all'.tr(),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D544E),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Catégories Grid (Exact 9 icons as mockup)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _categories.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 16,
                crossAxisSpacing: 10,
                mainAxisExtent: 104,
              ),
              itemBuilder: (context, index) {
                final cat = _categories[index];
                return GestureDetector(
                  onTap: () => _showCategoryDetails(cat['name']),
                  child: Column(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E293B)
                              : (cat['bgColor'] as Color),
                          borderRadius: BorderRadius.circular(20),
                          border: isDark
                              ? Border.all(color: const Color(0xFF334155))
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          cat['icon'] as IconData,
                          color: cat['iconColor'] as Color,
                          size: 26,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _getLocalizedCategoryName(cat['name'] as String),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF2C3E50),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // 6. Top Professionnels Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'recommended_pros'.tr(),
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CatalogSearchScreen(),
                      ),
                    );
                  },
                  child: Text(
                    'see_all'.tr(),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D544E),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Top Professionnels Horizontal Cards from Firestore
          SizedBox(
            height: 215,
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: FirebaseService().streamPros(sortBy: 'rating'),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF0D544E)),
                  );
                }
                final pros = snapshot.data ?? [];
                if (pros.isEmpty) {
                  return Center(child: Text('client_no_pro_available'.tr()));
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: pros.length,
                  itemBuilder: (context, index) {
                    final pro = pros[index];
                    final isAvailable = pro['available'] == true;

                    return GestureDetector(
                      onTap: () => _showProDetails(pro),
                      child: Container(
                        width: 175,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(20),
                          border: isDark
                              ? Border.all(color: const Color(0xFF334155))
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: isDark ? 0.2 : 0.04,
                              ),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Pro Photo with "• Disponible" pill
                            SizedBox(
                              width: double.infinity,
                              height: 105,
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(20),
                                      ),
                                      child: ProAvatarWidget(
                                        name: pro['name'] as String? ?? '',
                                        photoBase64:
                                            pro['photoBase64'] as String? ?? '',
                                        photoUrl:
                                            pro['photoUrl'] as String? ?? '',
                                        avatarAsset:
                                            pro['avatarAsset'] as String? ?? '',
                                        size: 175,
                                        borderRadius: 0,
                                        showVerifiedBadge: false,
                                        fill: true,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isAvailable
                                            ? const Color(0xFF10B981)
                                            : Colors.grey,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        isAvailable
                                            ? '• ${'available'.tr()}'
                                            : '• ${'unavailable'.tr()}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    left: 8,
                                    child: GestureDetector(
                                      onTap: () async {
                                        final proId =
                                            (pro['id'] ?? pro['uid'] ?? '')
                                                .toString();
                                        final isNowFav = await FirebaseService()
                                            .toggleFavorite(pro);
                                        if (!context.mounted) return;
                                        setState(() {
                                          if (isNowFav) {
                                            _favIds.add(proId);
                                          } else {
                                            _favIds.remove(proId);
                                          }
                                        });
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              isNowFav
                                                  ? '${pro['name']} ajouté aux favoris !'
                                                  : '${pro['name']} retiré des favoris.',
                                            ),
                                            backgroundColor: isNowFav
                                                ? const Color(0xFF10B981)
                                                : Colors.grey.shade700,
                                            duration: const Duration(
                                              seconds: 1,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(5),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(
                                            alpha: 0.4,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _favIds.contains(
                                                (pro['id'] ?? pro['uid'] ?? '')
                                                    .toString(),
                                              )
                                              ? Icons.favorite_rounded
                                              : Icons.favorite_border_rounded,
                                          color:
                                              _favIds.contains(
                                                (pro['id'] ?? pro['uid'] ?? '')
                                                    .toString(),
                                              )
                                              ? const Color(0xFFEF4444)
                                              : Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pro['name'] ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: titleColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          pro['serviceType'] ??
                                              pro['service'] ??
                                              '',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF0D544E),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.star_rounded,
                                            color: Color(0xFFF39C12),
                                            size: 15,
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            '${pro['rating'] ?? 4.8}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: titleColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        pro['price'] ?? '',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFDE6D1B),
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
                    );
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // 7. Près de vous Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'client_near_you'.tr(),
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: titleColor,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Près de vous Vertical List (Real Firestore Stream)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: FirebaseService().streamPros(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(
                        color: Color(0xFF0D544E),
                      ),
                    ),
                  );
                }
                final pros = snapshot.data ?? [];
                if (pros.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'client_no_pro_found'.tr(),
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  );
                }

                return Column(
                  children: pros.map((pro) {
                    final ratingVal = pro['rating'] != null
                        ? pro['rating'].toString()
                        : '4.8';
                    final priceVal = pro['price'] != null
                        ? pro['price'].toString()
                        : 'Sur devis';
                    final isAvail =
                        pro['isAvailable'] == true || pro['available'] == true;
                    final reviewsCount =
                        pro['reviewsCount'] ?? pro['reviews'] ?? '24';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: isDark
                            ? Border.all(color: const Color(0xFF334155))
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.2 : 0.03,
                            ),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: InkWell(
                        onTap: () => _showProDetails(pro),
                        borderRadius: BorderRadius.circular(20),
                        child: Row(
                          children: [
                            // Avatar with teal verified badge
                            ProAvatarWidget(
                              name: pro['name'] as String? ?? '',
                              photoBase64: pro['photoBase64'] as String? ?? '',
                              photoUrl: pro['photoUrl'] as String? ?? '',
                              avatarAsset: pro['avatarAsset'] as String? ?? '',
                              size: 58,
                              borderRadius: 16,
                              showVerifiedBadge: pro['demoProfile'] != true,
                            ),
                            const SizedBox(width: 14),
                            // Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pro['name'] ?? '',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: titleColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          pro['city'] ??
                                              pro['distance'] ??
                                              'Tunis, Tunisie',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: subColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.star_rounded,
                                        color: Color(0xFFF39C12),
                                        size: 15,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        '$ratingVal ($reviewsCount)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: titleColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Price & Availability Pill
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  priceVal,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFDE6D1B),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isAvail
                                        ? const Color(0xFF10B981)
                                              .withValues(alpha: 0.12)
                                        : Colors.grey.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    isAvail ? 'Disponible' : 'Indisponible',
                                    style: TextStyle(
                                      color: isAvail
                                          ? const Color(0xFF10B981)
                                          : Colors.grey,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildFavoritesScreenPlaceholder(double topPadding) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    return SafeArea(
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: FirebaseService().streamFavorites(),
        builder: (context, snapshot) {
          final favs = snapshot.data ?? [];

          if (snapshot.connectionState == ConnectionState.waiting &&
              favs.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF0D544E)),
            );
          }

          if (favs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.favorite_border_rounded,
                        size: 56,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'favorites_empty_title'.tr(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'favorites_empty_body'.tr(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() => _currentBottomNavIndex = 0);
                      },
                      icon: const Icon(Icons.search_rounded, size: 18),
                      label: Text(
                        'favorites_discover'.tr(),
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D544E),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'favorites_title'.tr(),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D544E).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${favs.length}',
                        style: const TextStyle(
                          color: Color(0xFF0D544E),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: ListView.separated(
                    itemCount: favs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final pro = favs[index];
                      final proName =
                          pro['name'] ?? pro['fullName'] ?? 'Artisan';
                      final service = pro['serviceType'] ?? 'Service';
                      final price = pro['price'] ?? '35 DT/h';
                      final rating = (pro['rating'] is num)
                          ? (pro['rating'] as num).toDouble()
                          : 4.8;

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: borderColor),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: isDark ? 0.2 : 0.02,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            ProAvatarWidget(
                              name: pro['name'] as String? ?? '',
                              photoBase64: pro['photoBase64'] as String? ?? '',
                              photoUrl: pro['photoUrl'] as String? ?? '',
                              avatarAsset: pro['avatarAsset'] as String? ?? '',
                              size: 62,
                              borderRadius: 14,
                              showVerifiedBadge: pro['demoProfile'] != true,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    proName,
                                    style: TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.bold,
                                      color: textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          service,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: textSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.star_rounded,
                                        size: 16,
                                        color: Color(0xFFF59E0B),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        rating.toStringAsFixed(1),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: textPrimary,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        price,
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFDE6D1B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.favorite_rounded,
                                    color: Color(0xFFEF4444),
                                    size: 22,
                                  ),
                                  tooltip: 'Retirer des favoris',
                                  onPressed: () async {
                                    await FirebaseService().toggleFavorite(pro);
                                    if (mounted) setState(() {});
                                  },
                                ),
                                ElevatedButton(
                                  onPressed: () => _showProDetails(pro),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0D544E),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    minimumSize: Size.zero,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: Text(
                                    'book_now'.tr(),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHistoryScreenPlaceholder(double topPadding) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DefaultTabController(
      length: 4,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Text(
                    loc.translate('bookings'),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(25),
              ),
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: const Color(0xFF0D544E),
                  borderRadius: BorderRadius.circular(25),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: isDark
                    ? Colors.grey.shade400
                    : Colors.grey.shade700,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                tabs: [
                  Tab(text: loc.translate('tab_all')),
                  Tab(text: loc.translate('tab_pending')),
                  Tab(text: loc.translate('tab_confirmed')),
                  Tab(text: loc.translate('tab_completed')),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                children: [
                  _buildBookingsTabContent('Toutes'),
                  _buildBookingsTabContent('En attente'),
                  _buildBookingsTabContent('Confirmées'),
                  _buildBookingsTabContent('Terminées'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingsTabContent(String filter) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirebaseService().streamClientBookings(statusFilter: filter),
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
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFD7F3EA).withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.calendar_today_rounded,
                    size: 48,
                    color: Color(0xFF0D544E),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  loc.translate('no_bookings'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'home_status_label'.tr(namedArgs: {'status': filter}),
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          itemCount: bookings.length,
          itemBuilder: (context, index) {
            final b = bookings[index];
            final status = (b['status'] ?? 'en_attente').toString();
            Color statusBg;
            Color statusText;
            String statusLabel;
            if (status == 'confirmee') {
              statusBg = const Color(0xFF10B981).withValues(alpha: 0.15);
              statusText = const Color(0xFF10B981);
              statusLabel = 'Confirmée';
            } else if (status == 'terminee') {
              statusBg = const Color(0xFF3B82F6).withValues(alpha: 0.15);
              statusText = const Color(0xFF3B82F6);
              statusLabel = 'Terminée';
            } else if (status == 'annulee') {
              statusBg = const Color(0xFFEF4444).withValues(alpha: 0.15);
              statusText = const Color(0xFFEF4444);
              statusLabel = 'Annulée';
            } else {
              statusBg = const Color(0xFFF59E0B).withValues(alpha: 0.15);
              statusText = const Color(0xFFD97706);
              statusLabel = 'En attente';
            }

            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isDark ? Colors.transparent : const Color(0xFFE2E8F0),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            b['serviceType'] ?? 'Service',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : AppTheme.titleColor,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: statusText,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.person_outline_rounded,
                          size: 16,
                          color: Color(0xFF0D544E),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          b['proName'] ?? 'Professionnel',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? Colors.grey.shade300
                                : AppTheme.subtitleColor,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          b['price'] ?? '',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFDE6D1B),
                          ),
                        ),
                      ],
                    ),
                    if (b['address'] != null &&
                        b['address'].toString().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              b['address'].toString(),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (b['scheduledDate'] != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.event_outlined,
                            size: 16,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            b['scheduledDate'].toString(),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (status == 'en_attente') ...[
                      const Divider(height: 20),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () async {
                            final bookingId = b['id']?.toString() ?? '';
                            if (bookingId.isEmpty) return;
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (dialogContext) => AlertDialog(
                                title: Text('booking_cancel_confirm'.tr()),
                                content: Text('booking_cancel_warning'.tr()),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(dialogContext).pop(false),
                                    child: Text('cancel'.tr()),
                                  ),
                                  FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFFDC2626),
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () =>
                                        Navigator.of(dialogContext).pop(true),
                                    child: Text('confirm'.tr()),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed != true || !context.mounted) return;
                            final ok = await FirebaseService().cancelBooking(
                              bookingId,
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    ok
                                        ? 'Réservation annulée'
                                        : 'Impossible d\'annuler',
                                  ),
                                  backgroundColor: ok
                                      ? const Color(0xFFEF4444)
                                      : Colors.grey,
                                ),
                              );
                            }
                          },
                          icon: const Icon(
                            Icons.cancel_outlined,
                            size: 16,
                            color: Color(0xFFEF4444),
                          ),
                          label: Text(
                            'cancel_service_request'.tr(),
                            style: TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 8. Bottom Navigation Bar matching screenshot
  Widget _buildBottomNav() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: isDark
            ? const Border(
                top: BorderSide(color: Color(0xFF334155), width: 0.8),
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentBottomNavIndex,
        onTap: (index) {
          setState(() {
            _currentBottomNavIndex = index;
          });
          // Rafraîchit la photo de profil quand on revient à l'accueil
          if (index == 0) _loadProfilePhoto();
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        selectedItemColor: isDark
            ? const Color(0xFF14B8A6)
            : const Color(0xFF0D544E),
        unselectedItemColor: const Color(0xFF94A3B8),
        selectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_outlined),
            activeIcon: const Icon(Icons.home_rounded),
            label: 'home'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.search_rounded),
            label: 'search'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.favorite_border_rounded),
            activeIcon: const Icon(Icons.favorite_rounded),
            label: 'favorites'.tr(),
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
            activeIcon: Badge(
              isLabelVisible: _unreadMessages > 0,
              label: Text(
                _unreadMessages > 9 ? '9+' : '$_unreadMessages',
                style: const TextStyle(fontSize: 9, color: Colors.white),
              ),
              child: const Icon(Icons.chat_bubble_rounded),
            ),
            label: 'messages_inbox'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.access_time_rounded),
            label: 'nav_bookings'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline_rounded),
            activeIcon: const Icon(Icons.person_rounded),
            label: 'profile'.tr(),
          ),
        ],
      ),
    );
  }
}

// ── Notifications Sheet ───────────────────────────────────────────────────────
class _NotificationsSheet extends StatelessWidget {
  final bool isDark;
  final String clientName;
  const _NotificationsSheet({required this.isDark, required this.clientName});

  Color _notifColor(String? type) {
    switch (type) {
      case 'booking_status_update':
        return const Color(0xFF0D544E);
      case 'new_booking':
        return const Color(0xFFDE6D1B);
      default:
        return const Color(0xFF64748B);
    }
  }

  IconData _notifIcon(String? newStatus) {
    switch (newStatus) {
      case 'confirmee':
        return Icons.check_circle_rounded;
      case 'annulee':
        return Icons.cancel_rounded;
      case 'terminee':
        return Icons.flag_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.35,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle + header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 0),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF334155)
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'notifications'.tr(),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: titleColor,
                        ),
                      ),
                      StreamBuilder<List<Map<String, dynamic>>>(
                        stream: FirebaseService().streamClientNotifications(),
                        builder: (_, snap) {
                          final unread = (snap.data ?? [])
                              .where((n) => n['isRead'] != true)
                              .length;
                          if (unread == 0) return const SizedBox.shrink();
                          return TextButton(
                            onPressed: () async {
                              final uid = (snap.data?.isNotEmpty == true)
                                  ? snap.data!.first['recipientId'] as String?
                                  : null;
                              if (uid != null) {
                                await FirebaseService()
                                    .markAllNotificationsRead(uid);
                              }
                            },
                            child: Text(
                              'mark_all_read'.tr(),
                              style: const TextStyle(
                                color: Color(0xFF0D544E),
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
            const Divider(height: 1),
            // List
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: FirebaseService().streamClientNotifications(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF0D544E),
                      ),
                    );
                  }
                  final notifs = snap.data ?? [];
                  if (notifs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_none_rounded,
                            size: 52,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'no_notifications'.tr(),
                            style: TextStyle(fontSize: 14, color: subColor),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    itemCount: notifs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final n = notifs[i];
                      final isUnread = n['isRead'] != true;
                      final type = n['type'] as String?;
                      final newStatus = n['newStatus'] as String?;
                      final color = _notifColor(type);
                      final icon = _notifIcon(newStatus);
                      final title = n['title'] as String? ?? '';
                      final body = n['body'] as String? ?? '';
                      final time = n['timeLabel'] as String? ?? '';
                      final nid = n['id'] as String? ?? '';

                      return GestureDetector(
                        onTap: () async {
                          final navigator = Navigator.of(context);
                          if (isUnread && nid.isNotEmpty) {
                            await FirebaseService().markNotificationRead(nid);
                          }
                          if (!navigator.mounted) return;

                          if (type == 'booking_status_update' &&
                              newStatus == 'terminee' &&
                              n['bookingId'] != null) {
                            navigator.pop();
                            navigator.push(
                              MaterialPageRoute(
                                builder: (_) => BookingDetailScreen(
                                  booking: {
                                    'id': n['bookingId'].toString(),
                                    'clientId': n['recipientId'],
                                    'proId': n['proId'],
                                    'proName':
                                        n['proName'] as String? ?? 'Artisan',
                                    'serviceType':
                                        n['serviceType'] as String? ??
                                        'Service',
                                    'address': n['address'] as String? ?? '',
                                    'scheduledDate':
                                        n['scheduledDate'] as String? ?? '',
                                    'price': n['baseAmount']?.toString() ?? '',
                                    'status': 'terminee',
                                    'clientReviewSubmitted': false,
                                  },
                                ),
                              ),
                            );
                            return;
                          }

                          if (type == 'booking_status_update' &&
                              newStatus == 'confirmee' &&
                              n['bookingId'] != null) {
                            final chatBooking = <String, dynamic>{
                              'id': n['bookingId'].toString(),
                              'clientName': clientName,
                              'proId': n['proId'],
                              'proName': n['proName'] as String? ?? 'Artisan',
                              'serviceType':
                                  n['serviceType'] as String? ?? 'Service',
                              'status': 'confirmee',
                            };
                            navigator.pop();
                            final action = await showDialog<bool>(
                              context: navigator.context,
                              builder: (dialogContext) => AlertDialog(
                                title: Text('booking_chat_title'.tr()),
                                content: Text('booking_accepted_choice'.tr()),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext),
                                    child: Text('cancel'.tr()),
                                  ),
                                  TextButton.icon(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, true),
                                    icon: const Icon(
                                      Icons.chat_bubble_outline_rounded,
                                    ),
                                    label: Text('booking_chat_action'.tr()),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, false),
                                    child: Text('booking_payment_action'.tr()),
                                  ),
                                ],
                              ),
                            );
                            if (action == null) return;
                            if (action) {
                              navigator.push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      BookingChatScreen(booking: chatBooking),
                                ),
                              );
                            } else {
                              navigator.pushNamed(
                                AppRoutes.checkout,
                                arguments: {
                                  'bookingId': n['bookingId'].toString(),
                                  'proId': n['proId'] as String? ?? '',
                                  'proName':
                                      n['proName'] as String? ?? 'Artisan',
                                  'serviceType':
                                      n['serviceType'] as String? ?? 'Service',
                                  'baseAmount':
                                      (n['baseAmount'] as num?)?.toDouble() ??
                                      45.0,
                                  'address': n['address'] as String? ?? 'Tunis',
                                  'scheduledDate':
                                      n['scheduledDate'] as String?,
                                },
                              );
                            }
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isUnread
                                ? color.withValues(alpha: 0.07)
                                : (isDark
                                      ? const Color(0xFF0F172A)
                                      : const Color(0xFFF8FAFC)),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isUnread
                                  ? color.withValues(alpha: 0.25)
                                  : (isDark
                                        ? const Color(0xFF334155)
                                        : const Color(0xFFE2E8F0)),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Icône
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(icon, color: color, size: 20),
                              ),
                              const SizedBox(width: 12),
                              // Texte
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            title,
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: isUnread
                                                  ? FontWeight.bold
                                                  : FontWeight.w600,
                                              color: titleColor,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isUnread)
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: color,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      body,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: subColor,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      time,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: subColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
