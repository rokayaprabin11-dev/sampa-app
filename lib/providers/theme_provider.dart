import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Light/dark preference.
///
/// Defaults to [ThemeMode.system] on a fresh install, so a device already in
/// dark mode opens Sampada in dark rather than forcing light. Once the user
/// flips the switch the choice is explicit and persisted, so it survives a
/// restart — it used to reset to light every launch.
class ThemeProvider with ChangeNotifier {
  static const _key = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.system;

  ThemeProvider() {
    _load();
  }

  ThemeMode get themeMode => _themeMode;

  /// Whether the app is currently showing dark — an explicit dark choice, or
  /// system mode on a device that is itself dark. Drives the settings switch, so
  /// it reflects what the user actually sees.
  bool get isDarkMode =>
      _themeMode == ThemeMode.dark ||
      (_themeMode == ThemeMode.system &&
          WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark);

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      if (saved != null) {
        _themeMode = ThemeMode.values.firstWhere(
          (m) => m.name == saved,
          orElse: () => ThemeMode.system,
        );
        notifyListeners();
      }
    } catch (_) {
      // First launch, or storage unavailable — keep the system default.
    }
  }

  Future<void> toggleTheme(bool isOn) async {
    _themeMode = isOn ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, _themeMode.name);
    } catch (_) {
      // A failed write is not worth surfacing — the choice still holds for this
      // session; it just won't survive a restart.
    }
  }
}
