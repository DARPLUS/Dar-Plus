import 'package:flutter/material.dart';
import '../core/routing/app_routes.dart';
import '../services/firebase_service.dart';
import '../theme/app_theme.dart';

class PaymentStatusScreen extends StatelessWidget {
  final String paymentId;
  final bool autoSimulateServerResponse;

  const PaymentStatusScreen({
    super.key,
    required this.paymentId,
    this.autoSimulateServerResponse = false,
  });

  @override
  Widget build(BuildContext context) {
    final isLocal = paymentId.startsWith('booking_');
    return Scaffold(
      appBar: AppBar(title: const Text('État du paiement')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: FirebaseService().streamClientBookings(),
              builder: (context, snapshot) {
                Map<String, dynamic>? booking;
                for (final item in snapshot.data ?? <Map<String, dynamic>>[]) {
                  if (item['id'] == paymentId) {
                    booking = item;
                    break;
                  }
                }
                final method = booking?['paymentMethod'] as String?;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.payments_outlined,
                        size: 68, color: AppTheme.tealPrimary),
                    const SizedBox(height: 20),
                    Text(
                      method == 'cash'
                          ? 'Paiement à régler après l’intervention'
                          : 'Réservation enregistrée',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Votre réservation est enregistrée. Le montant sera réglé directement au professionnel après le service. Aucun paiement par carte n’a été effectué dans l’application.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (isLocal)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          'Mode local : les données ne sont pas synchronisées avec Firebase.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(height: 28),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
                        AppRoutes.bookings,
                        (route) => route.settings.name == AppRoutes.home,
                      ),
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: const Text('Voir mes réservations'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).popUntil(
                        (route) => route.settings.name == AppRoutes.home || route.isFirst,
                      ),
                      child: const Text('Retour à l’accueil'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
