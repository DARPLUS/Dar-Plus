import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'theme/app_theme.dart';
import 'services/firebase_service.dart';
import 'providers/theme_provider.dart';
import 'providers/locale_provider.dart';
import 'core/routing/app_routes.dart';
import 'core/localization/app_localizations.dart';
import 'services/ads_service.dart';
import 'services/app_check_service.dart';
import 'widgets/call_overlay.dart';
import 'providers/ai_assistant_provider.dart';
import 'providers/commission_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // Charger les variables d'environnement depuis .env
  await dotenv.load(fileName: '.env');

  // Initialize Firebase (supports both active Firebase config and local fallback)
  await FirebaseService().init();
  await AppCheckService.initialize();
  await AdsService.initialize();

  // Immersive edge-to-edge transparent system UI overlay
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: AppTheme.background,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('fr'), Locale('en'), Locale('ar')],
      path: 'assets/translations',
      fallbackLocale: const Locale('fr'),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
          ChangeNotifierProvider(create: (_) => AiAssistantProvider()),
          ChangeNotifierProvider(create: (_) => CommissionProvider()),
        ],
        child: const DarPlusApp(),
      ),
    ),
  );
}

class DarPlusApp extends StatelessWidget {
  const DarPlusApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    context.watch<LocaleProvider>();

    return MaterialApp(
      title: 'DAR PLUS',
      debugShowCheckedModeBanner: false,
      navigatorKey: AppRoutes.navigatorKey,

      // Themes
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,

      // Localization & RTL support powered by EasyLocalization
      localizationsDelegates: [
        ...context.localizationDelegates,
        AppLocalizations.delegate,
      ],
      supportedLocales: context.supportedLocales,
      locale: context.locale,

      // Advanced Navigation with Named Routes
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.onGenerateRoute,

      // Superposition globale des appels audio (client <-> professionnel)
      builder: (context, child) =>
          CallOverlay(child: child ?? const SizedBox.shrink()),
    );
  }
}
