import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

class ProHomeScreen extends StatefulWidget {
  final String proName;
  final String serviceType;

  const ProHomeScreen({
    super.key,
    this.proName = 'Ahmed Ben Salah',
    this.serviceType = 'Plomberie & Sanitaire',
  });

  @override
  State<ProHomeScreen> createState() => _ProHomeScreenState();
}

class _ProHomeScreenState extends State<ProHomeScreen> {
  bool _isAvailable = true;

  final List<Map<String, String>> _availableMissions = [
    {
      'client': 'Sonia Mansour',
      'location': 'Les Berges du Lac 2, Tunis',
      'service': 'Réparation fuite d\'eau sous évier',
      'time': 'Aujourd\'hui à 15:00',
      'budget': '65 DT',
    },
    {
      'client': 'Karim Trabelsi',
      'location': 'Ennasr 2, Ariana',
      'service': 'Remplacement mitigeur salle de bain',
      'time': 'Demain à 10:30',
      'budget': '80 DT',
    },
    {
      'client': 'Mouna Ben Ammar',
      'location': 'La Marsa',
      'service': 'Installation chauffe-eau',
      'time': 'Jeudi à 14:00',
      'budget': '120 DT',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C5050),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'D+ PRO',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Espace Partenaire',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Se déconnecter',
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pro profile card & Availability switch
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor:
                            const Color(0xFF0C5050).withValues(alpha: 0.12),
                        child: const Icon(
                          Icons.handyman_rounded,
                          color: Color(0xFF0C5050),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.proName,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.titleColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.serviceType,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.subtitleColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.star_rounded,
                                color: Color(0xFF10B981), size: 16),
                            SizedBox(width: 4),
                            Text(
                              '4.9',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 28, color: Color(0xFFF1ECE4)),
                  // Switch online status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isAvailable
                                  ? const Color(0xFF10B981)
                                  : Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isAvailable
                                ? 'En ligne (Disponible aux missions)'
                                : 'Hors ligne (Occupé)',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: _isAvailable
                                  ? const Color(0xFF10B981)
                                  : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: _isAvailable,
                        activeThumbColor: const Color(0xFF0C5050),
                        onChanged: (val) {
                          setState(() {
                            _isAvailable = val;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // Performance stats
            Row(
              children: [
                Expanded(
                  child: _buildStatCard('Missions', '18', Icons.task_alt_rounded),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                      'Revenus', '1 420 DT', Icons.account_balance_wallet_rounded),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                      'Avis vérifiés', '16', Icons.thumb_up_alt_rounded),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // Mission header
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Missions disponibles',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.titleColor,
                  ),
                ),
                Text(
                  '3 nouvelles',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.orangePrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // List of missions
            ..._availableMissions.map((mission) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          mission['service']!,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.titleColor,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0C5050).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            mission['budget']!,
                            style: const TextStyle(
                              color: Color(0xFF0C5050),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded,
                            size: 15, color: AppTheme.subtitleColor),
                        const SizedBox(width: 4),
                        Text(
                          mission['location']!,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppTheme.subtitleColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.schedule_rounded,
                            size: 15, color: AppTheme.subtitleColor),
                        const SizedBox(width: 4),
                        Text(
                          mission['time']!,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppTheme.subtitleColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Mission acceptée pour ${mission['client']} !'),
                              backgroundColor: const Color(0xFF0C5050),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0C5050),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Accepter la mission',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF0C5050), size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.titleColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.subtitleColor,
            ),
          ),
        ],
      ),
    );
  }
}
