import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../theme/app_theme.dart';

class PaymentHistoryScreen extends StatelessWidget {
  const PaymentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historique des paiements')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: FirebaseService().streamClientBookings(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = (snapshot.data ?? [])
              .where((booking) => booking['paymentMethod'] != null)
              .toList();

          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.receipt_long_outlined,
                        size: 56, color: AppTheme.subtitleColor),
                    const SizedBox(height: 14),
                    Text('Aucun paiement enregistré pour le moment.',
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              final paid = item['paymentStatus'] == 'paye';
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF0D544E).withValues(alpha: .1),
                    child: const Icon(Icons.payments_outlined,
                        color: AppTheme.tealPrimary),
                  ),
                  title: Text(item['serviceType'] as String? ?? 'Service'),
                  subtitle: Text(
                    '${item['proName'] ?? 'Professionnel'} · ${paid ? 'Payé' : 'À régler sur place'}',
                  ),
                  trailing: Text(item['price'] as String? ?? ''),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
