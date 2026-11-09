import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  static const String _prefKey = 'selected_locale';
  Locale _locale = const Locale('fr');

  Locale get locale => _locale;

  LocaleProvider() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final languageCode = prefs.getString(_prefKey);
      if (languageCode != null && ['fr', 'en', 'ar'].contains(languageCode)) {
        _locale = Locale(languageCode);
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> setLocale(Locale newLocale, [BuildContext? context]) async {
    if (!['fr', 'en', 'ar'].contains(newLocale.languageCode)) return;
    _locale = newLocale;
    notifyListeners();

    if (context != null && context.mounted) {
      await context.setLocale(newLocale);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, newLocale.languageCode);
    } catch (_) {}
  }

  bool get isArabic => _locale.languageCode == 'ar';
}
