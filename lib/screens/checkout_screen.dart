import 'package:flutter/material.dart';
import '../core/routing/app_routes.dart';
import '../services/firebase_service.dart';
import '../theme/app_theme.dart';

class CheckoutScreen extends StatefulWidget {
  final String bookingId;
  final String proId;
  final String proName;
  final String serviceType;
  final double baseAmount;
  final String address;
  final String? scheduledDate;

  const CheckoutScreen({
    super.key,
    required this.bookingId,
    required this.proId,
    required this.proName,
    required this.serviceType,
    required this.baseAmount,
    required this.address,
    this.scheduledDate,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _isSubmitting = false;

  Future<void> _confirmPayment() async {
    if (_isSubmitting) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);

    final saved = await FirebaseService().setBookingPaymentMethod(
      bookingId: widget.bookingId,
      paymentMethod: 'cash',
    );
    if (!mounted) return;

    setState(() => _isSubmitting = false);
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d’enregistrer le mode de paiement.')),
      );
      return;
    }

    Navigator.of(context).pushReplacementNamed(
      AppRoutes.paymentStatus,
      arguments: {'paymentId': widget.bookingId},
    );
  }

  @override
  Widget build(BuildContext context) {
    final amount = widget.baseAmount.toStringAsFixed(2);
    return Scaffold(
      appBar: AppBar(title: const Text('Récapitulatif et paiement')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Icon(Icons.receipt_long_rounded,
                size: 48, color: AppTheme.tealPrimary),
            const SizedBox(height: 18),
            Text(widget.serviceType,
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            _CheckoutRow(label: 'Professionnel', value: widget.proName),
            _CheckoutRow(label: 'Adresse', value: widget.address),
            _CheckoutRow(
              label: 'Date prévue',
              value: (widget.scheduledDate?.isNotEmpty ?? false)
                  ? widget.scheduledDate!
                  : 'Dès que possible',
            ),
            const Divider(height: 32),
            _CheckoutRow(label: 'Montant estimé', value: '$amount TND', bold: true),
            const SizedBox(height: 22),
            Card(
              child: ListTile(
                leading: const Icon(Icons.payments_outlined,
                    color: AppTheme.tealPrimary),
                title: const Text('Paiement au professionnel'),
                subtitle: const Text(
                    'Le règlement se fera directement après l’intervention.'),
                trailing: const Icon(Icons.check_circle_rounded,
                    color: AppTheme.tealPrimary),
              ),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _isSubmitting ? null : _confirmPayment,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Confirmer le mode de paiement'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckoutRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _CheckoutRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(label)),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: TextStyle(fontWeight: bold ? FontWeight.bold : null),
              ),
            ),
          ],
        ),
      );
}
