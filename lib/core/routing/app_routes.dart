import 'package:flutter/material.dart';
import '../../screens/splash_screen.dart';
import '../../screens/onboarding_screen.dart';
import '../../screens/login_screen.dart';
import '../../screens/register_screen.dart';
import '../../screens/home_screen.dart';
import '../../screens/pro_home_screen.dart';
import '../../screens/admin_requests_screen.dart';
import '../../screens/client_profile_screen.dart';
import '../../screens/catalog_search_screen.dart';
import '../../screens/service_detail_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String proHome = '/pro-home';
  static const String admin = '/admin';
  static const String profile = '/profile';
  static const String catalog = '/catalog';
  static const String serviceDetail = '/service-detail';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());

      case onboarding:
        return MaterialPageRoute(builder: (_) => const OnboardingScreen());

      case login:
        final email = settings.arguments as String?;
        return MaterialPageRoute(
          builder: (_) => LoginScreen(prefilledEmail: email),
        );

      case register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());

      case home:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => HomeScreen(
            userName: args['userName'] as String? ?? 'Client',
            userEmail: args['userEmail'] as String? ?? '',
            userPhone: args['userPhone'] as String? ?? '',
          ),
        );

      case proHome:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => ProHomeScreen(
            proName: args['proName'] as String? ?? 'Professionnel',
            serviceType: args['serviceType'] as String? ?? 'Service',
          ),
        );

      case admin:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => AdminRequestsScreen(
            adminName: args['adminName'] as String? ?? 'Administrateur',
            adminEmail: args['adminEmail'] as String? ?? '',
            adminRole: (args['isSuperAdmin'] == true || args['adminRole'] == 'super_admin')
                ? 'super_admin'
                : 'admin',
          ),
        );

      case profile:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => ClientProfileScreen(
            userName: args['userName'] as String? ?? 'Client',
            userEmail: args['userEmail'] as String? ?? '',
            userPhone: args['userPhone'] as String? ?? '',
          ),
        );

      case catalog:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => CatalogSearchScreen(
            initialCategory: args['category'] as String?,
            initialSearch: args['search'] as String?,
          ),
        );

      case serviceDetail:
        final pro = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => ServiceDetailScreen(proData: pro),
        );

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('Route non trouvée : ${settings.name}'),
            ),
          ),
        );
    }
  }
}
