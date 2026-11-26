import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import '../providers/locale_provider.dart';
import '../theme/app_theme.dart';
import '../services/firebase_service.dart';
import '../widgets/contact_admin_sheet.dart';
import 'home_screen.dart';
import 'pro_home_screen.dart';
import 'admin_requests_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  final String? prefilledEmail;
  const LoginScreen({super.key, this.prefilledEmail});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _emailController;
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _rememberMe = true;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.prefilledEmail ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _quickFillDemo(String email, String password) {
    setState(() {
      _emailController.text = email;
      _passwordController.text = password;
    });
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final firebaseService = FirebaseService();

    final result = await firebaseService.signInWithEmailAndPassword(
      email: _emailController.text,
      password: _passwordController.text,
    );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });

    if (result['success'] == true) {
      final role = (result['role'] as String?)?.toLowerCase() ?? 'client';
      final fullName =
          (result['fullName'] as String?) ??
          _emailController.text.split('@').first;
      final email =
          (result['email'] as String?) ?? _emailController.text.trim();
      final phone = (result['phone'] as String?) ?? '';
      final serviceType =
          (result['serviceType'] as String?) ?? 'Plomberie & Sanitaire';

      if ((role == 'admin' || role == 'super_admin') && !kIsWeb) {
        await firebaseService.signOut();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Les comptes administrateur sont accessibles uniquement depuis la version Web.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] as String),
          backgroundColor: const Color(0xFF0C5050),
          duration: const Duration(seconds: 2),
        ),
      );

      final bool mustChangePassword = result['mustChangePassword'] == true;

      // Redirection automatique selon le rôle détecté
      if (role == 'admin' || role == 'super_admin') {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => AdminRequestsScreen(
              adminName: fullName,
              adminEmail: email,
              adminPhone: phone,
              adminRole: role,
              mustChangePassword: mustChangePassword,
            ),
          ),
          (route) => false,
        );
      } else if (role == 'professionnel') {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) =>
                ProHomeScreen(proName: fullName, serviceType: serviceType),
          ),
          (route) => false,
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => HomeScreen(
              userName: fullName,
              userEmail: email,
              userPhone: phone,
            ),
          ),
          (route) => false,
        );
      }
    } else {
      // Gestion des cas spécifiques d'attente de validation ou de rejet
      final code = result['code'] as String?;
      if (code == 'PENDING_APPROVAL') {
        _showPendingApprovalDialog(result['message'] as String);
      } else if (code == 'REJECTED') {
        _showRejectedDialog(result['message'] as String);
      } else if (code == 'EMAIL_NOT_VERIFIED') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'verification_required'.tr(args: [_emailController.text.trim()]),
            ),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: 'verification_resend'.tr(),
              textColor: Colors.white,
              onPressed: () async {
                final resend = await firebaseService
                    .resendClientVerificationEmail(
                      languageCode: context.locale.languageCode,
                    );
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(resend['message'] as String),
                    backgroundColor: resend['success'] == true
                        ? const Color(0xFF0C5050)
                        : Colors.redAccent,
                  ),
                );
              },
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] as String),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() {
      _isGoogleLoading = true;
    });

    final firebaseService = FirebaseService();
    final result = await firebaseService.signInWithGoogle();

    if (!mounted) return;
    setState(() {
      _isGoogleLoading = false;
    });

    if (result['success'] == true) {
      final role = (result['role'] as String?)?.toLowerCase() ?? 'client';
      final fullName = (result['fullName'] as String?) ?? 'Utilisateur';
      final email = (result['email'] as String?) ?? '';
      final phone = (result['phone'] as String?) ?? '';
      final serviceType =
          (result['serviceType'] as String?) ?? 'Plomberie & Sanitaire';

      if ((role == 'admin' || role == 'super_admin') && !kIsWeb) {
        await firebaseService.signOut();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Les comptes administrateur sont accessibles uniquement depuis la version Web.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] as String),
          backgroundColor: const Color(0xFF0C5050),
          duration: const Duration(seconds: 2),
        ),
      );

      final bool mustChangePassword = result['mustChangePassword'] == true;

      if (role == 'admin' || role == 'super_admin') {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => AdminRequestsScreen(
              adminName: fullName,
              adminEmail: email,
              adminPhone: phone,
              adminRole: role,
              mustChangePassword: mustChangePassword,
            ),
          ),
          (route) => false,
        );
      } else if (role == 'professionnel') {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) =>
                ProHomeScreen(proName: fullName, serviceType: serviceType),
          ),
          (route) => false,
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => HomeScreen(
              userName: fullName,
              userEmail: email,
              userPhone: phone,
            ),
          ),
          (route) => false,
        );
      }
    } else {
      final code = result['code'] as String?;
      if (code == 'PENDING_APPROVAL') {
        _showPendingApprovalDialog(result['message'] as String);
      } else if (code == 'REJECTED') {
        _showRejectedDialog(result['message'] as String);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] as String),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showPendingApprovalDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Row(
          children: [
            Icon(
              Icons.hourglass_top_rounded,
              color: Color(0xFFEA580C),
              size: 26,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Compte en attente de confirmation',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.titleColor,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: const TextStyle(
                fontSize: 13.5,
                color: Color(0xFF475569),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDBA74)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.notifications_active_outlined,
                    size: 18,
                    color: Color(0xFFEA580C),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'L\'admin a reçu vos informations dans son dashboard et vérifie vos coordonnées.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF9A3412)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ContactAdminSheet.show(context);
            },
            child: const Text('Contacter le support'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0C5050),
              foregroundColor: Colors.white,
            ),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
  }

  void _showRejectedDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Row(
          children: [
            Icon(Icons.cancel_rounded, color: Color(0xFFEF4444), size: 26),
            SizedBox(width: 10),
            Text(
              'Demande non validée',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppTheme.titleColor,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 13.5,
            color: Color(0xFF475569),
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ContactAdminSheet.show(context);
            },
            child: const Text('Contacter l\'administration'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController(
      text: _emailController.text.trim(),
    );
    final resetFormKey = GlobalKey<FormState>();
    bool isSending = false;
    bool isSuccess = false;
    String? errorMessage;
    String sentEmail = '';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDlgDark = Theme.of(context).brightness == Brightness.dark;
            final dlgBg = isDlgDark ? const Color(0xFF1E293B) : Colors.white;
            final dlgTitle = isDlgDark ? Colors.white : const Color(0xFF0F172A);
            final dlgSub = isDlgDark
                ? const Color(0xFF94A3B8)
                : const Color(0xFF475569);
            final inputBorder = isDlgDark
                ? const Color(0xFF334155)
                : const Color(0xFFDDE3EA);
            final inputBg = isDlgDark ? const Color(0xFF0F172A) : Colors.white;

            return AlertDialog(
              backgroundColor: dlgBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              contentPadding: const EdgeInsets.all(24),
              content: SingleChildScrollView(
                child: isSuccess
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981)
                                  .withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.mark_email_read_rounded,
                              color: Color(0xFF10B981),
                              size: 34,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'E-mail envoyé !',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: dlgTitle,
                            ),
                          ),
                          const SizedBox(height: 10),
                          RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 13.5,
                                color: dlgSub,
                                height: 1.45,
                              ),
                              children: [
                                const TextSpan(
                                  text: 'Un lien de réinitialisation a été envoyé à :\n',
                                ),
                                TextSpan(
                                  text: '$sentEmail\n\n',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0C5050),
                                  ),
                                ),
                                const TextSpan(
                                  text: 'Ouvrez votre boîte mail et cliquez sur le lien pour définir votre nouveau mot de passe. Vérifiez aussi vos spams.',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0C5050),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                'Retour à la connexion',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0C5050)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.lock_reset_rounded,
                                  color: Color(0xFF0C5050),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Mot de passe oublié',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: dlgTitle,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Entrez l\'adresse e-mail associée à votre compte DAR PLUS. Nous vous enverrons un lien sécurisé pour réinitialiser votre mot de passe.',
                            style: TextStyle(
                              fontSize: 13,
                              color: dlgSub,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 18),
                          // Champ email
                          Container(
                            decoration: BoxDecoration(
                              color: inputBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: errorMessage != null
                                    ? Colors.redAccent
                                    : inputBorder,
                                width: 1.2,
                              ),
                            ),
                            child: Form(
                              key: resetFormKey,
                              child: TextFormField(
                                controller: resetEmailController,
                                keyboardType: TextInputType.emailAddress,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  color: dlgTitle,
                                ),
                                validator: (value) {
                                  final email = (value ?? '').trim();
                                  return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                          .hasMatch(email)
                                      ? null
                                      : 'email_invalid'.tr();
                                },
                                onChanged: (_) {
                                  if (errorMessage != null) {
                                    setDialogState(() {
                                      errorMessage = null;
                                    });
                                  }
                                },
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(
                                    Icons.mail_outline_rounded,
                                    color: Color(0xFF64748B),
                                    size: 20,
                                  ),
                                  hintText: 'nom@exemple.com',
                                  hintStyle: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 14,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (errorMessage != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  color: Colors.redAccent,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    errorMessage!,
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: isSending
                                      ? null
                                      : () => Navigator.pop(ctx),
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF64748B),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text('Annuler'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton(
                                  onPressed: isSending
                                      ? null
                                      : () async {
                                          final email = resetEmailController
                                              .text
                                              .trim();
                                          if (!(resetFormKey.currentState
                                                  ?.validate() ??
                                              false)) {
                                            return;
                                          }

                                          setDialogState(() {
                                            isSending = true;
                                            errorMessage = null;
                                          });

                                          final res = await FirebaseService()
                                              .resetPassword(
                                                email,
                                                languageCode:
                                                    context.locale.languageCode,
                                              );

                                          setDialogState(() {
                                            isSending = false;
                                            if (res['success'] == true) {
                                              isSuccess = true;
                                              sentEmail = email;
                                            } else {
                                              errorMessage =
                                                  res['message'] as String;
                                            }
                                          });
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0C5050),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: isSending
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                          ),
                                        )
                                      : const Text(
                                          'Envoyer le lien',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
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
      },
    );
  }

  Widget _buildAdminWebLayout(BuildContext context, bool isDesktop) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final adminSurface = isDark ? const Color(0xFF0F172A) : Colors.white;
    if (!isDesktop) {
      // Responsive layout for narrower screens on Web (single column)
      return Scaffold(
        backgroundColor: adminSurface,
        body: SingleChildScrollView(
          child: Column(
            children: [
              _buildAdminLeftPanel(isCompact: true),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: _buildAdminLoginForm(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Exact Split Screen Layout for Desktop / Web
    return Scaffold(
      backgroundColor: adminSurface,
      body: Row(
        children: [
          // Left Dark Panel (46% width)
          Expanded(flex: 46, child: _buildAdminLeftPanel(isCompact: false)),
          // Right Clean Form Panel (54% width)
          Expanded(
            flex: 54,
            child: Container(
              color: adminSurface,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 40,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: _buildAdminLoginForm(context),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminLeftPanel({required bool isCompact}) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF081026),
            Color(0xFF0A1832),
            Color(0xFF0C2433),
            Color(0xFF071B26),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Ambient soft teal glow
          Positioned(
            top: -60,
            left: -60,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0D544E).withValues(alpha: 0.22),
              ),
            ),
          ),
          // Tech radar / grid overlay
          Positioned.fill(child: CustomPaint(painter: _AdminGridPainter())),
          // Foreground Content
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 24 : 48,
              vertical: isCompact ? 32 : 44,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: isCompact
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.spaceBetween,
              children: [
                // Top Brand: [D+] DAR PLUS / ADMINISTRATION
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D544E),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'D+',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          'DAR PLUS',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            letterSpacing: 0.6,
                          ),
                        ),
                        SizedBox(height: 1),
                        Text(
                          'ADMINISTRATION',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                if (isCompact) const SizedBox(height: 32),

                // Center Content Block
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge: • CONSOLE SÉCURISÉE
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F2E31).withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF14B8A6)
                              .withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF2DD4BF),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'CONSOLE SÉCURISÉE',
                            style: TextStyle(
                              color: Color(0xFF2DD4BF),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Main Title
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          height: 1.18,
                          letterSpacing: -0.6,
                          fontFamily: 'sans-serif',
                        ),
                        children: [
                          TextSpan(
                            text: 'Pilotez DAR PLUS,\n',
                            style: TextStyle(color: Colors.white),
                          ),
                          TextSpan(
                            text: 'en toute confiance.',
                            style: TextStyle(color: Color(0xFF2DD4BF)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Subtitle
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: const Text(
                        'Supervisez les utilisateurs, les interventions et les paiements depuis un espace centralisé conçu pour votre équipe.',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 13.5,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),

                    // 3 KPI Cards Row
                    Row(
                      children: [
                        _buildAdminStatCard('8,4K', 'Clients actifs'),
                        const SizedBox(width: 12),
                        _buildAdminStatCard('1,2K', 'Professionnels'),
                        const SizedBox(width: 12),
                        _buildAdminStatCard('99,9%', 'Disponibilité'),
                      ],
                    ),
                  ],
                ),

                if (isCompact) const SizedBox(height: 32),

                // Bottom Footer of Left Panel
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '© 2026 DAR PLUS',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Row(
                      children: const [
                        Icon(
                          Icons.lock_outline_rounded,
                          color: Color(0xFF64748B),
                          size: 13,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Connexion chiffrée',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminStatCard(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF132038).withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFF334155).withValues(alpha: 0.45),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminLoginForm(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headingColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final bodyColor = isDark
        ? const Color(0xFFCBD5E1)
        : const Color(0xFF475569);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final accentColor = isDark
        ? const Color(0xFF5EEAD4)
        : const Color(0xFF0D544E);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ESPACE ADMINISTRATEUR (Small green tag)
          Text(
            'admin_login_space'.tr(),
            style: TextStyle(
              color: accentColor,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),

          // Big Heading: Heureux de vous revoir
          Text(
            'admin_login_welcome'.tr(),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: headingColor,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),

          // Subtitle
          Text(
            'admin_login_subtitle'.tr(),
            style: TextStyle(fontSize: 13.5, color: bodyColor),
          ),
          const SizedBox(height: 28),

          // Email label
          Text(
            'admin_login_email'.tr(),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: bodyColor,
            ),
          ),
          const SizedBox(height: 8),

          // Email Input
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || !value.contains('@')) {
                return 'validation_email_invalid'.tr();
              }
              return null;
            },
            style: TextStyle(fontSize: 14, color: headingColor),
            decoration: InputDecoration(
              prefixIcon: const Icon(
                Icons.mail_outline_rounded,
                color: Color(0xFF94A3B8),
                size: 19,
              ),
              hintText: 'admin@darplus.tn',
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13.5,
              ),
              filled: true,
              fillColor: cardColor,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Color(0xFF0D544E),
                  width: 1.5,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.redAccent),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Colors.redAccent,
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Password Label & Forgot Password Link
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'password_label'.tr(),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: bodyColor,
                ),
              ),
              GestureDetector(
                onTap: _showForgotPasswordDialog,
                child: Text(
                  'forgot_password'.tr(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Password Input
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            validator: (value) {
              if (value == null || value.length < 6) {
                return 'validation_password_min'.tr(args: ['6']);
              }
              return null;
            },
            style: TextStyle(fontSize: 14, color: headingColor),
            decoration: InputDecoration(
              prefixIcon: const Icon(
                Icons.lock_outline_rounded,
                color: Color(0xFF94A3B8),
                size: 19,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: const Color(0xFF94A3B8),
                  size: 19,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              hintText: 'admin_login_password_hint'.tr(),
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13.5,
              ),
              filled: true,
              fillColor: cardColor,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: accentColor, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.redAccent),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Colors.redAccent,
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Checkbox: Rester connecté pendant 30 jours
          Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: Checkbox(
                  value: _rememberMe,
                  activeColor: const Color(0xFF0D544E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                  onChanged: (val) => setState(() => _rememberMe = val ?? true),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _rememberMe = !_rememberMe),
                child: Text(
                  'admin_login_remember'.tr(),
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // Accéder à la console →
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D544E),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.2,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'admin_login_submit'.tr(),
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.2,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 17),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 22),

          // Separator: APERÇU FRONTEND
          Row(
            children: [
              const Expanded(
                child: Divider(color: Color(0xFFE2E8F0), thickness: 1),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  'admin_login_preview'.tr(),
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const Expanded(
                child: Divider(color: Color(0xFFE2E8F0), thickness: 1),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Utiliser le compte de démonstration
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton(
              onPressed: () {
                _quickFillDemo('admin@darplus.tn', 'admin123');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('admin_login_demo_filled'.tr()),
                    backgroundColor: Color(0xFF0D544E),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: bodyColor,
                side: BorderSide(color: borderColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                backgroundColor: cardColor,
              ),
              child: Text(
                'admin_login_use_demo'.tr(),
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Security Notice Footer
          Center(
            child: Text(
              'admin_login_security_note'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 10.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 850;
    if (kIsWeb || isDesktop) {
      return _buildAdminWebLayout(context, isDesktop);
    }
    return _buildMobileLayout(context);
  }

  Widget _buildMobileLayout(BuildContext context) {
    context.watch<ThemeProvider>();
    context.watch<LocaleProvider>();
    final topPadding = MediaQuery.of(context).padding.top;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final inputBorderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFDDE3EA);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final dividerColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Dark Teal Top Header (matches user's screenshot exactly)
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                top: topPadding + 22,
                left: 24,
                right: 24,
                bottom: 34,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF0C5050),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(34),
                  bottomRight: Radius.circular(34),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top left warm orange/golden house icon badge with quick demo popup
                  PopupMenuButton<Map<String, String>>(
                    tooltip: 'Comptes de test / Démos',
                    offset: const Offset(0, 52),
                    onSelected: (creds) {
                      _quickFillDemo(creds['email']!, creds['password']!);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: {
                          'email': 'client@darplus.tn',
                          'password': 'password123',
                        },
                        child: Row(
                          children: [
                            Icon(
                              Icons.person_rounded,
                              size: 18,
                              color: Color(0xFF0C5050),
                            ),
                            SizedBox(width: 8),
                            Text('Client (Karim)'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: {
                          'email': 'ahmed.pro@darplus.tn',
                          'password': 'password123',
                        },
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 18,
                              color: Color(0xFF10B981),
                            ),
                            SizedBox(width: 8),
                            Text('Pro Validé (Ahmed - Plombier)'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: {
                          'email': 'sami.attente@darplus.tn',
                          'password': 'password123',
                        },
                        child: Row(
                          children: [
                            Icon(
                              Icons.hourglass_top_rounded,
                              size: 18,
                              color: Color(0xFFEA580C),
                            ),
                            SizedBox(width: 8),
                            Text('Pro En Attente (Sami)'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: {
                          'email': 'admin@darplus.tn',
                          'password': 'admin123',
                        },
                        child: Row(
                          children: [
                            Icon(
                              Icons.workspace_premium_rounded,
                              size: 18,
                              color: Color(0xFFD97706),
                            ),
                            SizedBox(width: 8),
                            Text('Super Admin (admin@darplus.tn)'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: {
                          'email': 'staff@darplus.tn',
                          'password': 'admin123',
                        },
                        child: Row(
                          children: [
                            Icon(
                              Icons.shield_outlined,
                              size: 18,
                              color: Color(0xFF7C3AED),
                            ),
                            SizedBox(width: 8),
                            Text('Admin (staff@darplus.tn)'),
                          ],
                        ),
                      ),
                    ],
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: const Color(0xFFE89838),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.add_home_outlined,
                            color: Color(0xFF0C5050),
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // Title: Bon retour
                  Text(
                    'login_title'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'sans-serif',
                      letterSpacing: -0.6,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Subtitle
                  Text(
                    'login_subtitle'.tr(),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 14.5,
                      fontWeight: FontWeight.normal,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),

            // 2. Form Body (exactly matches the image)
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: kIsWeb ? 480 : double.infinity,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 26,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Label 1: Adresse e-mail
                        Text(
                          'email_label'.tr(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Input 1: Email
                        Container(
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: inputBorderColor,
                              width: 1.2,
                            ),
                          ),
                          child: TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || !value.contains('@')) {
                                return 'Veuillez saisir une adresse email valide';
                              }
                              return null;
                            },
                            style: TextStyle(
                              color: textColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              prefixIcon: Icon(
                                Icons.mail_outline_rounded,
                                color: subColor,
                                size: 20,
                              ),
                              hintText: 'email_hint'.tr(),
                              hintStyle: TextStyle(
                                color: isDark
                                    ? const Color(0xFF64748B)
                                    : const Color(0xFF94A3B8),
                                fontSize: 14.5,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Label 2: Mot de passe
                        Text(
                          'password_label'.tr(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Input 2: Mot de passe
                        Container(
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: inputBorderColor,
                              width: 1.2,
                            ),
                          ),
                          child: TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            validator: (value) {
                              if (value == null || value.length < 6) {
                                return 'Le mot de passe doit comporter au moins 6 caractères';
                              }
                              return null;
                            },
                            style: TextStyle(
                              color: textColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              prefixIcon: Icon(
                                Icons.lock_outline_rounded,
                                color: subColor,
                                size: 20,
                              ),
                              hintText: 'password_hint'.tr(),
                              hintStyle: TextStyle(
                                color: isDark
                                    ? const Color(0xFF64748B)
                                    : const Color(0xFF94A3B8),
                                fontSize: 14.5,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: subColor,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Bouton Mot de passe oublié ?
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _showForgotPasswordDialog,
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF0C5050),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'forgot_password'.tr(),
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0C5050),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 22),

                        // Action Button: Se connecter (matches user's screenshot)
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0C5050),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Text(
                                    'login_button'.tr(),
                                    style: const TextStyle(
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        if (!kIsWeb) ...[
                          // Separator: -- ou --
                          Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color: dividerColor,
                                  thickness: 1,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                child: Text(
                                  'or_separator'.tr(),
                                  style: TextStyle(
                                    color: subColor,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color: dividerColor,
                                  thickness: 1,
                                ),
                              ),
                            ],
                          ),
                        ],

                        if (!kIsWeb) ...[
                          const SizedBox(height: 20),

                          // Social Button: Continuer avec Google (matches user's screenshot)
                          Container(
                            width: double.infinity,
                            height: 54,
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: inputBorderColor,
                                width: 1.2,
                              ),
                            ),
                            child: InkWell(
                              onTap: (_isLoading || _isGoogleLoading)
                                  ? null
                                  : _handleGoogleLogin,
                              borderRadius: BorderRadius.circular(16),
                              child: _isGoogleLoading
                                  ? Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFF0C5050),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'connecting_to_google'.tr(),
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: textColor,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        // G Logo Badge
                                        Container(
                                          width: 26,
                                          height: 26,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: inputBorderColor,
                                              width: 1.2,
                                            ),
                                          ),
                                          alignment: Alignment.center,
                                          child: const Text(
                                            'G',
                                            style: TextStyle(
                                              color: Color(0xFF0C5050),
                                              fontWeight: FontWeight.w900,
                                              fontSize: 13.5,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          'continue_with_google'.tr(),
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: textColor,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 32),

                        if (!kIsWeb) ...[
                          // Footer Link: Pas encore de compte ? Créer un compte
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${'no_account'.tr()} ',
                                style: TextStyle(fontSize: 14, color: subColor),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(
                                      builder: (_) => const RegisterScreen(),
                                    ),
                                  );
                                },
                                child: Text(
                                  'create_account'.tr(),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0C5050),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 20),
                      ],
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
}

class _AdminGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF334155).withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    // Draw subtle grid lines
    const step = 48.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Concentric circular radar arcs in bottom-right
    final center = Offset(size.width * 0.9, size.height * 0.78);
    final arcPaint = Paint()
      ..color = const Color(0xFF14B8A6).withValues(alpha: 0.09)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (double r = 60; r < 500; r += 80) {
      canvas.drawCircle(center, r, arcPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
