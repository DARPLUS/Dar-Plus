import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import '../providers/locale_provider.dart';
import '../models/payment_model.dart';
import '../services/payment_service.dart';
import '../services/ads_service.dart';
import '../services/firebase_service.dart';
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
    if (widget.autoSimulateServerResponse &&
        !FirebaseService().isFirebaseInitialized) {
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
        SnackBar(
          content: Text('payment_cancel_error'.tr()),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _goToHome({int initialTab = 0, bool showInterstitial = false}) {
    void navigateHome() {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            initialTab: initialTab, // 4: Mes réservations
          ),
        ),
        (route) => false,
      );
    }

    if (showInterstitial) {
      AdsService.showInterstitialIfAvailable(onComplete: navigateHome);
    } else {
      navigateHome();
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>();
    context.watch<LocaleProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    return PopScope(
      canPop: false, // Bloquer le retour arrière standard pendant le traitement pour éviter un double paiement
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF0F172A)
            : const Color(0xFFFAF7F2),
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
                        'payment_connecting'.tr(),
                        style: TextStyle(color: textSecondary, fontSize: 14),
                      ),
                    ],
                  ),
                );
              }

              // ================= ÉTAT 1 : SUCCÈS =================
              if (payment.isSuccess) {
                return _buildSuccessView(
                  payment,
                  cardBg,
                  borderColor,
                  textPrimary,
                  textSecondary,
                  isDark,
                );
              }

              // ================= ÉTAT 2 : ÉCHEC =================
              if (payment.isFailed) {
                return _buildFailedView(
                  payment,
                  cardBg,
                  borderColor,
                  textPrimary,
                  textSecondary,
                  isDark,
                );
              }

              // ================= ÉTAT 3 : ANNULATION =================
              if (payment.isCancelled) {
                return _buildCancelledView(
                  payment,
                  cardBg,
                  borderColor,
                  textPrimary,
                  textSecondary,
                  isDark,
                );
              }

              // ================= ÉTAT 4 : EN ATTENTE (PENDING) =================
              return _buildPendingView(
                payment,
                cardBg,
                borderColor,
                textPrimary,
                textSecondary,
                isDark,
              );
            },
          ),
        ),
      ),
    );
  }

  // --- 1. VUE SUCCÈS ---
  Widget _buildSuccessView(
    PaymentModel payment,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
    final isLocalSimulation = payment.paymentProvider == 'local_simulation';
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
              child: Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF10B981),
                size: 54,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isLocalSimulation
                ? 'payment_local_sim_title'.tr()
                : 'Paiement confirmé !',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isLocalSimulation
                ? 'payment_local_sim_notice'.tr()
                : 'Votre réservation a été validée avec succès par le serveur.',
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
                if (payment.isSandbox || payment.id.startsWith('pay_sb_')) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isLocalSimulation
                          ? 'payment_local_sim_badge'.tr()
                          : 'ENVIRONNEMENT TEST / SANDBOX (FIRESTORE)',
                      style: const TextStyle(
                        color: Color(0xFFD97706),
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                _buildReceiptRow(
                  'Prix de la prestation',
                  '${payment.baseAmount.toStringAsFixed(3)} ${payment.currency}',
                  textPrimary,
                ),
                if (payment.discountAmount > 0) ...[
                  const SizedBox(height: 10),
                  _buildReceiptRow(
                    'Réduction',
                    '-${payment.discountAmount.toStringAsFixed(3)} ${payment.currency}',
                    textPrimary,
                  ),
                ],
                const SizedBox(height: 10),
                _buildReceiptRow(
                  'Frais de mise en relation',
                  '${payment.feeAmount.toStringAsFixed(3)} ${payment.currency}',
                  textPrimary,
                ),
                const Divider(height: 24),
                _buildReceiptRow(
                  'Total réglé',
                  '${payment.totalAmount.toStringAsFixed(3)} ${payment.currency}',
                  textPrimary,
                  isBold: true,
                  highlight: true,
                ),
                const Divider(height: 24),
                _buildReceiptRow('Service', payment.serviceType, textPrimary),
                const SizedBox(height: 10),
                _buildReceiptRow('Artisan', payment.proName, textPrimary),
                const SizedBox(height: 10),
                _buildReceiptRow(
                  'Référence transaction',
                  payment.transactionRef ?? payment.id,
                  textSecondary,
                  isSmall: true,
                ),
                const SizedBox(height: 10),
                _buildReceiptRow(
                  'Moyen de paiement',
                  _getMethodLabel(payment.paymentMethod),
                  textPrimary,
                ),
                const SizedBox(height: 10),
                _buildReceiptRow('Statut', payment.status.labelFr, textPrimary),
                const SizedBox(height: 10),
                _buildReceiptRow(
                  'Date & Heure',
                  _formatDateTime(payment.createdAt),
                  textSecondary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => _goToHome(initialTab: 4, showInterstitial: true),
              icon: const Icon(Icons.calendar_month_rounded, size: 20),
              label: Text(
                'payment_view_bookings'.tr(),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D544E),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => _goToHome(initialTab: 0, showInterstitial: true),
            child: Text(
              'home'.tr(),
              style: TextStyle(
                color: textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 2. VUE ÉCHEC ---
  Widget _buildFailedView(
    PaymentModel payment,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
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
              child: Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFEF4444),
                size: 54,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'payment_declined_title'.tr(),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            payment.failureReason ?? 'payment_declined_default'.tr(),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'payment_retry_method'.tr(),
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => _goToHome(initialTab: 0),
            child: Text(
              'payment_cancel_home'.tr(),
              style: TextStyle(color: textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  // --- 3. VUE ANNULATION ---
  Widget _buildCancelledView(
    PaymentModel payment,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
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
              child: Icon(
                Icons.cancel_outlined,
                color: Color(0xFFF59E0B),
                size: 54,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'payment_session_cancelled'.tr(),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'payment_session_cancelled_body'.tr(),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'home'.tr(),
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 4. VUE EN ATTENTE (PENDING) ---
  Widget _buildPendingView(
    PaymentModel payment,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
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
            'payment_processing'.tr(),
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'payment_waiting_confirmation'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'payment_amount_label'.tr(
              namedArgs: {'amount': payment.totalAmount.toStringAsFixed(3)},
            ),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0D544E),
            ),
          ),
          const SizedBox(height: 40),

          // Bouton d'annulation tant que c'est en attente
          OutlinedButton(
            onPressed: _isCancelling ? null : _handleCancel,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFEF4444)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: _isCancelling
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFEF4444),
                    ),
                  )
                : Text(
                    'payment_cancel_transaction'.tr(),
                    style: TextStyle(
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(
    String label,
    String value,
    Color textColor, {
    bool isBold = false,
    bool highlight = false,
    bool isSmall = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isSmall ? 12 : 13.5,
            color: const Color(0xFF64748B),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: highlight ? 18 : (isSmall ? 12 : 14),
            fontWeight: (isBold || highlight)
                ? FontWeight.bold
                : FontWeight.w600,
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
