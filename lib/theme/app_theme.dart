import 'package:flutter/material.dart';

class AppTheme {
  static const Color background = Color(0xFFFAF7F4);
  static const Color tealPrimary = Color(0xFF0F6B6B);
  static const Color orangePrimary = Color(0xFFE8834F);
  static const Color secondaryButtonBg = Color(0xFFF0EDE2);
  static const Color titleColor = Color(0xFF0B1B2B);
  static const Color subtitleColor = Color(0xFF67768A);
  static const Color indicatorInactive = Color(0xFFE5E0D8);
  static const Color frostedGlassBg = Color(0x66000000); // 40% translucent black

  static ThemeData get lightTheme {
    return ThemeData(
      scaffoldBackgroundColor: background,
      primaryColor: tealPrimary,
      fontFamily: 'Georgia',
      colorScheme: const ColorScheme.light(
        primary: tealPrimary,
        secondary: orangePrimary,
        surface: background,
      ),
      useMaterial3: true,
    );
  }
}
