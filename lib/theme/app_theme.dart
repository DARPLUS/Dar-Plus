import 'package:flutter/material.dart';

class AppTheme {
  // Light Theme Colors
  static const Color background = Color(0xFFFAF7F4);
  static const Color cardLight = Colors.white;
  static const Color tealPrimary = Color(0xFF0D544E);
  static const Color orangePrimary = Color(0xFFDE6D1B);
  static const Color secondaryButtonBg = Color(0xFFF0EDE2);
  static const Color titleColor = Color(0xFF0B1B2B);
  static const Color subtitleColor = Color(0xFF67768A);
  static const Color indicatorInactive = Color(0xFFE5E0D8);
  static const Color frostedGlassBg = Color(0x66000000);

  // Dark Theme Colors
  static const Color darkBackground = Color(0xFF0F172A); // Slate 900
  static const Color darkSurface = Color(0xFF1E293B);    // Slate 800
  static const Color darkCard = Color(0xFF1E293B);       // Slate 800
  static const Color darkTitle = Color(0xFFF8FAFC);      // Slate 50
  static const Color darkSubtitle = Color(0xFF94A3B8);   // Slate 400
  static const Color darkDivider = Color(0xFF334155);    // Slate 700

  // Helpers pour adapter les couleurs dynamiquement
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color titleColorOf(BuildContext context) =>
      isDark(context) ? darkTitle : titleColor;

  static Color subtitleColorOf(BuildContext context) =>
      isDark(context) ? darkSubtitle : subtitleColor;

  static Color cardColorOf(BuildContext context) =>
      isDark(context) ? darkCard : cardLight;

  static Color surfaceColorOf(BuildContext context) =>
      isDark(context) ? darkSurface : Colors.white;

  static Color borderColorOf(BuildContext context) =>
      isDark(context) ? darkDivider : const Color(0xFFDDE3EA);

  static Color inputBgOf(BuildContext context) =>
      isDark(context) ? darkCard : Colors.white;

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      primaryColor: tealPrimary,
      cardColor: cardLight,
      fontFamily: 'Georgia',
      colorScheme: const ColorScheme.light(
        primary: tealPrimary,
        secondary: orangePrimary,
        surface: cardLight,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: titleColor,
        outline: Color(0xFFDDE3EA),
        error: Color(0xFFDC2626),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: titleColor,
        elevation: 0,
        centerTitle: false,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      cardTheme: CardThemeData(
        color: cardLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFEDE8E1)),
        ),
      ),
      listTileTheme: const ListTileThemeData(tileColor: cardLight),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFDDE3EA)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFDDE3EA)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: tealPrimary, width: 1.5),
        ),
      ),
      dividerColor: const Color(0xFFE2E8F0),
      useMaterial3: true,
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      primaryColor: const Color(0xFF14B8A6),
      cardColor: darkCard,
      fontFamily: 'Georgia',
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF14B8A6),
        secondary: orangePrimary,
        surface: darkSurface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: darkTitle,
        outline: darkDivider,
        error: Color(0xFFEF4444),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        foregroundColor: darkTitle,
        elevation: 0,
        centerTitle: false,
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: darkSurface,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: darkDivider),
        ),
      ),
      listTileTheme: const ListTileThemeData(tileColor: darkCard),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: darkDivider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: darkDivider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF14B8A6), width: 1.5),
        ),
      ),
      dividerColor: darkDivider,
      useMaterial3: true,
    );
  }
}

extension AppThemeContext on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
  Color get themeCardBg => isDarkMode ? AppTheme.darkCard : AppTheme.cardLight;
  Color get themeTextPrimary => isDarkMode ? AppTheme.darkTitle : AppTheme.titleColor;
  Color get themeTextSecondary => isDarkMode ? AppTheme.darkSubtitle : AppTheme.subtitleColor;
  Color get themeBorder => isDarkMode ? AppTheme.darkDivider : const Color(0xFFDDE3EA);
  Color get themeScaffoldBg => Theme.of(this).scaffoldBackgroundColor;
}
