import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/locale_provider.dart';
import '../models/payment_model.dart';
import '../services/payment_service.dart';

class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  String _selectedFilter = 'tous'; // 'tous', 'succes', 'en_attente', 'echec'

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>();
    context.watch<LocaleProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final scaffoldBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFFAF7F2);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: Text(
          'Historique des paiements',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: StreamBuilder<List<PaymentModel>>(
        stream: PaymentService().streamClientPayments(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF0D544E)),
            );
          }

          final allPayments = snapshot.data ?? [];

          // Filtrage local selon l'onglet
          var filteredPayments = allPayments;
          if (_selectedFilter == 'succes') {
            filteredPayments = allPayments.where((p) => p.isSuccess).toList();
          } else if (_selectedFilter == 'en_attente') {
            filteredPayments = allPayments.where((p) => p.isPending).toList();
          } else if (_selectedFilter == 'echec') {
            filteredPayments = allPayments.where((p) => p.isFailed || p.isCancelled).toList();
          }

          // Calcul du total réglé avec succès
          final double totalSpent = allPayments
              .where((p) => p.isSuccess)
              .fold(0.0, (sum, p) => sum + p.totalAmount);

          return Column(
            children: [
              // 1. CARTE RÉCAPITULATIF TOTAL DÉPENSÉ
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0D544E), Color(0xFF147A70)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0D544E).withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total réglé sur DAR PLUS',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${totalSpent.toStringAsFixed(3)} DT',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 28),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. FILTRES RAPIDES (CHIPS)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                child: Row(
                  children: [
                    _buildFilterChip('tous', 'Tous (${allPayments.length})', isDark),
                    const SizedBox(width: 8),
                    _buildFilterChip('succes', 'Payés (${allPayments.where((p) => p.isSuccess).length})', isDark),
                    const SizedBox(width: 8),
                    _buildFilterChip('en_attente', 'En attente (${allPayments.where((p) => p.isPending).length})', isDark),
                    const SizedBox(width: 8),
                    _buildFilterChip('echec', 'Échecs / Annulés (${allPayments.where((p) => p.isFailed || p.isCancelled).length})', isDark),
                  ],
                ),
              ),

              // 3. LISTE DES TRANSACTIONS
              Expanded(
                child: filteredPayments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0).withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.payment_rounded, size: 48, color: textSecondary),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Aucune transaction trouvée',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Vos reçus de paiement s\'afficheront ici.',
                              style: TextStyle(fontSize: 13, color: textSecondary),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        physics: const BouncingScrollPhysics(),
                        itemCount: filteredPayments.length,
                        itemBuilder: (context, index) {
                          final payment = filteredPayments[index];
                          return _buildPaymentCard(payment, cardBg, borderColor, textPrimary, textSecondary, isDark);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String id, String label, bool isDark) {
    final isSelected = _selectedFilter == id;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF0D544E)
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF0D544E)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentCard(PaymentModel payment, Color cardBg, Color borderColor, Color textPrimary, Color textSecondary, bool isDark) {
    Color statusBg;
    Color statusText;
    IconData statusIcon;

    if (payment.isSuccess) {
      statusBg = const Color(0xFF10B981).withValues(alpha: 0.12);
      statusText = const Color(0xFF10B981);
      statusIcon = Icons.check_circle_rounded;
    } else if (payment.isPending) {
      statusBg = const Color(0xFFF59E0B).withValues(alpha: 0.12);
      statusText = const Color(0xFFD97706);
      statusIcon = Icons.hourglass_top_rounded;
    } else if (payment.isCancelled) {
      statusBg = const Color(0xFF64748B).withValues(alpha: 0.12);
      statusText = const Color(0xFF64748B);
      statusIcon = Icons.cancel_outlined;
    } else {
      statusBg = const Color(0xFFEF4444).withValues(alpha: 0.12);
      statusText = const Color(0xFFEF4444);
      statusIcon = Icons.error_outline_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _showReceiptDetailsSheet(payment, cardBg, borderColor, textPrimary, textSecondary),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        payment.serviceType,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 13, color: statusText),
                          const SizedBox(width: 4),
                          Text(
                            payment.status.labelFr,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: statusText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Artisan : ${payment.proName}',
                  style: TextStyle(fontSize: 13, color: textSecondary),
                ),
                const SizedBox(height: 10),
                Divider(height: 1, color: borderColor),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 13, color: textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          _formatDate(payment.createdAt),
                          style: TextStyle(fontSize: 12, color: textSecondary),
                        ),
                      ],
                    ),
                    Text(
                      '${payment.totalAmount.toStringAsFixed(3)} DT',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: payment.isSuccess ? const Color(0xFF0D544E) : textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showReceiptDetailsSheet(PaymentModel payment, Color cardBg, Color borderColor, Color textPrimary, Color textSecondary) {
    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Reçu de transaction',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildModalRow('Référence serveur', payment.transactionRef ?? payment.id, textPrimary, isSmall: true),
              const Divider(height: 16),
              _buildModalRow('Prestation', payment.serviceType, textPrimary),
              const SizedBox(height: 8),
              _buildModalRow('Artisan', payment.proName, textPrimary),
              const SizedBox(height: 8),
              _buildModalRow('Moyen de paiement', payment.paymentMethod, textPrimary),
              const SizedBox(height: 8),
              _buildModalRow('Statut officiel', payment.status.labelFr, textPrimary),
              if (payment.failureReason != null) ...[
                const SizedBox(height: 8),
                _buildModalRow('Motif', payment.failureReason!, const Color(0xFFEF4444)),
              ],
              const Divider(height: 16),
              _buildModalRow('Prestation de base', '${payment.baseAmount.toStringAsFixed(3)} DT', textSecondary),
              const SizedBox(height: 6),
              _buildModalRow('Frais de service & garantie', '+${payment.feeAmount.toStringAsFixed(3)} DT', textSecondary),
              if (payment.discountAmount > 0) ...[
                const SizedBox(height: 6),
                _buildModalRow('Réduction', '-${payment.discountAmount.toStringAsFixed(3)} DT', const Color(0xFF10B981)),
              ],
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total prélevé',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                  ),
                  Text(
                    '${payment.totalAmount.toStringAsFixed(3)} DT',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D544E)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModalRow(String label, String value, Color color, {bool isSmall = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        Text(
          value,
          style: TextStyle(
            fontSize: isSmall ? 11.5 : 13.5,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
