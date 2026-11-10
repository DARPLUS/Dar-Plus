import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/locale_provider.dart';
import '../models/payment_model.dart';
import '../services/payment_service.dart';
import 'home_screen.dart';

class PaymentStatusScreen extends StatefulWidget {
  final String paymentId;
  final bool autoSimulateServerResponse;

  const PaymentStatusScreen({
    super.key,
    required this.paymentId,
    this.autoSimulateServerResponse = false,
  });

  @override
  State<PaymentStatusScreen> createState() => _PaymentStatusScreenState();
}

class _PaymentStatusScreenState extends State<PaymentStatusScreen> {
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    // En environnement de test / dev, simuler le retour webhook du serveur
    if (widget.autoSimulateServerResponse) {
      PaymentService().simulateServerWebhookResponse(
        widget.paymentId,
        shouldSucceed: true,
      );
    }
  }

  Future<void> _handleCancel() async {
    setState(() => _isCancelling = true);
    final ok = await PaymentService().cancelPayment(widget.paymentId);
    if (!mounted) return;
    setState(() => _isCancelling = false);

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d\'annuler la session (déjà traitée ou expirée).'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _goToHome({int initialTab = 0}) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          initialTab: initialTab, // 2: Mes réservations
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>();
    context.watch<LocaleProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return PopScope(
      canPop: false, // Bloquer le retour arrière standard pendant le traitement pour éviter un double paiement
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFFAF7F2),
        body: SafeArea(
          child: StreamBuilder<PaymentModel?>(
            stream: PaymentService().streamPaymentStatus(widget.paymentId),
            builder: (context, snapshot) {
              final payment = snapshot.data;

              // Si les données sont en cours de chargement initial
              if (payment == null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: Color(0xFF0D544E)),
                      const SizedBox(height: 16),
                      Text(
                        'Connexion sécurisée au serveur...',
                        style: TextStyle(color: textSecondary, fontSize: 14),
                      ),
                    ],
                  ),
                );
              }

              // ================= ÉTAT 1 : SUCCÈS =================
              if (payment.isSuccess) {
                return _buildSuccessView(payment, cardBg, borderColor, textPrimary, textSecondary, isDark);
              }

              // ================= ÉTAT 2 : ÉCHEC =================
              if (payment.isFailed) {
                return _buildFailedView(payment, cardBg, borderColor, textPrimary, textSecondary, isDark);
              }

              // ================= ÉTAT 3 : ANNULATION =================
              if (payment.isCancelled) {
                return _buildCancelledView(payment, cardBg, borderColor, textPrimary, textSecondary, isDark);
              }

              // ================= ÉTAT 4 : EN ATTENTE (PENDING) =================
              return _buildPendingView(payment, cardBg, borderColor, textPrimary, textSecondary, isDark);
            },
          ),
        ),
      ),
    );
  }

  // --- 1. VUE SUCCÈS ---
  Widget _buildSuccessView(PaymentModel payment, Color cardBg, Color borderColor, Color textPrimary, Color textSecondary, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 54),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Paiement confirmé !',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'Votre réservation a été validée avec succès par le serveur.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: textSecondary),
          ),
          const SizedBox(height: 28),

          // Reçu officiel du serveur
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                if (payment.id.startsWith('pay_sb_')) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('ENVIRONNEMENT TEST / SANDBOX (FIRESTORE)', style: TextStyle(color: Color(0xFFD97706), fontSize: 10.5, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 12),
                ],
                _buildReceiptRow('Montant réglé', '${payment.totalAmount.toStringAsFixed(3)} DT', textPrimary, isBold: true, highlight: true),
                const Divider(height: 24),
                _buildReceiptRow('Service', payment.serviceType, textPrimary),
                const SizedBox(height: 10),
                _buildReceiptRow('Artisan', payment.proName, textPrimary),
                const SizedBox(height: 10),
                _buildReceiptRow('Référence transaction', payment.transactionRef ?? payment.id, textSecondary, isSmall: true),
                const SizedBox(height: 10),
                _buildReceiptRow('Moyen de paiement', _getMethodLabel(payment.paymentMethod), textPrimary),
                const SizedBox(height: 10),
                _buildReceiptRow('Date & Heure', _formatDateTime(payment.createdAt), textSecondary),
              ],
            ),
          ),
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => _goToHome(initialTab: 3), // Onglet 3: Mes réservations
              icon: const Icon(Icons.calendar_month_rounded, size: 20),
              label: const Text('Voir mes réservations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D544E),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => _goToHome(initialTab: 0),
            child: Text('Retour à l\'accueil', style: TextStyle(color: textSecondary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // --- 2. VUE ÉCHEC ---
  Widget _buildFailedView(PaymentModel payment, Color cardBg, Color borderColor, Color textPrimary, Color textSecondary, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 54),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Paiement refusé',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            payment.failureReason ?? 'La transaction n\'a pas pu aboutir auprès de votre banque.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: textSecondary),
          ),
          const SizedBox(height: 30),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(), // Retourner au checkout pour changer de méthode ou réessayer
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D544E),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Réessayer avec un autre mode', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => _goToHome(initialTab: 0),
            child: Text('Annuler et revenir à l\'accueil', style: TextStyle(color: textSecondary)),
          ),
        ],
      ),
    );
  }

  // --- 3. VUE ANNULATION ---
  Widget _buildCancelledView(PaymentModel payment, Color cardBg, Color borderColor, Color textPrimary, Color textSecondary, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.cancel_outlined, color: Color(0xFFF59E0B), size: 54),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Session annulée',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'Vous avez annulé cette session de paiement. Aucun débit n\'a été effectué.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: textSecondary),
          ),
          const SizedBox(height: 30),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => _goToHome(initialTab: 0),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D544E),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Retour à l\'accueil', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // --- 4. VUE EN ATTENTE (PENDING) ---
  Widget _buildPendingView(PaymentModel payment, Color cardBg, Color borderColor, Color textPrimary, Color textSecondary, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              color: Color(0xFF0D544E),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Traitement en cours...',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: textPrimary),
          ),
          const SizedBox(height: 10),
          Text(
            'En attente de la confirmation définitive du serveur de paiement.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Montant : ${payment.totalAmount.toStringAsFixed(3)} DT',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0D544E)),
          ),
          const SizedBox(height: 40),

          // Bouton d'annulation tant que c'est en attente
          OutlinedButton(
            onPressed: _isCancelling ? null : _handleCancel,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFEF4444)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: _isCancelling
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFEF4444)))
                : const Text('Annuler la transaction', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, Color textColor, {bool isBold = false, bool highlight = false, bool isSmall = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: isSmall ? 12 : 13.5, color: const Color(0xFF64748B)),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: highlight ? 18 : (isSmall ? 12 : 14),
            fontWeight: (isBold || highlight) ? FontWeight.bold : FontWeight.w600,
            color: highlight ? const Color(0xFF0D544E) : textColor,
          ),
        ),
      ],
    );
  }

  String _getMethodLabel(String method) {
    switch (method) {
      case 'carte_bancaire':
        return 'Carte bancaire';
      case 'flouci':
        return 'Flouci / Konnect';
      case 'cash':
        return 'Espèces';
      default:
        return method;
    }
  }

  String _formatDateTime(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} à ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
