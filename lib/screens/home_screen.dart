import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'register_screen.dart';
import 'admin_requests_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = [
      {'title': 'Bricolage & Travaux', 'icon': Icons.build_rounded, 'color': AppTheme.tealPrimary},
      {'title': 'Ménage & Nettoyage', 'icon': Icons.cleaning_services_rounded, 'color': AppTheme.orangePrimary},
      {'title': 'Cuisine & Chef', 'icon': Icons.restaurant_rounded, 'color': const Color(0xFFD35400)},
      {'title': 'Plomberie', 'icon': Icons.plumbing_rounded, 'color': const Color(0xFF2980B9)},
      {'title': 'Électricité', 'icon': Icons.bolt_rounded, 'color': const Color(0xFFF39C12)},
      {'title': 'Jardinage', 'icon': Icons.yard_rounded, 'color': const Color(0xFF27AE60)},
    ];

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: AppTheme.tealPrimary,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Text(
                'D+',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'DAR PLUS',
              style: TextStyle(
                color: AppTheme.titleColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          // Admin panel button
          IconButton(
            tooltip: 'Espace Admin',
            icon: const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF0C5050)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminRequestsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, color: AppTheme.titleColor),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.tealPrimary, Color(0xFF0C5050)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.tealPrimary.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bienvenue sur DAR PLUS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Trouvez les meilleurs prestataires vérifiés en un clic pour votre foyer.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Search bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.search_rounded, color: AppTheme.subtitleColor),
                        SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Quel service recherchez-vous ?',
                              hintStyle: TextStyle(
                                color: AppTheme.subtitleColor,
                                fontSize: 13,
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

            const SizedBox(height: 20),

            // Devenir professionnel banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE8834F).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFE8834F).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: AppTheme.orangePrimary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.handyman_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vous êtes un professionnel ?',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.titleColor,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Rejoignez notre réseau d\'experts qualifiés',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.subtitleColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RegisterScreen(
                            initialType: AccountType.professionnel,
                          ),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.orangePrimary,
                      textStyle: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    child: const Text('Postuler'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Services header
            const Text(
              'Nos Catégories',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.titleColor,
              ),
            ),
            const SizedBox(height: 16),
            // Services grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.15,
              ),
              itemCount: services.length,
              itemBuilder: (context, index) {
                final s = services[index];
                final color = s['color'] as Color;
                final icon = s['icon'] as IconData;
                final title = s['title'] as String;

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(icon, color: color, size: 26),
                      ),
                      const Spacer(),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.titleColor,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
