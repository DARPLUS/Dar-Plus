import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/firebase_service.dart';
import 'home_screen.dart';
import 'pro_home_screen.dart';
import 'admin_requests_screen.dart';
import 'register_screen.dart';

enum LoginRole { client, professionnel, admin }

class LoginScreen extends StatefulWidget {
  final LoginRole initialRole;

  const LoginScreen({
    super.key,
    this.initialRole = LoginRole.client,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late LoginRole _selectedRole;
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.initialRole;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _quickFillDemo(LoginRole role) {
    setState(() {
      _selectedRole = role;
      if (role == LoginRole.admin) {
        _emailController.text = 'admin@darplus.tn';
        _passwordController.text = 'admin123';
      } else if (role == LoginRole.professionnel) {
        _emailController.text = 'ahmed.pro@darplus.tn';
        _passwordController.text = 'password123';
      } else {
        _emailController.text = 'client@darplus.tn';
        _passwordController.text = 'password123';
      }
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
      selectedRole: _selectedRole.name,
    );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });

    if (result['success'] == true) {
      final role = (result['role'] as String?)?.toLowerCase() ?? _selectedRole.name;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] as String),
          backgroundColor: const Color(0xFF0C5050),
          duration: const Duration(seconds: 2),
        ),
      );

      // Redirection dynamique selon le rôle
      if (role == 'admin') {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AdminRequestsScreen()),
          (route) => false,
        );
      } else if (role == 'professionnel') {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => ProHomeScreen(
              proName: _emailController.text.split('@').first,
            ),
          ),
          (route) => false,
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] as String),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showForgotPasswordDialog() {
    final resetEmailController =
        TextEditingController(text: _emailController.text);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Mot de passe oublié ?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.titleColor,
              fontFamily: 'serif',
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Entrez votre adresse email pour recevoir un lien de réinitialisation sécurisé.',
                style: TextStyle(fontSize: 13, color: AppTheme.subtitleColor),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE8E4DC)),
                ),
                child: TextField(
                  controller: resetEmailController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.mail_outline_rounded,
                        color: Color(0xFF6B7280), size: 20),
                    hintText: 'nom@email.com',
                    hintStyle:
                        TextStyle(color: Color(0xFF8B98A8), fontSize: 13.5),
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler',
                  style: TextStyle(color: AppTheme.subtitleColor)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final res = await FirebaseService()
                    .resetPassword(resetEmailController.text);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(res['message'] as String),
                      backgroundColor: const Color(0xFF0C5050),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0C5050),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text('Envoyer le lien'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. Dark Teal Top Header (matches screenshot)
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                top: topPadding + 20,
                bottom: 28,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF0C5050),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo container: D+ and DAR PLUS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: const Text(
                          'D+',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'DAR PLUS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          fontFamily: 'serif',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Vos services à domicile',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                      fontFamily: 'sans-serif',
                    ),
                  ),
                ],
              ),
            ),

            // 2. Main Login Form Body
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Segmented Role Toggle (Client / Professionnel / Admin)
                    Container(
                      height: 52,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECE8E1),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Row(
                        children: [
                          // Tab 1: Client
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedRole = LoginRole.client;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  color: _selectedRole == LoginRole.client
                                      ? const Color(0xFF0C5050)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.person_rounded,
                                      size: 17,
                                      color: _selectedRole == LoginRole.client
                                          ? Colors.white
                                          : const Color(0xFF7A8696),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Client',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: _selectedRole == LoginRole.client
                                            ? Colors.white
                                            : const Color(0xFF6B7A8E),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Tab 2: Professionnel
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedRole = LoginRole.professionnel;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  color: _selectedRole == LoginRole.professionnel
                                      ? const Color(0xFF0C5050)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.build_rounded,
                                      size: 15,
                                      color:
                                          _selectedRole == LoginRole.professionnel
                                              ? Colors.white
                                              : const Color(0xFF7A8696),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Professionnel',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            _selectedRole == LoginRole.professionnel
                                                ? Colors.white
                                                : const Color(0xFF6B7A8E),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Tab 3: Admin (unified for admin as requested!)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedRole = LoginRole.admin;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: _selectedRole == LoginRole.admin
                                    ? const Color(0xFF0C5050)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.shield_rounded,
                                    size: 15,
                                    color: _selectedRole == LoginRole.admin
                                        ? Colors.white
                                        : const Color(0xFF7A8696),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Admin',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: _selectedRole == LoginRole.admin
                                          ? Colors.white
                                          : const Color(0xFF6B7A8E),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Title: Connexion (matches screenshot)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Connexion',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0B1B2B),
                            fontFamily: 'serif',
                            letterSpacing: -0.4,
                          ),
                        ),
                        // Quick fill helper for demo
                        PopupMenuButton<LoginRole>(
                          tooltip: 'Remplissage rapide Démo',
                          icon: const Icon(Icons.flash_on_rounded,
                              color: AppTheme.orangePrimary, size: 20),
                          onSelected: _quickFillDemo,
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: LoginRole.client,
                              child: Text('Démo: Compte Client'),
                            ),
                            const PopupMenuItem(
                              value: LoginRole.professionnel,
                              child: Text('Démo: Compte Professionnel'),
                            ),
                            const PopupMenuItem(
                              value: LoginRole.admin,
                              child: Text('Démo: Compte Admin'),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Label: Email
                    const Text(
                      'Email',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Field 1: Email Input
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFE8E4DC),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
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
                          color: Color(0xFF0B1B2B),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          prefixIcon: Container(
                            width: 32,
                            height: 32,
                            margin: const EdgeInsets.only(left: 14, right: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7E8BA3).withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.mail_outline_rounded,
                              color: Color(0xFF6B7280),
                              size: 19,
                            ),
                          ),
                          prefixIconConstraints:
                              const BoxConstraints(minWidth: 58, minHeight: 48),
                          hintText: 'nom@email.com',
                          hintStyle: TextStyle(
                            color: const Color(0xFF8B98A8).withValues(alpha: 0.9),
                            fontSize: 14.5,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Label: Mot de passe
                    const Text(
                      'Mot de passe',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Field 2: Mot de passe Input
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFE8E4DC),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
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
                          color: Color(0xFF0B1B2B),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          prefixIcon: Container(
                            width: 32,
                            height: 32,
                            margin: const EdgeInsets.only(left: 14, right: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.lock_rounded,
                              color: Color(0xFFE8834F),
                              size: 19,
                            ),
                          ),
                          prefixIconConstraints:
                              const BoxConstraints(minWidth: 58, minHeight: 48),
                          hintText: '••••••••',
                          hintStyle: TextStyle(
                            color: const Color(0xFF8B98A8).withValues(alpha: 0.9),
                            fontSize: 14.5,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: const Color(0xFF4C3B71),
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

                    const SizedBox(height: 10),

                    // Mot de passe oublié ? (matches screenshot)
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: _showForgotPasswordDialog,
                        child: const Text(
                          'Mot de passe oublié?',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0C5050),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Action Button: Connexion (Dark teal, matches screenshot)
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
                            borderRadius: BorderRadius.circular(18),
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
                                'Connexion',
                                style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    // Separator: -- ou -- (matches screenshot)
                    Row(
                      children: [
                        const Expanded(
                          child: Divider(
                            color: Color(0xFFE2DDD5),
                            thickness: 1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            'ou',
                            style: TextStyle(
                              color:
                                  const Color(0xFF6B7A8E).withValues(alpha: 0.9),
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const Expanded(
                          child: Divider(
                            color: Color(0xFFE2DDD5),
                            thickness: 1,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Social login buttons: Google and Facebook (matches screenshot)
                    Row(
                      children: [
                        // Google button
                        Expanded(
                          child: _buildSocialButton(
                            label: 'Google',
                            iconWidget: const Icon(
                              Icons.language_rounded,
                              color: Color(0xFF38BDF8),
                              size: 20,
                            ),
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Connexion Google en cours...'),
                                  backgroundColor: Color(0xFF0C5050),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Facebook button
                        Expanded(
                          child: _buildSocialButton(
                            label: 'Facebook',
                            iconWidget: const Icon(
                              Icons.facebook_rounded,
                              color: Color(0xFF1877F2),
                              size: 21,
                            ),
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Connexion Facebook en cours...'),
                                  backgroundColor: Color(0xFF0C5050),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Footer Link: Pas de compte? S'inscrire (matches screenshot)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Pas de compte? ',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7A8E),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => RegisterScreen(
                                  initialType:
                                      _selectedRole == LoginRole.professionnel
                                          ? AccountType.professionnel
                                          : AccountType.client,
                                ),
                              ),
                            );
                          },
                          child: const Text(
                            'S\'inscrire',
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

  Widget _buildSocialButton({
    required String label,
    required Widget iconWidget,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE8E4DC),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              iconWidget,
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0B1B2B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
