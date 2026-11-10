import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:lottie/lottie.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../services/firebase_service.dart';
import 'onboarding_screen.dart';
import 'home_screen.dart';
import 'pro_home_screen.dart';
import 'admin_requests_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    _fadeController.forward();

    // Vérifier si un utilisateur est déjà connecté (session persistante ou redirect Google)
    _timer = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;

      // 1. Sur Web : vérifier d'abord un résultat de redirect Google en attente
      if (kIsWeb) {
        try {
          final redirectResult = await FirebaseAuth.instance.getRedirectResult();
          if (redirectResult.user != null && mounted) {
            final result = await FirebaseService().signInWithGoogle();
            if (result['success'] == true && mounted) {
              _navigateByRole(result);
              return;
            }
          }
        } catch (_) {}
      }

      // 2. Vérifier si un utilisateur est déjà connecté (session persistante)
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && mounted) {
        try {
          final data = await FirebaseService().getCurrentUserData();
          if (data != null && mounted) {
            final role = (data['role'] as String?)?.toLowerCase() ?? 'client';
            final fullName = data['fullName'] as String? ?? 'Utilisateur';
            final email = data['email'] as String? ?? currentUser.email ?? '';
            final phone = data['phone'] as String? ?? '';
            final serviceType = data['serviceType'] as String? ?? 'Plomberie';
            final mustChange = data['mustChangePassword'] == true;

            _navigateByRole({
              'success': true,
              'role': role,
              'fullName': fullName,
              'email': email,
              'phone': phone,
              'serviceType': serviceType,
              'mustChangePassword': mustChange,
            });
            return;
          }
        } catch (_) {}
      }

      // 3. Pas de session → aller vers Onboarding après 4 secondes
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 500),
            pageBuilder: (_, _, _) => const OnboardingScreen(),
            transitionsBuilder: (_, animation, _, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  void _navigateByRole(Map<String, dynamic> result) {
    if (!mounted) return;
    final role = (result['role'] as String?)?.toLowerCase() ?? 'client';
    final fullName = result['fullName'] as String? ?? 'Utilisateur';
    final email = result['email'] as String? ?? '';
    final phone = result['phone'] as String? ?? '';
    final serviceType = result['serviceType'] as String? ?? 'Plomberie';
    final mustChange = result['mustChangePassword'] == true;

    Widget screen;
    if (role == 'admin' || role == 'super_admin') {
      screen = AdminRequestsScreen(
        adminName: fullName,
        adminEmail: email,
        adminPhone: phone,
        adminRole: role,
        mustChangePassword: mustChange,
      );
    } else if (role == 'professionnel') {
      screen = ProHomeScreen(proName: fullName, serviceType: serviceType);
    } else {
      screen = HomeScreen(userName: fullName, userEmail: email, userPhone: phone);
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, _, _) => screen,
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      body: Stack(
        children: [
          // Background subtle ambient radial gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.1),
                  radius: 0.95,
                  colors: isDark
                      ? [
                          const Color(0xFF0F172A),
                          const Color(0xFF0F172A),
                          const Color(0xFF1E293B),
                        ]
                      : [
                          Colors.white,
                          const Color(0xFFF7FAF9),
                          const Color(0xFFEAF4F3),
                        ],
                ),
              ),
            ),
          ),
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Lottie Animation dar.json
                  SizedBox(
                    width: 250,
                    height: 250,
                    child: Lottie.asset(
                      'assets/animations/dar.json',
                      fit: BoxFit.contain,
                      repeat: true,
                      errorBuilder: (context, error, stackTrace) {
                        return Image.asset(
                          'assets/images/logo.png',
                          width: 120,
                          height: 120,
                          fit: BoxFit.contain,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  // App title
                  const Text(
                    'DAR PLUS',
                    style: TextStyle(
                      color: AppTheme.tealPrimary,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3.0,
                      fontFamily: 'sans-serif',
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Tagline
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.tealPrimary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.tealPrimary.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    child: const Text(
                      'Des professionnels à votre service',
                      style: TextStyle(
                        color: AppTheme.tealPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Bottom loading indicator
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppTheme.tealPrimary.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
