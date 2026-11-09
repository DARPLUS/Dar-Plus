import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/locale_provider.dart';
import '../core/localization/app_localizations.dart';
import '../services/firebase_service.dart';
import '../widgets/pro_avatar_widget.dart';
import 'checkout_screen.dart';

class ServiceDetailScreen extends StatefulWidget {
  final Map<String, dynamic> proData;

  const ServiceDetailScreen({
    super.key,
    required this.proData,
  });

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  bool _isFav = false;

  @override
  void initState() {
    super.initState();
    final proId = (widget.proData['id'] ?? widget.proData['uid'] ?? 'pro_${widget.proData['name']}').toString();
    FirebaseService().isFavorite(proId).then((val) {
      if (mounted) setState(() => _isFav = val);
    });
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
    final price = proData['price'] ?? '35 TND/h';
    final rating = proData['rating'] ?? 4.8;
    final reviewsCount = proData['reviewsCount'] ?? 15;
    final location = proData['location'] ?? 'Grand Tunis';
    final distance = proData['distance'] ?? '2.0 km';
    final phone = proData['phone'] ?? '+216 71 000 000';
    final bio = proData['bio'] ??
        'Professionnel qualifié et vérifié par DAR PLUS pour toutes vos interventions à domicile.';
    final specialties = (proData['specialties'] as List<dynamic>?) ??
        [serviceType, 'Intervention rapide', 'Devis gratuit'];
    final badges = (proData['badges'] as List<dynamic>?) ?? ['Vérifié DAR+'];
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
                child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
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
                    _isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: _isFav ? const Color(0xFFEF4444) : Colors.white,
                    size: 20,
                  ),
                ),
                onPressed: () async {
                  final newStatus = await FirebaseService().toggleFavorite(widget.proData);
                  if (!mounted) return;
                  setState(() => _isFav = newStatus);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(newStatus
                          ? '$name ajouté à vos favoris !'
                          : '$name retiré de vos favoris.'),
                      backgroundColor: newStatus ? const Color(0xFF10B981) : Colors.grey.shade700,
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
                        size: 280,
                        borderRadius: 0,
                        showVerifiedBadge: false,
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
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isAvailable
                                    ? const Color(0xFF10B981)
                                    : Colors.grey.shade600,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isAvailable ? 'Disponible aujourd\'hui' : 'Indisponible',
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
                            const Icon(Icons.location_on_rounded, color: Colors.white70, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '$location • à $distance',
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
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
                        color: isDark ? Colors.transparent : const Color(0xFFEDE8E1),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem('Note globale', '$rating ★', Colors.amber),
                        _buildVerticalDivider(isDark),
                        _buildStatItem('Avis clients', '$reviewsCount', Colors.blue),
                        _buildVerticalDivider(isDark),
                        _buildStatItem('Tarif horaire', price, const Color(0xFFDE6D1B)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Badges
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: badges.map((badge) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0D544E).withValues(alpha: 0.25) : const Color(0xFFD7F3EA),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF0D544E).withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF0D544E)),
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
                    'À propos du professionnel',
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
                      color: isDark ? Colors.grey.shade300 : AppTheme.subtitleColor,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Prestations & Spécialités
                  Text(
                    'Prestations & Compétences',
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
                            child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '$spec',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : AppTheme.titleColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 24),

                  // Avis Clients récents
                  Text(
                    'Derniers avis clients',
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
                        return const Center(child: CircularProgressIndicator(color: Color(0xFF0D544E)));
                      }
                      final reviews = snapshot.data ?? [];
                      if (reviews.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? Colors.transparent : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.rate_review_outlined, color: Colors.grey.shade400, size: 28),
                              const SizedBox(width: 12),
                              Text(
                                'Aucun avis pour le moment',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return Column(
                        children: reviews.map((review) {
                          final author = review['clientName'] as String? ?? 'Client';
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
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Appel vers $phone...'),
                      backgroundColor: const Color(0xFF0D544E),
                    ),
                  );
                },
                icon: const Icon(Icons.phone_in_talk_rounded, size: 20),
                label: const Text('Appeler'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0D544E),
                  side: const BorderSide(color: Color(0xFF0D544E), width: 1.5),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),

              const SizedBox(width: 12),

              // Book Now Button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    _showBookingSheet(context, name, serviceType, price);
                  },
                  icon: const Icon(Icons.calendar_month_rounded, size: 20),
                  label: Text(
                    loc.translate('book_now'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D544E),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
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
                  Text('$rating', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(date, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
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
      BuildContext context, String proName, String serviceType, String price) {
    final addressCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    // 0 = Dès que possible, 1 = Demain matin, 2 = Choisir une date
    int selectedSlot = 0;
    String customDate = '';
    String customTime = '';
    String? addressError;
    bool isLocating = false;
    bool isSubmitting = false;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    String buildScheduledDate() {
      if (selectedSlot == 0) return loc.translate('slot_asap');
      if (selectedSlot == 1) return loc.translate('slot_tomorrow_morning');
      if (customDate.isNotEmpty && customTime.isNotEmpty) {
        return '$customDate · $customTime';
      }
      if (customDate.isNotEmpty) return customDate;
      return loc.translate('slot_choose_date');
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
                                  color: isDark ? Colors.white : AppTheme.titleColor,
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
                          onPressed:
                              isSubmitting ? null : () => Navigator.pop(ctx),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ── Créneaux rapides ─────────────────────────────
                    Text(
                      loc.translate('booking_date'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppTheme.titleColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _SlotChip(
                          label: loc.translate('slot_asap'),
                          icon: Icons.flash_on_rounded,
                          isSelected: selectedSlot == 0,
                          onTap: () =>
                              setModalState(() => selectedSlot = 0),
                        ),
                        const SizedBox(width: 8),
                        _SlotChip(
                          label: loc.translate('slot_tomorrow_morning'),
                          icon: Icons.wb_sunny_rounded,
                          isSelected: selectedSlot == 1,
                          onTap: () =>
                              setModalState(() => selectedSlot = 1),
                        ),
                        const SizedBox(width: 8),
                        _SlotChip(
                          label: loc.translate('slot_choose_date'),
                          icon: Icons.calendar_month_rounded,
                          isSelected: selectedSlot == 2,
                          onTap: () async {
                            setModalState(() => selectedSlot = 2);
                            final picked = await showDatePicker(
                              context: modalContext,
                              initialDate:
                                  DateTime.now().add(const Duration(days: 1)),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now()
                                  .add(const Duration(days: 90)),
                              builder: (ctx, child) => Theme(
                                data: Theme.of(ctx).copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: Color(0xFF0D544E),
                                  ),
                                ),
                                child: child!,
                              ),
                            );
                            if (picked != null && modalContext.mounted) {
                              final days = [
                                'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'
                              ];
                              final months = [
                                'jan', 'fév', 'mar', 'avr', 'mai', 'jun',
                                'jul', 'aoû', 'sep', 'oct', 'nov', 'déc'
                              ];
                              final d = '${days[picked.weekday - 1]} ${picked.day} ${months[picked.month - 1]}';
                              final time = await showTimePicker(
                                context: modalContext,
                                initialTime: const TimeOfDay(hour: 9, minute: 0),
                                builder: (ctx, child) => Theme(
                                  data: Theme.of(ctx).copyWith(
                                    colorScheme: const ColorScheme.light(
                                      primary: Color(0xFF0D544E),
                                    ),
                                  ),
                                  child: child!,
                                ),
                              );
                              setModalState(() {
                                customDate = d;
                                customTime = time != null
                                    ? '${time.hour.toString().padLeft(2, '0')}h${time.minute.toString().padLeft(2, '0')}'
                                    : '';
                              });
                            }
                          },
                        ),
                      ],
                    ),

                    // Affichage date sélectionnée
                    if (selectedSlot == 2 && customDate.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D544E).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.event_available_rounded,
                                size: 16, color: Color(0xFF0D544E)),
                            const SizedBox(width: 6),
                            Text(
                              '$customDate${customTime.isNotEmpty ? " · $customTime" : ""}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0D544E),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // ── Adresse ──────────────────────────────────────
                    TextField(
                      controller: addressCtrl,
                      onChanged: (_) {
                        if (addressError != null) {
                          setModalState(() => addressError = null);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: loc.translate('intervention_address'),
                        hintText: loc.translate('address_hint'),
                        prefixIcon: const Icon(Icons.home_work_rounded,
                            color: Color(0xFF0D544E)),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14)),
                        errorText: addressError,
                        suffixIcon: isLocating
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF0D544E)),
                                ),
                              )
                            : IconButton(
                                tooltip: 'Utiliser ma localisation',
                                icon: const Icon(Icons.my_location_rounded,
                                    color: Color(0xFF0D544E)),
                                onPressed: () async {
                                  setModalState(() => isLocating = true);
                                  try {
                                    // Charger l'adresse depuis le profil
                                    final userData = await FirebaseService()
                                        .getCurrentUserData();
                                    String detected = '';
                                    if (userData != null) {
                                      final addr =
                                          userData['address'] as String?;
                                      final city =
                                          userData['city'] as String?;
                                      final phone =
                                          userData['phone'] as String?;
                                      if (addr != null && addr.isNotEmpty) {
                                        detected = addr;
                                      } else if (city != null &&
                                          city.isNotEmpty) {
                                        detected = city;
                                      } else if (phone != null) {
                                        detected = 'Tunis, Tunisie';
                                      }
                                    }
                                    // Web : tenter la géolocalisation navigateur
                                    if (kIsWeb && detected.isEmpty) {
                                      detected =
                                          'Localisation détectée — veuillez préciser la rue';
                                    }
                                    if (detected.isEmpty) {
                                      detected = 'Tunis, Tunisie';
                                    }
                                    setModalState(() {
                                      addressCtrl.text = detected;
                                      isLocating = false;
                                      addressError = null;
                                    });
                                  } catch (_) {
                                    setModalState(() => isLocating = false);
                                  }
                                },
                              ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── Description ──────────────────────────────────
                    TextField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: loc.translate('need_description'),
                        hintText: loc.translate('description_hint'),
                        prefixIcon: const Icon(Icons.description_rounded,
                            color: Color(0xFF0D544E)),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14)),
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
                                    color: Colors.white, strokeWidth: 2.5),
                              )
                            : Text(
                                loc.translate('confirm_booking'),
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D544E),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final address = addressCtrl.text.trim();
                                if (address.length < 10) {
                                  setModalState(() => addressError =
                                      loc.translate('address_too_short'));
                                  return;
                                }

                                // ── Récapitulatif ────────────────────
                                final scheduledDate = buildScheduledDate();
                                final confirmed = await showDialog<bool>(
                                  context: modalContext,
                                  builder: (dCtx) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(20)),
                                    title: Row(children: [
                                      const Icon(
                                          Icons.receipt_long_rounded,
                                          color: Color(0xFF0D544E),
                                          size: 22),
                                      const SizedBox(width: 8),
                                      Text(
                                        loc.translate('booking_recap'),
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ]),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _RecapRow(
                                            icon: Icons.person_rounded,
                                            label: loc.translate('booking_pro'),
                                            value: proName),
                                        _RecapRow(
                                            icon: Icons.build_rounded,
                                            label: 'Service',
                                            value: serviceType),
                                        _RecapRow(
                                            icon: Icons.schedule_rounded,
                                            label: loc.translate('booking_date'),
                                            value: scheduledDate),
                                        _RecapRow(
                                            icon: Icons.location_on_rounded,
                                            label:
                                                loc.translate('booking_address'),
                                            value: address),
                                        _RecapRow(
                                            icon: Icons.payments_rounded,
                                            label: 'Tarif',
                                            value: price),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dCtx, false),
                                        child: Text(
                                          'Modifier',
                                          style: TextStyle(
                                              color: AppTheme.subtitleColorOf(
                                                  context)),
                                        ),
                                      ),
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.pop(dCtx, true),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFF0D544E),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                        ),
                                        child: Text(
                                            loc.translate('confirm')),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirmed != true) return;
                                if (!modalContext.mounted) return;

                                setModalState(() => isSubmitting = true);

                                final proId = widget.proData['id'] ??
                                    widget.proData['uid'] ??
                                    'pro_${widget.proData['name']}';
                                final proPhone = widget.proData['phone'] ?? '';

                                final res =
                                    await FirebaseService().createBooking(
                                  proId: proId.toString(),
                                  proName: proName,
                                  proPhone: proPhone.toString(),
                                  serviceType: serviceType,
                                  price: price,
                                  address: address,
                                  description: descCtrl.text.trim(),
                                  scheduledDate: scheduledDate,
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
                                                  'booking_sent_success')
                                              : loc.translate('error')),
                                    ),
                                    backgroundColor: isSuccess
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFDC2626),
                                  ),
                                );

                                if (isSuccess && res['id'] != null && context.mounted) {
                                  final numMatch = RegExp(r'(\d+([.,]\d+)?)').firstMatch(price);
                                  final double parsedBase = numMatch != null
                                      ? double.tryParse(numMatch.group(1)!.replaceAll(',', '.')) ?? 45.0
                                      : 45.0;

                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => CheckoutScreen(
                                        bookingId: res['id'].toString(),
                                        proId: proId.toString(),
                                        proName: proName,
                                        serviceType: serviceType,
                                        baseAmount: parsedBase,
                                        address: address,
                                        scheduledDate: scheduledDate,
                                      ),
                                    ),
                                  );
                                }
                              },
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

// ── Widgets helpers pour le booking sheet ────────────────────────────────────

class _SlotChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _SlotChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF0D544E)
                : (isDark ? const Color(0xFF1E293B) : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF0D544E)
                  : (isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFDDE3EA)),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? Colors.white
                    : const Color(0xFF0D544E),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : (isDark
                          ? const Color(0xFF94A3B8)
                          : AppTheme.titleColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecapRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _RecapRow(
      {required this.icon, required this.label, required this.value});

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
                Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.subtitleColorOf(context))),
                Text(value,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
