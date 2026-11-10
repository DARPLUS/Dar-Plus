import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _prefKey = 'app_theme_mode';
  static const String _legacyPrefKey = 'is_dark_mode';

  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isSystemMode => _themeMode == ThemeMode.system;
  bool get isLightMode => _themeMode == ThemeMode.light;

  /// Détermine si le thème affiché à l'écran est sombre (prend en compte le mode système)
  bool isDark(BuildContext context) {
    if (_themeMode == ThemeMode.system) {
      return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  ThemeProvider() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeStr = prefs.getString(_prefKey);
      if (modeStr != null) {
        switch (modeStr) {
          case 'dark':
            _themeMode = ThemeMode.dark;
            break;
          case 'light':
            _themeMode = ThemeMode.light;
            break;
          case 'system':
          default:
            _themeMode = ThemeMode.system;
            break;
        }
      } else if (prefs.containsKey(_legacyPrefKey)) {
        final legacyDark = prefs.getBool(_legacyPrefKey) ?? false;
        _themeMode = legacyDark ? ThemeMode.dark : ThemeMode.light;
      } else {
        _themeMode = ThemeMode.system;
      }
      notifyListeners();
    } catch (_) {}
  }

  /// Changer explicitement le mode de thème (Système, Clair ou Sombre)
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      String val = 'system';
      if (mode == ThemeMode.dark) val = 'dark';
      if (mode == ThemeMode.light) val = 'light';
      await prefs.setString(_prefKey, val);
      await prefs.setBool(_legacyPrefKey, mode == ThemeMode.dark);
    } catch (_) {}
  }

  /// Basculer binaire pour compatibilité
  Future<void> toggleTheme(bool isDark) async {
    await setThemeMode(isDark ? ThemeMode.dark : ThemeMode.light);
  }
}
