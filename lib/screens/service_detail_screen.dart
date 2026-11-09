import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../core/localization/app_localizations.dart';
import '../services/firebase_service.dart';

class ServiceDetailScreen extends StatelessWidget {
  final Map<String, dynamic> proData;

  const ServiceDetailScreen({
    super.key,
    required this.proData,
  });

  @override
  Widget build(BuildContext context) {
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
                  child: const Icon(Icons.favorite_border_rounded, color: Colors.white, size: 20),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$name ajouté à vos favoris !'),
                      backgroundColor: const Color(0xFF10B981),
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
                    child: Image.asset(
                      proData['avatarAsset'] ?? 'assets/images/slide_1_photo.png',
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: const Color(0xFF0D544E),
                        child: const Icon(Icons.person_rounded, size: 80, color: Colors.white),
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
                  _buildReviewCard(
                    author: 'Inès Ben Amor',
                    date: 'Il y a 3 jours',
                    rating: 5.0,
                    comment: 'Intervention impeccable et très ponctuel. Travail soigné et très propre ! Je recommande vivement.',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  _buildReviewCard(
                    author: 'Tarek Chaabane',
                    date: 'La semaine dernière',
                    rating: 4.8,
                    comment: 'Très bon artisan, diagnostic rapide et tarif conforme à ce qui était annoncé.',
                    isDark: isDark,
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
    String scheduledDate = 'Dès que possible';
    bool isSubmitting = false;

    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Réserver $serviceType',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppTheme.titleColor,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Artisan : $proName • Tarif : $price',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: addressCtrl,
                    decoration: InputDecoration(
                      labelText: 'Adresse d\'intervention',
                      hintText: 'Ex: Rue Habib Bourguiba, La Marsa',
                      prefixIcon: const Icon(Icons.home_work_rounded, color: Color(0xFF0D544E)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Description du besoin',
                      hintText: 'Ex: Fuite sous évier cuisine à réparer...',
                      prefixIcon: const Icon(Icons.description_rounded, color: Color(0xFF0D544E)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(Icons.event_rounded, color: Color(0xFF0D544E), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Date : $scheduledDate',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: modalContext,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 90)),
                          );
                          if (picked != null) {
                            setModalState(() {
                              scheduledDate = '${picked.day}/${picked.month}/${picked.year}';
                            });
                          }
                        },
                        child: const Text('Modifier', style: TextStyle(color: Color(0xFF0D544E))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D544E),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final address = addressCtrl.text.trim();
                              if (address.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Veuillez renseigner une adresse'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }

                              setModalState(() {
                                isSubmitting = true;
                              });

                              final proId = proData['id'] ?? proData['uid'] ?? 'pro_${proData['name']}';
                              final proPhone = proData['phone'] ?? '';

                              final res = await FirebaseService().createBooking(
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
                                            ? 'Demande de réservation envoyée avec succès !'
                                            : 'Erreur lors de la réservation'),
                                  ),
                                  backgroundColor: isSuccess ? const Color(0xFF10B981) : Colors.red,
                                ),
                              );
                            },
                      child: isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Text(
                              'Confirmer la réservation',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
