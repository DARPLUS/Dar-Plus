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
import '../../screens/checkout_screen.dart';
import '../../screens/payment_status_screen.dart';
import '../../screens/payment_history_screen.dart';
import '../../screens/bookings_screen.dart';
import '../../screens/booking_detail_screen.dart';
import '../../screens/urgency_screen.dart';
import '../../screens/map_screen.dart';

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
  static const String checkout = '/checkout';
  static const String paymentStatus = '/payment-status';
  static const String paymentHistory = '/payment-history';
  static const String bookings = '/bookings';
  static const String bookingDetail = '/booking-detail';
  static const String urgency = '/urgency';
  static const String map = '/map';

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

      case bookings:
        return MaterialPageRoute(builder: (_) => const BookingsScreen());

      case bookingDetail:
        final booking = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => BookingDetailScreen(booking: booking),
        );

      case urgency:
        return MaterialPageRoute(builder: (_) => const UrgencyScreen());

      case map:
        return MaterialPageRoute(builder: (_) => const MapScreen());

      case checkout:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => CheckoutScreen(
            bookingId: args['bookingId'] as String? ?? '',
            proId: args['proId'] as String? ?? '',
            proName: args['proName'] as String? ?? 'Artisan',
            serviceType: args['serviceType'] as String? ?? 'Service',
            baseAmount: (args['baseAmount'] as num?)?.toDouble() ?? 45.0,
            address: args['address'] as String? ?? 'Tunis',
            scheduledDate: args['scheduledDate'] as String?,
          ),
        );

      case paymentStatus:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => PaymentStatusScreen(
            paymentId: args['paymentId'] as String? ?? '',
            autoSimulateServerResponse: args['autoSimulate'] as bool? ?? false,
          ),
        );

      case paymentHistory:
        return MaterialPageRoute(
          builder: (_) => const PaymentHistoryScreen(),
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
