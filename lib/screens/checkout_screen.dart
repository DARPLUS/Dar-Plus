import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import '../providers/locale_provider.dart';
import '../services/payment_service.dart';
import 'payment_status_screen.dart';

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
  final _paymentFormKey = GlobalKey<FormState>();
  final _promoFormKey = GlobalKey<FormState>();
  // 0: Prestation unitaire, 1: Abonnement DAR+ Sérénité
  int _purchaseType = 0;

  // Modes proposés: paiement Stripe ou règlement en espèces à l'intervention.
  String _selectedGateway = 'stripe_test';

  // Formulaire Carte Stripe Test
  final TextEditingController _cardNumberController = TextEditingController(
    text: '4242 4242 4242 4242',
  );
  final TextEditingController _cardExpiryController = TextEditingController(
    text: '12/28',
  );
  final TextEditingController _cardCvcController = TextEditingController(
    text: '123',
  );
  final TextEditingController _cardHolderController = TextEditingController(
    text: 'Client DAR PLUS',
  );

  // Code promo
  final TextEditingController _promoController = TextEditingController();
  double _discountAmount = 0.0;
  String? _appliedPromoCode;
  bool _isLoading = false;
  bool _isApplyingPromo = false;
  final String _paymentRequestId =
      '${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(0x7fffffff)}';

  static const double _feeAmount =
      2.500; // Frais de mise en relation DAR+ (en DT)
  static const double _subscriptionPrice =
      29.900; // Prix formule Sérénité (en DT/mois)

  double get _currentBaseAmount =>
      _purchaseType == 1 ? _subscriptionPrice : widget.baseAmount;
  double get _currentFeeAmount =>
      _purchaseType == 1 ? 0.0 : _feeAmount; // 0 frais pour abonnés
  double get _totalAmount =>
      (_currentBaseAmount + _currentFeeAmount - _discountAmount).clamp(
        0.0,
        999999.0,
      );

  Future<void> _applyPromoCode() async {
    if (!(_promoFormKey.currentState?.validate() ?? false)) return;
    final code = _promoController.text.trim().toUpperCase();
    if (_purchaseType == 1) return;
    setState(() => _isApplyingPromo = true);
    try {
      final result = await FirebaseFirestore.instance
          .collection('promotions')
          .where('code', isEqualTo: code)
          .limit(1)
          .get();
      final docs = result.docs.where((doc) => doc.data()['isActive'] == true);
      if (docs.isEmpty) throw StateError('Code promo invalide ou expiré.');
      final promo = docs.first.data();
      final amount = promo['discount'];
      final type = promo['type'];
      if (amount is! num || !amount.isFinite || amount <= 0) {
        throw StateError('Cette promotion est mal configurée.');
      }
      if (type == 'percent' && amount > 100) {
        throw StateError('Cette promotion est mal configurée.');
      }
      if (type != 'percent' && type != 'fixed') {
        throw StateError('Cette promotion est mal configurée.');
      }
      final rawDiscount = type == 'percent'
          ? _currentBaseAmount * amount / 100
          : amount.toDouble();
      final discount = rawDiscount.clamp(0.0, _currentBaseAmount).toDouble();
      if (!mounted) return;
      setState(() {
        _discountAmount = discount;
        _appliedPromoCode = code;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Code promo appliqué : -${discount.toStringAsFixed(3)} DT.',
          ),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is StateError
                ? error.message.toString()
                : 'Impossible de vérifier ce code promo. Réessayez.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    } finally {
      if (mounted) setState(() => _isApplyingPromo = false);
    }
  }

  void _fillValidStripeCard() {
    setState(() {
      _cardNumberController.text = '4242 4242 4242 4242';
      _cardExpiryController.text = '12/28';
      _cardCvcController.text = '123';
      _cardHolderController.text = 'Client Test DAR PLUS';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('payment_test_card_valid_inserted'.tr()),
        backgroundColor: Color(0xFF10B981),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _fillDeclinedStripeCard() {
    setState(() {
      _cardNumberController.text =
          '4000 0000 0000 0002'; // Carte de test Stripe provoquant un refus
      _cardExpiryController.text = '12/28';
      _cardCvcController.text = '123';
      _cardHolderController.text = 'Client Test Refusé';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('payment_test_card_declined_inserted'.tr()),
        backgroundColor: Color(0xFFEF4444),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleProcessPayment() async {
    if (_selectedGateway == 'cash') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('payment_cash_confirm_title'.tr()),
          content: Text(
            'payment_cash_confirm_body'.tr(
              args: [_totalAmount.toStringAsFixed(3), widget.proName],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('cancel'.tr()),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text('payment_cash_confirm'.tr()),
            ),
          ],
        ),
      );
      if (confirmed == true && mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop();
        messenger.showSnackBar(
          SnackBar(content: Text('payment_cash_selected'.tr())),
        );
      }
      return;
    }

    if (!(_paymentFormKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    final cardClean = _cardNumberController.text.replaceAll(' ', '');

    const paymentMethod = 'carte_bancaire';

    try {
      final payment = await PaymentService().processOnlineSandboxPayment(
        bookingId: widget.bookingId,
        proId: widget.proId,
        proName: widget.proName,
        serviceType: _purchaseType == 1
            ? 'Abonnement DAR+ Sérénité'
            : widget.serviceType,
        baseAmount: _currentBaseAmount,
        feeAmount: _currentFeeAmount,
        discountAmount: _discountAmount,
        totalAmount: _totalAmount,
        gateway: _selectedGateway,
        paymentMethod: paymentMethod,
        isSubscription: _purchaseType == 1,
        requestId: _paymentRequestId,
        promoCode: _appliedPromoCode,
        testCardNumber: cardClean,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PaymentStatusScreen(
            paymentId: payment.id,
            autoSimulateServerResponse: false,
          ),
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      final message = error.code == 'not-found'
          ? 'payment_backend_not_deployed'.tr()
          : '${'payment_process_error'.tr()} ${error.message ?? error.code}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 8),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${'payment_process_error'.tr()} $error'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  @override
  void dispose() {
    _promoController.dispose();
    _cardNumberController.dispose();
    _cardExpiryController.dispose();
    _cardCvcController.dispose();
    _cardHolderController.dispose();
    super.dispose();
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

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFFAF7F2),
      appBar: AppBar(
        title: Text(
          _selectedGateway == 'cash'
              ? 'payment_cash_title'.tr()
              : 'payment_stripe_sandbox_title'.tr(),
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 0. BANDEAU SANDBOX TEST
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B)
                    .withValues(alpha: isDark ? 0.2 : 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.science_rounded,
                    color: Color(0xFFD97706),
                    size: 26,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'payment_sandbox_active'.tr(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFFD97706),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'payment_sandbox_notice'.tr(),
                          style: TextStyle(
                            fontSize: 11.5,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 1. SÉLECTEUR TYPE D'ACHAT (PRESTATION OU ABONNEMENT)
            Text(
              'payment_plan_heading'.tr(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildPurchaseTypeCard(
                    index: 0,
                    title: 'payment_this_service'.tr(),
                    subtitle: '${widget.baseAmount.toStringAsFixed(3)} DT',
                    badge: widget.serviceType,
                    cardBg: cardBg,
                    borderColor: borderColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildPurchaseTypeCard(
                    index: 1,
                    title: 'payment_serenity_subscription'.tr(),
                    subtitle: '29.900 DT / mois',
                    badge: 'recommended'.tr(),
                    badgeColor: const Color(0xFFD97706),
                    cardBg: cardBg,
                    borderColor: borderColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 2. RÉSUMÉ DE LA COMMANDE
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D544E)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          _purchaseType == 1
                              ? Icons.verified_rounded
                              : Icons.handyman_rounded,
                          color: const Color(0xFF0D544E),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _purchaseType == 1
                                  ? 'Abonnement DAR+ Sérénité'
                                  : widget.serviceType,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _purchaseType == 1
                                  ? 'Dépannage illimité, 0 frais, artisan prioritaire 24/7'
                                  : 'Artisan : ${widget.proName}',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_purchaseType == 0) ...[
                    const SizedBox(height: 12),
                    Divider(height: 1, color: borderColor),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 15,
                          color: textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.address,
                            style: TextStyle(
                              fontSize: 12,
                              color: textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 3. CHOIX DE LA PASSERELLE DE TEST
            Text(
              'payment_method_heading'.tr(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            _buildGatewaySelector(
              id: 'stripe_test',
              title: 'payment_stripe_sandbox_title'.tr(),
              subtitle: 'payment_stripe_sandbox_subtitle'.tr(),
              icon: Icons.credit_card_rounded,
              iconColor: const Color(0xFF635BFF),
              cardBg: cardBg,
              borderColor: borderColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            const SizedBox(height: 10),
            if (_purchaseType == 0) ...[
              const SizedBox(height: 10),
              _buildGatewaySelector(
                id: 'cash',
                title: 'payment_cash_title'.tr(),
                subtitle: 'payment_cash_subtitle'.tr(),
                icon: Icons.payments_rounded,
                iconColor: const Color(0xFF059669),
                cardBg: cardBg,
                borderColor: borderColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
            ],
            const SizedBox(height: 20),

            // 4. FORMULAIRE DE SAISIE SANDBOX DÉDIÉ
            if (_selectedGateway == 'stripe_test') ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF635BFF).withValues(alpha: 0.4),
                  ),
                ),
                child: Form(
                  key: _paymentFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.credit_card,
                            size: 18,
                            color: Color(0xFF635BFF),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'payment_card_entry_test'.tr(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: textPrimary,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF635BFF)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'payment_test_badge'.tr(),
                              style: TextStyle(
                                color: Color(0xFF635BFF),
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _buildInputField(
                        'Numéro de carte de test',
                        _cardNumberController,
                        Icons.credit_card_outlined,
                        borderColor,
                        cardBg,
                        textPrimary,
                        textSecondary,
                        validator: (value) {
                          final digits = (value ?? '').replaceAll(
                            RegExp(r'\D'),
                            '',
                          );
                          return digits.length < 13 || digits.length > 19
                              ? 'payment_card_number_invalid'.tr()
                              : null;
                        },
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInputField(
                              'Expiration (MM/AA)',
                              _cardExpiryController,
                              Icons.calendar_today,
                              borderColor,
                              cardBg,
                              textPrimary,
                              textSecondary,
                              validator: (value) {
                                final match = RegExp(
                                  r'^(0[1-9]|1[0-2])/(\d{2})$',
                                ).firstMatch((value ?? '').trim());
                                if (match == null) {
                                  return 'payment_card_expiry_invalid'.tr();
                                }
                                final month = int.parse(match.group(1)!);
                                final year = 2000 + int.parse(match.group(2)!);
                                final now = DateTime.now();
                                if (year < now.year ||
                                    (year == now.year && month < now.month)) {
                                  return 'payment_card_expiry_invalid'.tr();
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildInputField(
                              'CVC',
                              _cardCvcController,
                              Icons.lock_outline,
                              borderColor,
                              cardBg,
                              textPrimary,
                              textSecondary,
                              validator: (value) =>
                                  RegExp(r'^\d{3,4}$')
                                      .hasMatch((value ?? '').trim())
                                  ? null
                                  : 'payment_card_cvc_invalid'.tr(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildInputField(
                        'Nom du titulaire',
                        _cardHolderController,
                        Icons.person_outline,
                        borderColor,
                        cardBg,
                        textPrimary,
                        textSecondary,
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? 'payment_card_holder_required'.tr()
                            : null,
                      ),
                      const SizedBox(height: 14),

                      // BOUTONS RAPIDES DE TEST
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _fillValidStripeCard,
                              icon: const Icon(
                                Icons.check_circle_outline,
                                size: 14,
                                color: Color(0xFF10B981),
                              ),
                              label: Text(
                                'payment_test_card_valid'.tr(),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF10B981),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Color(0xFF10B981),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _fillDeclinedStripeCard,
                              icon: const Icon(
                                Icons.error_outline,
                                size: 14,
                                color: Color(0xFFEF4444),
                              ),
                              label: Text(
                                'payment_test_card_declined'.tr(),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFEF4444),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Color(0xFFEF4444),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // 5. CODE PROMO
            if (_purchaseType == 0) ...[
              Row(
                children: [
                  Expanded(
                    child: Form(
                      key: _promoFormKey,
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 48),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderColor),
                        ),
                        child: TextFormField(
                          controller: _promoController,
                          validator: (value) => (value ?? '').trim().isEmpty
                              ? 'promo_code_required'.tr()
                              : null,
                          onChanged: (value) {
                            if (_appliedPromoCode != null &&
                                value.trim().toUpperCase() !=
                                    _appliedPromoCode) {
                              setState(() {
                                _appliedPromoCode = null;
                                _discountAmount = 0;
                              });
                            }
                          },
                          style: TextStyle(color: textPrimary, fontSize: 14),
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            hintText: 'Saisir un code promo',
                            hintStyle: TextStyle(
                              color: textSecondary,
                              fontSize: 13,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _isApplyingPromo ? null : _applyPromoCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D544E),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                    ),
                    child: _isApplyingPromo
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'apply'.tr(),
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
              ),
              if (_appliedPromoCode != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: Color(0xFF10B981),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Code $_appliedPromoCode appliqué (-${_discountAmount.toStringAsFixed(3)} DT)',
                      style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
            ],

            // 6. DÉTAIL FINANCIER COMPLET
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'payment_summary_title'.tr(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildPriceRow(
                    _purchaseType == 1
                        ? 'Abonnement DAR+ Sérénité (1 mois)'
                        : 'Prestation de service',
                    '${_currentBaseAmount.toStringAsFixed(3)} DT',
                    textSecondary,
                  ),
                  if (_currentFeeAmount > 0) ...[
                    const SizedBox(height: 8),
                    _buildPriceRow(
                      'Frais de mise en relation & garantie DAR+',
                      '+${_currentFeeAmount.toStringAsFixed(3)} DT',
                      textSecondary,
                    ),
                  ] else ...[
                    const SizedBox(height: 8),
                    _buildPriceRow(
                      'Frais de mise en relation',
                      'OFFERT (Abonné) !',
                      const Color(0xFF10B981),
                      isBold: true,
                    ),
                  ],
                  if (_discountAmount > 0) ...[
                    const SizedBox(height: 8),
                    _buildPriceRow(
                      'Réduction code promo',
                      '-${_discountAmount.toStringAsFixed(3)} DT',
                      const Color(0xFF10B981),
                      isBold: true,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Divider(height: 1, color: borderColor),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'payment_total_incl_fees'.tr(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      Text(
                        '${_totalAmount.toStringAsFixed(3)} DT',
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D544E),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),

            // 7. BOUTON FINAL DE PAIEMENT SANDBOX
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleProcessPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D544E),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'payment_validating_server'.tr(),
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _selectedGateway == 'cash'
                                ? Icons.payments_rounded
                                : Icons.lock_rounded,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _selectedGateway == 'cash'
                                ? 'payment_cash_button'.tr()
                                : 'payment_stripe_button'.tr(
                                    args: [_totalAmount.toStringAsFixed(3)],
                                  ),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildPurchaseTypeCard({
    required int index,
    required String title,
    required String subtitle,
    required String badge,
    Color? badgeColor,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final isSelected = _purchaseType == index;
    return GestureDetector(
      onTap: () => setState(() {
        _purchaseType = index;
        _appliedPromoCode = null;
        _discountAmount = 0;
        _promoController.clear();
        if (index == 1 && _selectedGateway == 'cash') {
          _selectedGateway = 'stripe_test';
        }
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF0D544E) : borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (badgeColor ?? const Color(0xFF0D544E)).withValues(
                  alpha: 0.12,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: badgeColor ?? const Color(0xFF0D544E),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0D544E),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGatewaySelector({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final isSelected = _selectedGateway == id;
    return GestureDetector(
      onTap: () => setState(() => _selectedGateway = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? const Color(0xFF0D544E) : borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11.5, color: textSecondary),
                  ),
                ],
              ),
            ),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF0D544E)
                      : Colors.grey.shade400,
                  width: 2,
                ),
                color: isSelected
                    ? const Color(0xFF0D544E)
                    : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(
    String label,
    TextEditingController controller,
    IconData icon,
    Color borderColor,
    Color cardBg,
    Color textPrimary,
    Color textSecondary, {
    required String? Function(String?) validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: controller,
                  validator: validator,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPriceRow(
    String label,
    String amount,
    Color color, {
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            color: color,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            fontSize: 13.5,
            color: color,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
