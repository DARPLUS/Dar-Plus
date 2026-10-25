import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import '../services/firebase_service.dart';

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

class _ProHomeScreenState extends State<ProHomeScreen> {
  bool _isAvailable = true;
  int _currentBottomNavIndex = 0;

  // Interventions data matching screenshot
  final List<Map<String, dynamic>> _interventions = [
    {
      'client': 'Ahmed Ben Salah',
      'time': '10:00',
      'location': 'El Menzah 9',
      'price': '120 TND',
      'status': 'Confirmé',
      'statusBg': Color(0xFFE0F2FE),
      'statusColor': Color(0xFF0284C7),
      'avatarAsset': 'assets/images/slide_1_photo.png',
      'phone': '+216 98 123 456',
      'service': 'Réparation fuite d\'eau salle de bain',
    },
    {
      'client': 'Sonia Mansouri',
      'time': '14:30',
      'location': 'La Marsa',
      'price': '80 TND',
      'status': 'En route',
      'statusBg': Color(0xFFFEF3C7),
      'statusColor': Color(0xFFD97706),
      'avatarAsset': 'assets/images/slide_2_photo.png',
      'phone': '+216 22 789 012',
      'service': 'Remplacement mitigeur cuisine',
    },
    {
      'client': 'Karim Belhaj',
      'time': '17:00',
      'location': 'Ariana',
      'price': '150 TND',
      'status': 'En attente',
      'statusBg': Color(0xFFF3E8FF),
      'statusColor': Color(0xFF9333EA),
      'avatarAsset': 'assets/images/slide_3_photo.png',
      'phone': '+216 55 345 678',
      'service': 'Installation chauffe-eau électrique',
    },
  ];

  // New pending requests data
  final List<Map<String, dynamic>> _pendingRequests = [
    {
      'client': 'Yasmine Dridi',
      'location': 'Les Berges du Lac 2',
      'time': 'Demain • 09:30',
      'price': '90 TND',
      'service': 'Changement canalisation lavabo',
      'avatarAsset': 'assets/images/slide_1_photo.png',
    },
    {
      'client': 'Mehdi Ben Romdhane',
      'location': 'Ennasr 2',
      'time': 'Demain • 14:00',
      'price': '110 TND',
      'service': 'Débouchage colonne générale',
      'avatarAsset': 'assets/images/slide_2_photo.png',
    },
  ];

  @override
  Widget build(BuildContext context) {
    const bgCream = Color(0xFFFAF7F2);
    const orangeAccent = Color(0xFFE05D38);

    return Scaffold(
      backgroundColor: bgCream,
      body: SafeArea(
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

                    const SizedBox(height: 14),

                    // Alert / Notification Banner (2 nouvelles demandes!)
                    _buildNotificationBanner(context),

                    const SizedBox(height: 20),

                    // Section Interventions d'aujourd'hui
                    _buildInterventionsSection(context),

                    const SizedBox(height: 20),

                    // Section Performance cette semaine (matching screenshot 2)
                    _buildPerformanceCard(),

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
        color: Color(0xFF0F2D2A),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
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
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/images/slide_1_photo.png',
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 50,
                        height: 50,
                        color: const Color(0xFF163E3A),
                        child: const Icon(Icons.person, color: Colors.white),
                      ),
                    ),
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
                          color: const Color(0xFF0F2D2A),
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
                      'Bonjour,',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          widget.proName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          '✌',
                          style: TextStyle(fontSize: 18),
                        ),
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
              border: Border.all(
                color: const Color(0xFF156554),
                width: 1.2,
              ),
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
                            ? 'Vous êtes disponible'
                            : 'Vous êtes indisponible',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isAvailable
                            ? 'Les clients peuvent vous contacter'
                            : 'Vous ne recevez pas de demandes',
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
                  onChanged: (val) {
                    setState(() {
                      _isAvailable = val;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          val
                              ? 'Statut: Vous êtes maintenant Disponible !'
                              : 'Statut: Vous êtes maintenant Hors ligne.',
                        ),
                        backgroundColor: val
                            ? const Color(0xFF0E4B3E)
                            : Colors.grey.shade800,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 3 Stat KPI Cards in a row (1690 TND, 3 Aujourd'hui, 4.9/5 Note)
          Row(
            children: [
              Expanded(
                child: _buildDarkStatCard(
                  icon: Icons.savings_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  value: '1690 TND',
                  label: 'Ce mois',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDarkStatCard(
                  icon: Icons.check_box_rounded,
                  iconColor: const Color(0xFF10B981),
                  value: '3',
                  label: 'Aujourd\'hui',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDarkStatCard(
                  icon: Icons.star_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  value: '4.9/5',
                  label: 'Note',
                ),
              ),
            ],
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
        color: const Color(0xFF163F3C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
        ),
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
            label: 'Demandes',
            badgeCount: 2,
            onTap: () => _showPendingRequestsSheet(context),
          ),
        ),
        const SizedBox(width: 10),
        // 2. Dispo.
        Expanded(
          child: _buildActionCard(
            context: context,
            icon: Icons.calendar_month_rounded,
            iconColor: const Color(0xFF3B82F6),
            label: 'Dispo.',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Gestion des disponibilités et plannings ouverte'),
                  backgroundColor: Color(0xFF0F2D2A),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        // 3. Messages (with badge 3)
        Expanded(
          child: _buildActionCard(
            context: context,
            icon: Icons.chat_bubble_outline_rounded,
            iconColor: const Color(0xFF8B5CF6),
            label: 'Messages',
            badgeCount: 3,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('3 nouveaux messages de clients'),
                  backgroundColor: Color(0xFF0F2D2A),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        // 4. Revenus
        Expanded(
          child: _buildActionCard(
            context: context,
            icon: Icons.monetization_on_outlined,
            iconColor: const Color(0xFFF59E0B),
            label: 'Revenus',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Détails des gains et virements bancaires'),
                  backgroundColor: Color(0xFF0F2D2A),
                ),
              );
            },
          ),
        ),
      ],
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 78,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFEFE8DE)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
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
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
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
    return GestureDetector(
      onTap: () => _showPendingRequestsSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2E8),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFFFCDCC5),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFFFEE0CB),
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
                  const Text(
                    '2 nouvelles demandes!',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE05D38),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Répondez vite pour ne pas les perdre',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF78716C),
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
  }

