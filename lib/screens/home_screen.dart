import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../theme/app_theme.dart';
import '../core/localization/app_localizations.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/locale_provider.dart';
import 'admin_requests_screen.dart';
import 'client_profile_screen.dart';
import 'catalog_search_screen.dart';
import 'service_detail_screen.dart';

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

  StreamSubscription<List<Map<String, dynamic>>>? _categoriesSub;

  String _getLocalizedCategoryName(String original) {
    final lower = original.trim().toLowerCase();
    if (lower.contains('plomb')) return context.tr('cat_plumbing');
    if (lower.contains('élec') || lower.contains('elec')) return context.tr('cat_electricity');
    if (lower.contains('clim')) return context.tr('cat_ac');
    if (lower.contains('peint')) return context.tr('cat_paint');
    if (lower.contains('menuis')) return context.tr('cat_carpentry');
    if (lower.contains('nettoy')) return context.tr('cat_cleaning');
    if (lower.contains('jardin')) return context.tr('cat_gardening');
    if (lower.contains('serrur')) return context.tr('cat_locksmith');
    if (lower == 'plus' || lower.contains('autre')) return context.tr('cat_more');
    return original;
  }

  @override
  void initState() {
    super.initState();
    _currentBottomNavIndex = widget.initialTab;
    _loadProfilePhoto();
    _listenToCategories();
  }

  void _listenToCategories() {
    _categoriesSub = FirebaseService().streamCategories().listen((list) {
      if (mounted && list.isNotEmpty) {
        final activeCategories = list.where((c) => c['isActive'] == true).toList();
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
    super.dispose();
  }

  Future<void> _loadProfilePhoto() async {
    try {
      final data = await FirebaseService().getCurrentUserData();
      if (data != null && mounted) {
        final photo = data['photoBase64'] as String?;
        if (photo != null && photo.trim().isNotEmpty) {
          setState(() {
            _clientPhotoBase64 = photo.trim();
          });
        }
      }
    } catch (_) {}
  }
  String _selectedLocation = 'Tunis, El Menzah';

  // 3 Quick Actions without the AI icon as requested
  final List<Map<String, dynamic>> _quickActions = [
    {
      'title': 'Urgence',
      'icon': Icons.notifications_active_rounded,
      'color': const Color(0xFFDC3522),
    },
    {
      'title': 'Estimer',
      'icon': Icons.paid_rounded,
      'color': const Color(0xFFDE6D1B),
    },
    {
      'title': 'Carte',
      'icon': Icons.map_rounded,
      'color': const Color(0xFF1D83E0),
    },
  ];

  // Exact 9 categories shown in the design mockup
  final List<Map<String, dynamic>> _categories = [
    {
      'name': 'Plomberie',
      'icon': Icons.build_rounded,
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
      'icon': Icons.bolt_rounded,
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
      MaterialPageRoute(
        builder: (_) => ServiceDetailScreen(proData: pro),
      ),
    );
  }

  void _showLocationPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        final cities = [
          'Tunis, El Menzah',
          'Tunis, Les Berges du Lac',
          'Tunis, Ennasr 2',
          'La Marsa',
          'Carthage',
          'Ariana Ville',
          'Sousse, Kantaoui',
          'Sfax Ville',
        ];

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choisir votre zone',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.titleColor,
                  fontFamily: 'serif',
                ),
              ),
              const SizedBox(height: 14),
              ...cities.map((city) {
                final isSelected = city == _selectedLocation;
                return ListTile(
                  leading: const Icon(Icons.location_on_rounded,
                      color: Color(0xFF0D544E)),
                  title: Text(
                    city,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? const Color(0xFF0D544E)
                          : (isDark ? Colors.white : AppTheme.titleColor),
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_rounded,
                          color: Color(0xFF0D544E))
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedLocation = city;
                    });
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        );
      },
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
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildCurrentBody(double topPadding) {
    if (_currentBottomNavIndex == 4) {
      return ClientProfileScreen(
        userName: widget.userName,
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
            decoration: const BoxDecoration(
              color: Color(0xFF0D544E),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Greetings + Bell + Avatar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            'assets/images/logo.png',
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(
                                color: Color(0xFFE89838),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: const Text('D+', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('good_morning'),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 13,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${widget.userName} 👋',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        // Notification Bell circle with dot
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AdminRequestsScreen(),
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
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                const Icon(
                                  Icons.notifications_rounded,
                                  color: Color(0xFFE8834F),
                                  size: 24,
                                ),
                                Positioned(
                                  right: 10,
                                  top: 10,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFDE6D1B),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Avatar circle
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _currentBottomNavIndex = 4;
                            });
                          },
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 2,
                              ),
                              image: _clientPhotoBase64 != null && _clientPhotoBase64!.isNotEmpty
                                  ? DecorationImage(
                                      image: MemoryImage(base64Decode(_clientPhotoBase64!)),
                                      fit: BoxFit.cover,
                                    )
                                  : const DecorationImage(
                                      image: AssetImage('assets/images/slide_1_photo.png'),
                                      fit: BoxFit.cover,
                                    ),
                            ),
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
                                  builder: (_) => CatalogSearchScreen(initialSearch: val.trim()),
                                ),
                              );
                            }
                          },
                          decoration: InputDecoration(
                            hintText: context.tr('search_hint'),
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

                const SizedBox(height: 14),

                // Location and Loyalty Points Row (matches screenshot)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Location selector
                    GestureDetector(
                      onTap: _showLocationPicker,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            color: Color(0xFFF43F5E),
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _selectedLocation,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_drop_down_rounded,
                            color: Colors.white70,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                    // Points Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF17605A),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.timer_rounded,
                            color: Color(0xFF818CF8),
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Text(
                            '820 pts',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Quick Action Cards (Urgence, Estimer, Carte) - WITHOUT AI as requested
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: _quickActions.map((action) {
                final color = action['color'] as Color;
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    height: 88,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(18),
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Action : ${action['title']}'),
                              backgroundColor: color,
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(18),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              action['icon'] as IconData,
                              color: Colors.white,
                              size: 28,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              action['title'] == 'Urgence'
                                  ? context.tr('action_urgent')
                                  : (action['title'] == 'Estimer'
                                      ? context.tr('action_estimate')
                                      : context.tr('action_map')),
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

          // 3. Loyalty & Coupons row (matches screenshot)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Argent 820 pts
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFECE7DF),
                      borderRadius: BorderRadius.circular(16),
                      border: isDark ? Border.all(color: const Color(0xFF334155)) : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF818CF8).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Text('🥈', style: TextStyle(fontSize: 14)),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('client_silver_pts'),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: titleColor,
                              ),
                            ),
                            Text(
                              context.tr('client_loyalty_sub'),
                              style: TextStyle(
                                fontSize: 11,
                                color: subColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // 3 coupons DAR20
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFDEEE7),
                      borderRadius: BorderRadius.circular(16),
                      border: isDark ? Border.all(color: const Color(0xFF334155)) : null,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.confirmation_num_rounded,
                          color: Color(0xFFDE6D1B),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('client_coupons_count'),
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFDE6D1B),
                              ),
                            ),
                            Text(
                              'DAR20',
                              style: TextStyle(
                                fontSize: 11,
                                color: subColor,
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

          const SizedBox(height: 18),

          // 4. Promo Banner ("-20% sur tout ce weekend")
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 135,
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
                padding: const EdgeInsets.all(16),
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
                        const Text('🎉', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 6),
                        Text(
                          context.tr('client_limited_offer'),
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
                      context.tr('client_promo_title'),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Code promo DAR20 appliqué (-20%) !'),
                            backgroundColor: Color(0xFFDE6D1B),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDE6D1B),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        context.tr('client_claim_offer'),
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
          ),

          const SizedBox(height: 24),

          // 5. Catégories Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.tr('categories'),
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
                    context.tr('see_all'),
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
                childAspectRatio: 0.82,
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
                          color: isDark ? const Color(0xFF1E293B) : (cat['bgColor'] as Color),
                          borderRadius: BorderRadius.circular(20),
                          border: isDark ? Border.all(color: const Color(0xFF334155)) : null,
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
                          color: isDark ? Colors.white : const Color(0xFF2C3E50),
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
                  context.tr('recommended_pros'),
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
                    context.tr('see_all'),
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
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF0D544E)));
                }
                final pros = snapshot.data ?? [];
                if (pros.isEmpty) {
                  return Center(child: Text(context.tr('client_no_pro_available')));
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
                          border: isDark ? Border.all(color: const Color(0xFF334155)) : null,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Pro Photo with "• Disponible" pill
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                  child: Image.asset(
                                    pro['avatarAsset'] ?? 'assets/images/slide_1_photo.png',
                                    height: 105,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Container(
                                      height: 105,
                                      color: const Color(0xFFE2DDD5),
                                      child: const Icon(Icons.person_rounded, size: 40, color: Colors.grey),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isAvailable ? const Color(0xFF10B981) : Colors.grey,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      isAvailable ? '• ${context.tr('available')}' : '• ${context.tr('unavailable')}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
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
                                  Text(
                                    pro['serviceType'] ?? pro['service'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF0D544E),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.star_rounded, color: Color(0xFFF39C12), size: 15),
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
              context.tr('client_near_you'),
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
                      child: CircularProgressIndicator(color: Color(0xFF0D544E)),
                    ),
                  );
                }
                final pros = snapshot.data ?? [];
                if (pros.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        context.tr('client_no_pro_found'),
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  );
                }

                return Column(
                  children: pros.map((pro) {
                    final ratingVal = pro['rating'] != null ? pro['rating'].toString() : '4.8';
                    final priceVal = pro['price'] != null ? pro['price'].toString() : 'Sur devis';
                    final isAvail = pro['isAvailable'] == true || pro['available'] == true;
                    final reviewsCount = pro['reviewsCount'] ?? pro['reviews'] ?? '24';
                    final avatar = pro['avatarAsset'] as String? ?? 'assets/images/slide_2_photo.png';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: isDark ? Border.all(color: const Color(0xFF334155)) : null,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
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
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.asset(
                                    avatar,
                                    width: 58,
                                    height: 58,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      width: 58,
                                      height: 58,
                                      color: const Color(0xFFE2DDD5),
                                      child: const Icon(Icons.person_rounded),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: -3,
                                  bottom: -3,
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF0D544E),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check_rounded,
                                      color: Colors.white,
                                      size: 10,
                                    ),
                                  ),
                                ),
                              ],
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
                                  Text(
                                    pro['city'] ?? pro['distance'] ?? 'Tunis, Tunisie',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: subColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.star_rounded,
                                          color: Color(0xFFF39C12), size: 15),
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
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isAvail
                                        ? const Color(0xFF10B981).withValues(alpha: 0.12)
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
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.favorite_rounded, size: 54, color: Color(0xFFDE6D1B)),
            const SizedBox(height: 12),
            Text(
              context.tr('client_favorite_pros_title'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppTheme.titleColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.tr('client_favorite_pros_sub'),
              style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey),
            ),
          ],
        ),
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
                unselectedLabelColor: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFD7F3EA).withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.calendar_today_rounded, size: 48, color: Color(0xFF0D544E)),
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
                  'Statut : $filter',
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
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
                              color: isDark ? Colors.white : AppTheme.titleColor,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                        const Icon(Icons.person_outline_rounded, size: 16, color: Color(0xFF0D544E)),
                        const SizedBox(width: 6),
                        Text(
                          b['proName'] ?? 'Professionnel',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey.shade300 : AppTheme.subtitleColor,
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
                    if (b['address'] != null && b['address'].toString().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: 16, color: Colors.grey.shade500),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              b['address'].toString(),
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
                          Icon(Icons.event_outlined, size: 16, color: Colors.grey.shade500),
                          const SizedBox(width: 6),
                          Text(
                            b['scheduledDate'].toString(),
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
                            final ok = await FirebaseService().cancelBooking(bookingId);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(ok ? 'Réservation annulée' : 'Impossible d\'annuler'),
                                  backgroundColor: ok ? const Color(0xFFEF4444) : Colors.grey,
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.cancel_outlined, size: 16, color: Color(0xFFEF4444)),
                          label: const Text(
                            'Annuler la demande',
                            style: TextStyle(color: Color(0xFFEF4444), fontSize: 12),
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
        border: isDark ? const Border(top: BorderSide(color: Color(0xFF334155), width: 0.8)) : null,
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
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        selectedItemColor: isDark ? const Color(0xFF14B8A6) : const Color(0xFF0D544E),
        unselectedItemColor: const Color(0xFF94A3B8),
        selectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 11,
        ),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_outlined),
            activeIcon: const Icon(Icons.home_rounded),
            label: context.tr('home'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.search_rounded),
            label: context.tr('search'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.favorite_border_rounded),
            activeIcon: const Icon(Icons.favorite_rounded),
            label: context.tr('favorites'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.access_time_rounded),
            label: context.tr('bookings'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline_rounded),
            activeIcon: const Icon(Icons.person_rounded),
            label: context.tr('profile'),
          ),
        ],
      ),
    );
  }
}
