import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/firebase_service.dart';

class AdminRequestsScreen extends StatefulWidget {
  const AdminRequestsScreen({super.key});

  @override
  State<AdminRequestsScreen> createState() => _AdminRequestsScreenState();
}

class _AdminRequestsScreenState extends State<AdminRequestsScreen> {
  String _selectedFilter = 'toutes';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C5050),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Administration DAR PLUS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Demandes de création de compte Pro',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Row(
              children: [
                _buildFilterChip('toutes', 'Toutes les demandes'),
                const SizedBox(width: 8),
                _buildFilterChip('en_attente', 'En attente'),
                const SizedBox(width: 8),
                _buildFilterChip('valide', 'Validées'),
              ],
            ),
          ),

          // Real-time Applications Stream from Firebase
          Expanded(
            child: StreamBuilder<List<ProApplication>>(
              stream: FirebaseService().streamProApplications(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.tealPrimary,
                    ),
                  );
                }

                var list = snapshot.data ?? [];

                if (_selectedFilter != 'toutes') {
                  list = list.where((a) => a.status == _selectedFilter).toList();
                }

                if (list.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.inbox_rounded,
                            size: 64,
                            color: Colors.grey.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Aucune demande pour le moment',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.titleColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Les demandes soumises par les professionnels apparaîtront ici instantanément.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.subtitleColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final app = list[index];
                    return _buildApplicationCard(app);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filterId, String label) {
    final isSelected = _selectedFilter == filterId;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = filterId;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF0C5050)
              : const Color(0xFFF1EDE6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF5A6B82),
          ),
        ),
      ),
    );
  }

  Widget _buildApplicationCard(ProApplication app) {
    Color statusColor;
    String statusLabel;

    switch (app.status) {
      case 'valide':
        statusColor = const Color(0xFF10B981);
        statusLabel = 'Compte Validé';
        break;
      case 'refuse':
        statusColor = const Color(0xFFEF4444);
        statusLabel = 'Refusé';
        break;
      default:
        statusColor = AppTheme.orangePrimary;
        statusLabel = 'En attente d\'approbation';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
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
        children: [
          // Header: Name + Status Badge
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFF0C5050).withValues(alpha: 0.12),
                child: Text(
                  app.fullName.isNotEmpty ? app.fullName[0].toUpperCase() : 'P',
                  style: const TextStyle(
                    color: Color(0xFF0C5050),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.fullName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.titleColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Reçue le ${app.createdAt.day.toString().padLeft(2, '0')}/${app.createdAt.month.toString().padLeft(2, '0')}/${app.createdAt.year} à ${app.createdAt.hour}h${app.createdAt.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),

          const Divider(height: 24, color: Color(0xFFF1ECE4)),

          // Service requested
          Row(
            children: [
              const Icon(Icons.build_rounded, size: 16, color: Color(0xFF0C5050)),
              const SizedBox(width: 8),
              Text(
                'Métier : ${app.serviceType}',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.titleColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Phone
          Row(
            children: [
              const Icon(Icons.phone_rounded, size: 16, color: Color(0xFF64748B)),
              const SizedBox(width: 8),
              Text(
                'Téléphone : ${app.phone}',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF475569),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Email
          Row(
            children: [
              const Icon(Icons.mail_outline_rounded, size: 16, color: Color(0xFF64748B)),
              const SizedBox(width: 8),
              Text(
                'Email : ${app.email}',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF475569),
                ),
              ),
            ],
          ),

          // Actions
          if (app.status == 'en_attente') ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await FirebaseService().approveProApplication(app.id);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Compte de ${app.fullName} validé avec succès !'),
                            backgroundColor: const Color(0xFF10B981),
                          ),
                        );
                        setState(() {});
                      }
                    },
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Valider le compte'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () async {
                    await FirebaseService().rejectProApplication(app.id);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Demande de ${app.fullName} refusée.'),
                          backgroundColor: const Color(0xFFEF4444),
                        ),
                      );
                      setState(() {});
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    side: const BorderSide(color: Color(0xFFEF4444)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Refuser'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