  // ─── 4. INTERVENTIONS D'AUJOURD'HUI ─────────────────────────────────────────
  Widget _buildInterventionsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Text(
                  '📅',
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(width: 8),
                Text(
                  'Interventions d\'aujourd\'hui',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Affichage de tout le calendrier d\'interventions'),
                    backgroundColor: Color(0xFF0F2D2A),
                  ),
                );
              },
              child: const Text(
                'Voir tout',
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
        // Interventions list
        ..._interventions.map((item) => _buildInterventionCard(context, item)),
      ],
    );
  }

  Widget _buildInterventionCard(
      BuildContext context, Map<String, dynamic> item) {
    return GestureDetector(
      onTap: () => _showInterventionDetails(context, item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFEFE8DE)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
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
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text(
                        '⏰',
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        item['time'],
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        '•',
                        style: TextStyle(color: Color(0xFF94A3B8)),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        '📍',
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          item['location'],
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
  Widget _buildPerformanceCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEFE8DE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text(
                '📊',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(width: 8),
              Text(
                'Performance cette semaine',
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 1. Taux d'acceptation
          _buildPerformanceBar(
            title: 'Taux d\'acceptation',
            valueText: '94%',
            valueColor: const Color(0xFF10B981),
            progress: 0.94,
            barColor: const Color(0xFF10B981),
          ),
          const SizedBox(height: 14),

          // 2. Ponctualité
          _buildPerformanceBar(
            title: 'Ponctualité',
            valueText: '98%',
            valueColor: const Color(0xFF0284C7),
            progress: 0.98,
            barColor: const Color(0xFF0284C7),
          ),
          const SizedBox(height: 14),

          // 3. Satisfaction client
          _buildPerformanceBar(
            title: 'Satisfaction client',
            valueText: '4.9/5',
            valueColor: const Color(0xFFF59E0B),
            progress: 0.98,
            barColor: const Color(0xFFF59E0B),
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
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
              ),
            ),
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
            backgroundColor: const Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }

  // ─── 6. BOTTOM NAVIGATION BAR (matching screenshot) ────────────────────────
  Widget _buildBottomNavigationBar(Color orangeAccent) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
        backgroundColor: Colors.white,
        selectedItemColor: orangeAccent,
        unselectedItemColor: const Color(0xFF64748B),
        selectedLabelStyle: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 11,
        ),
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_rounded),
            label: 'Tableau',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_rounded),
            label: 'Demandes',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.chat_bubble_outline_rounded),
                Positioned(
                  top: -2,
                  right: -4,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE05D38),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
            label: 'Messages',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.attach_money_rounded),
            label: 'Revenus',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            label: 'Compte',
          ),
        ],
      ),
    );
  }

  // ─── 7. MODALS & DIALOGS ───────────────────────────────────────────────────
  void _showInterventionDetails(
      BuildContext context, Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                      color: const Color(0xFFE2DDD5),
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
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.titleColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item['service'],
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.subtitleColor,
                            ),
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
                    color: const Color(0xFFFAF7F2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded,
                              size: 18, color: Color(0xFF0F2D2A)),
                          const SizedBox(width: 8),
                          Text('Horaire prévu : Aujourd\'hui à ${item['time']}'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded,
                              size: 18, color: Color(0xFFE05D38)),
                          const SizedBox(width: 8),
                          Text('Adresse : ${item['location']}'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.phone_rounded,
                              size: 18, color: Color(0xFF10B981)),
                          const SizedBox(width: 8),
                          Text('Téléphone : ${item['phone']}'),
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
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Appel vers ${item['client']}...'),
                              backgroundColor: const Color(0xFF0F2D2A),
                            ),
                          );
                        },
                        icon: const Icon(Icons.phone_in_talk_rounded, size: 18),
                        label: const Text('Appeler'),
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Navigation GPS vers ${item['location']} lancée !'),
                              backgroundColor: const Color(0xFF10B981),
                            ),
                          );
                        },
                        icon: const Icon(Icons.navigation_rounded, size: 18),
                        label: const Text('Itinéraire'),
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                      color: const Color(0xFFE2DDD5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const Text(
                  'Nouvelles demandes en attente',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 14),
                ..._pendingRequests.map(
                  (req) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF7F2),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFEFE8DE)),
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
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  Text(
                                    '${req['time']} • ${req['location']}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
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
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Demande de ${req['client']} refusée.'),
                                    ),
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.grey.shade700,
                                  side: BorderSide(color: Colors.grey.shade300),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('Décliner'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Demande de ${req['client']} acceptée !'),
                                      backgroundColor: const Color(0xFF10B981),
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
                                child: const Text('Accepter'),
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

  void _showNotificationsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.notifications_active_rounded, color: Color(0xFFE05D38)),
            SizedBox(width: 8),
            Text('Notifications Pro'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• 2 nouvelles demandes d\'intervention reçues aujourd\'hui.'),
            SizedBox(height: 8),
            Text('• Paiement de 120 TND validé pour l\'intervention d\'hier.'),
            SizedBox(height: 8),
            Text('• Félicitations : votre note moyenne a atteint 4.9/5 !'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer', style: TextStyle(color: Color(0xFF0F2D2A))),
          ),
        ],
      ),
    );
  }

  void _showSettingsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(22),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
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
                  color: const Color(0xFFE2DDD5),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.person_outline_rounded, color: Color(0xFF0F2D2A)),
                title: const Text('Modifier mon profil professionnel'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.attach_money_rounded, color: Color(0xFF0F2D2A)),
                title: const Text('Tarifs et spécialités'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.lock_reset_rounded, color: Color(0xFF0F2D2A)),
                title: const Text('Sécurité & Mot de passe'),
                onTap: () {
                  Navigator.pop(context);
                  _showChangePasswordDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                title: const Text('Se déconnecter', style: TextStyle(color: Colors.redAccent)),
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
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            title: const Row(
              children: [
                Icon(Icons.lock_reset_rounded, color: Color(0xFF0F2D2A), size: 24),
                SizedBox(width: 10),
                Text('Sécurité & Mot de passe',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Modifiez directement votre mot de passe professionnel DAR PLUS.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 16),
                    if (errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
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
                        labelText: 'Mot de passe actuel',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(obscureCurrent ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Mot de passe actuel requis' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: newPassCtrl,
                      obscureText: obscureNew,
                      decoration: InputDecoration(
                        labelText: 'Nouveau mot de passe',
                        prefixIcon: const Icon(Icons.key_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Nouveau mot de passe requis';
                        if (v.trim().length < 6) return 'Minimum 6 caractères';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: confirmPassCtrl,
                      obscureText: obscureConfirm,
                      decoration: InputDecoration(
                        labelText: 'Confirmer le mot de passe',
                        prefixIcon: const Icon(Icons.key_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      validator: (v) {
                        if (v != newPassCtrl.text) return 'Les mots de passe ne correspondent pas';
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
                child: const Text('Annuler', style: TextStyle(color: Color(0xFF64748B))),
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
                              content: Text(result['message'] as String),
                              backgroundColor: const Color(0xFF0F2D2A),
                            ),
                          );
                        } else {
                          setDialogState(() {
                            isSaving = false;
                            errorMessage = result['message'] as String?;
                          });
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F2D2A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Mettre à jour'),
              ),
            ],
          );
        },
      ),
    );
  }
}
