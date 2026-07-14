import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// UI language.
///
/// Seeds from the device language on a fresh install (Nepali if the phone is
/// Nepali, else English), and persists the user's explicit choice so it survives
/// a restart — it used to reset to English every launch.
class LocaleProvider with ChangeNotifier {
  static const _key = 'locale_code';
  static const _supported = ['en', 'ne'];

  Locale _locale = _deviceDefault();

  LocaleProvider() {
    _load();
  }

  Locale get locale => _locale;

  static Locale _deviceDefault() {
    final code = PlatformDispatcher.instance.locale.languageCode;
    return Locale(_supported.contains(code) ? code : 'en');
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_key);
      if (code != null && _supported.contains(code)) {
        _locale = Locale(code);
        notifyListeners();
      }
    } catch (_) {
      // Keep the device default.
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (!_supported.contains(locale.languageCode)) return;
    _locale = locale;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, locale.languageCode);
    } catch (_) {}
  }

  Future<void> clearLocale() async {
    _locale = _deviceDefault();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}
