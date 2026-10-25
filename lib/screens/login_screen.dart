import 'package:flutter/material.dart';
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
      final fullName = (result['fullName'] as String?) ??
          _emailController.text.split('@').first;
      final email = (result['email'] as String?) ?? _emailController.text.trim();
      final phone = (result['phone'] as String?) ?? '';
      final serviceType =
          (result['serviceType'] as String?) ?? 'Plomberie & Sanitaire';

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
            builder: (_) => ProHomeScreen(
              proName: fullName,
              serviceType: serviceType,
            ),
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
            builder: (_) => ProHomeScreen(
              proName: fullName,
              serviceType: serviceType,
            ),
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
            Icon(Icons.hourglass_top_rounded,
                color: Color(0xFFEA580C), size: 26),
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
                  Icon(Icons.notifications_active_outlined,
                      size: 18, color: Color(0xFFEA580C)),
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
    final resetEmailController =
        TextEditingController(text: _emailController.text.trim());
    bool isSending = false;
    bool isSuccess = false;
    String? errorMessage;
    String sentEmail = '';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
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
                          const Text(
                            'E-mail envoyé !',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.titleColor,
                            ),
                          ),
                          const SizedBox(height: 10),
                          RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: const TextStyle(
                                fontSize: 13.5,
                                color: Color(0xFF475569),
                                height: 1.45,
                              ),
                              children: [
                                const TextSpan(
                                  text:
                                      'Un e-mail contenant votre mot de passe temporaire a été envoyé à :\n',
                                ),
                                TextSpan(
                                  text: '$sentEmail\n\n',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0C5050),
                                  ),
                                ),
                                const TextSpan(
                                  text:
                                      'Veuillez ouvrir votre boîte de réception pour récupérer votre mot de passe temporaire et vous reconnecter.',
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
                              const Expanded(
                                child: Text(
                                  'Mot de passe oublié',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.titleColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Entrez l\'adresse e-mail associée à votre compte DAR PLUS. Nous vous enverrons un lien sécurisé pour réinitialiser votre mot de passe.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.subtitleColor,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 18),
                          // Champ email
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: errorMessage != null
                                    ? Colors.redAccent
                                    : const Color(0xFFDDE3EA),
                                width: 1.2,
                              ),
                            ),
                            child: TextField(
                              controller: resetEmailController,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(
                                fontSize: 14.5,
                                color: Color(0xFF0F172A),
                              ),
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
                          if (errorMessage != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.error_outline_rounded,
                                    color: Colors.redAccent, size: 16),
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
                                          final email =
                                              resetEmailController.text.trim();
                                          if (email.isEmpty ||
                                              !email.contains('@')) {
                                            setDialogState(() {
                                              errorMessage =
                                                  'Veuillez saisir une adresse e-mail valide.';
                                            });
                                            return;
                                          }

                                          setDialogState(() {
                                            isSending = true;
                                            errorMessage = null;
                                          });

                                          final res = await FirebaseService()
                                              .resetPassword(email);

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
                                        vertical: 12),
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
                                                    Colors.white),
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

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FBFB),
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
                            Icon(Icons.person_rounded,
                                size: 18, color: Color(0xFF0C5050)),
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
                            Icon(Icons.check_circle_rounded,
                                size: 18, color: Color(0xFF10B981)),
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
                            Icon(Icons.hourglass_top_rounded,
                                size: 18, color: Color(0xFFEA580C)),
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
                            Icon(Icons.workspace_premium_rounded,
                                size: 18, color: Color(0xFFD97706)),
                            SizedBox(width: 8),
                            Text('👑 Super Admin (admin@darplus.tn)'),
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
                            Icon(Icons.shield_outlined,
                                size: 18, color: Color(0xFF7C3AED)),
                            SizedBox(width: 8),
                            Text('🛡️ Admin (staff@darplus.tn)'),
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
                  const Text(
                    'Bon retour',
                    style: TextStyle(
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
                    'Connectez-vous pour réserver ou gérer vos interventions.',
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Label 1: Adresse e-mail
                    const Text(
                      'Adresse e-mail',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Input 1: Email
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFDDE3EA),
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
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(
                            Icons.mail_outline_rounded,
                            color: Color(0xFF64748B),
                            size: 20,
                          ),
                          hintText: 'nom@exemple.com',
                          hintStyle: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 14.5,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Label 2: Mot de passe
                    const Text(
                      'Mot de passe',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Input 2: Mot de passe
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFDDE3EA),
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
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(
                            Icons.lock_outline_rounded,
                            color: Color(0xFF64748B),
                            size: 20,
                          ),
                          hintText: 'Votre mot de passe',
                          hintStyle: const TextStyle(
                            color: Color(0xFF94A3B8),
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
                              color: const Color(0xFF64748B),
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
                              horizontal: 6, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Mot de passe oublié ?',
                          style: TextStyle(
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
                                      Colors.white),
                                ),
                              )
                            : const Text(
                                'Se connecter',
                                style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.2,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Separator: -- ou --
                    const Row(
                      children: [
                        Expanded(
                          child: Divider(color: Color(0xFFE2E8F0), thickness: 1),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            'ou',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(color: Color(0xFFE2E8F0), thickness: 1),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Social Button: Continuer avec Google (matches user's screenshot)
                    Container(
                      width: double.infinity,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFDDE3EA),
                          width: 1.2,
                        ),
                      ),
                      child: InkWell(
                        onTap: (_isLoading || _isGoogleLoading)
                            ? null
                            : _handleGoogleLogin,
                        borderRadius: BorderRadius.circular(16),
                        child: _isGoogleLoading
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF0C5050),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Connexion à Google...',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // G Logo Badge
                                  Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFFCBD5E1),
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
                                  const Text(
                                    'Continuer avec Google',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Footer Link: Pas encore de compte ? Créer un compte
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Pas encore de compte ? ',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => const RegisterScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            'Créer un compte',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0C5050),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
