import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';

import 'theme/app_theme.dart';
import 'services/firebase_service.dart';
import 'providers/theme_provider.dart';
import 'providers/locale_provider.dart';
import 'core/routing/app_routes.dart';
import 'core/localization/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // Initialize Firebase (supports both active Firebase config and local fallback)
  await FirebaseService().init();

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
      supportedLocales: const [
        Locale('fr'),
        Locale('en'),
        Locale('ar'),
      ],
      path: 'assets/translations',
      fallbackLocale: const Locale('fr'),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
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
    );
  }
}
