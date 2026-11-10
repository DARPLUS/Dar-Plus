import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../theme/app_theme.dart';
import '../core/localization/app_localizations.dart';
import '../widgets/pro_avatar_widget.dart';
import 'service_detail_screen.dart';

class CatalogSearchScreen extends StatefulWidget {
  final String? initialCategory;
  final String? initialSearch;

  const CatalogSearchScreen({
    super.key,
    this.initialCategory,
    this.initialSearch,
  });

  @override
  State<CatalogSearchScreen> createState() => _CatalogSearchScreenState();
}

class _CatalogSearchScreenState extends State<CatalogSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  late String _selectedCategory;
  String _searchQuery = '';
  bool _onlyAvailable = false;
  String _sortBy = 'rating';
  double _minRating = 0.0;

  // Catégories dynamiques chargées depuis Firestore
  List<Map<String, dynamic>> _dynamicCategories = [];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory ?? 'Tous';
    if (widget.initialSearch != null && widget.initialSearch!.isNotEmpty) {
      _searchController.text = widget.initialSearch!;
      _searchQuery = widget.initialSearch!;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _allCategories {
    final allItem = <Map<String, dynamic>>[
      {
        'id': '__all__',
        'name': 'Tous',
        'icon': Icons.grid_view_rounded,
        'iconColor': const Color(0xFF0D544E),
        'bgColor': const Color(0xFFD7F3EA),
      },
    ];
    allItem.addAll(_dynamicCategories);
    return allItem;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          _selectedCategory == 'Tous'
              ? loc.translate('catalog_title')
              : _selectedCategory,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppTheme.titleColor,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            tooltip: loc.translate('filters_and_sort'),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.transparent : const Color(0xFFE2DDD5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: loc.translate('search_hint'),
                  hintStyle: TextStyle(
                    color:
                        isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Color(0xFF0D544E),
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon:
                              const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),

          // 2. Horizontal Category Pills (dynamiques)
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: FirebaseService().streamCategories(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                final active = snapshot.data!
                    .where((c) => c['isActive'] == true)
                    .toList();
                if (_dynamicCategories.length != active.length) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() => _dynamicCategories = active);
                    }
                  });
                }
              }
              final cats = _allCategories;
              return SizedBox(
                height: 48,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 4),
                  scrollDirection: Axis.horizontal,
                  itemCount: cats.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final cat = cats[index];
                    final catName = cat['name'] as String;
                    final isSelected = _selectedCategory.toLowerCase() ==
                        catName.toLowerCase();
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _selectedCategory = catName),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF0D544E)
                              : (isDark
                                  ? const Color(0xFF1E293B)
                                  : Colors.white),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF0D544E)
                                : (isDark
                                    ? Colors.transparent
                                    : Colors.grey.shade300),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          catName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : (isDark
                                    ? Colors.grey.shade300
                                    : AppTheme.titleColor),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),

          const SizedBox(height: 8),

          // 3. Results Counter (temps réel)
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: FirebaseService().streamPros(
                category: _selectedCategory,
                searchQuery: _searchQuery,
                onlyAvailable: _onlyAvailable,
                sortBy: _sortBy,
              ),
              builder: (context, snapshot) {
                final allPros = snapshot.data ?? [];
                final filtered = _minRating > 0
                    ? allPros
                        .where((p) =>
                            (p['rating'] as num).toDouble() >= _minRating)
                        .toList()
                    : allPros;
                final count = filtered.length;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Résultats : $count artisan${count > 1 ? "s" : ""}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? Colors.grey.shade400
                            : AppTheme.subtitleColor,
                      ),
                    ),
                    if (_onlyAvailable || _minRating > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          loc.translate('available'),
                          style: const TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),

          // 4. Stream of Pros
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: FirebaseService().streamPros(
                category: _selectedCategory,
                searchQuery: _searchQuery,
                onlyAvailable: _onlyAvailable,
                sortBy: _sortBy,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF0D544E)),
                  );
                }

                var pros = snapshot.data ?? [];

                // Filtre par note minimale
                if (_minRating > 0) {
                  pros = pros
                      .where((p) =>
                          (p['rating'] as num).toDouble() >= _minRating)
                      .toList();
                }

                if (pros.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFD7F3EA)
                                    .withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.search_off_rounded,
                            size: 48,
                            color: Color(0xFF0D544E),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          loc.translate('no_pros_found'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : AppTheme.titleColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          loc.translate('adjust_filters_hint'),
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  itemCount: pros.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) =>
                      _buildProCard(context, pros[index], isDark),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProCard(
    BuildContext context,
    Map<String, dynamic> pro,
    bool isDark,
  ) {
    final proId = pro['id'] ?? 'pro_${pro['name']}';
    final photoBase64 = pro['photoBase64'] as String? ?? '';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.transparent : const Color(0xFFEDE8E1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ServiceDetailScreen(proData: pro),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Hero(
                tag: 'pro_avatar_$proId',
                child: ProAvatarWidget(
                  size: 64,
                  name: pro['name'] ?? '',
                  photoBase64: photoBase64,
                  borderRadius: 16,
                  showVerifiedBadge: true,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            pro['name'] ?? '',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : AppTheme.titleColor,
                            ),
                          ),
                        ),
                        Text(
                          pro['price'] ?? '',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFDE6D1B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D544E)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            pro['serviceType'] ?? '',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0D544E),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.location_on_rounded,
                          size: 13,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          pro['location'] ?? '',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFF39C12),
                          size: 16,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${pro['rating']}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : AppTheme.titleColor,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '(${pro['reviewsCount']} avis)',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: (pro['available'] == true)
                                ? const Color(0xFF10B981)
                                    .withValues(alpha: 0.12)
                                : Colors.grey.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            (pro['available'] == true)
                                ? 'Disponible'
                                : 'Indisponible',
                            style: TextStyle(
                              color: (pro['available'] == true)
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
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final loc = AppLocalizations.of(context);
        final isDarkModal =
            Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              color: isDarkModal
                  ? const Color(0xFF1E293B)
                  : Colors.white,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.translate('filters_and_sort'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDarkModal
                            ? Colors.white
                            : AppTheme.titleColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      loc.translate('sort_by'),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDarkModal
                            ? Colors.white
                            : AppTheme.titleColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: Text(loc.translate('sort_rating')),
                          selected: _sortBy == 'rating',
                          onSelected: (_) {
                            setModalState(() => _sortBy = 'rating');
                            setState(() {});
                          },
                        ),
                        ChoiceChip(
                          label: Text(loc.translate('sort_price_asc')),
                          selected: _sortBy == 'price_asc',
                          onSelected: (_) {
                            setModalState(
                                () => _sortBy = 'price_asc');
                            setState(() {});
                          },
                        ),
                        ChoiceChip(
                          label:
                              Text(loc.translate('sort_price_desc')),
                          selected: _sortBy == 'price_desc',
                          onSelected: (_) {
                            setModalState(
                                () => _sortBy = 'price_desc');
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Note minimale',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDarkModal
                            ? Colors.white
                            : AppTheme.titleColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Toutes'),
                          selected: _minRating == 0.0,
                          onSelected: (_) {
                            setModalState(() => _minRating = 0.0);
                            setState(() {});
                          },
                        ),
                        ChoiceChip(
                          label: const Text('3.0+'),
                          selected: _minRating == 3.0,
                          onSelected: (_) {
                            setModalState(() => _minRating = 3.0);
                            setState(() {});
                          },
                        ),
                        ChoiceChip(
                          label: const Text('4.0+'),
                          selected: _minRating == 4.0,
                          onSelected: (_) {
                            setModalState(() => _minRating = 4.0);
                            setState(() {});
                          },
                        ),
                        ChoiceChip(
                          label: const Text('4.5+'),
                          selected: _minRating == 4.5,
                          onSelected: (_) {
                            setModalState(() => _minRating = 4.5);
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: Text(
                        loc.translate('only_available_now'),
                        style: TextStyle(
                          color: isDarkModal
                              ? Colors.white
                              : AppTheme.titleColor,
                        ),
                      ),
                      value: _onlyAvailable,
                      activeThumbColor: const Color(0xFF0D544E),
                      onChanged: (val) {
                        setModalState(() => _onlyAvailable = val);
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D544E),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(loc.translate('apply_filters')),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
