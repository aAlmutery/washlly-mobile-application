import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleNotifier extends ChangeNotifier {
  static const _key = 'app_locale';

  Locale _locale = const Locale('ar');
  Locale get locale => _locale;

  LocaleNotifier() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key) ?? 'ar';
    _locale = Locale(code);
    notifyListeners();
  }

  Future<void> setLocale(String languageCode) async {
    if (_locale.languageCode == languageCode) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, languageCode);
    _locale = Locale(languageCode);
    notifyListeners();
  }
}
