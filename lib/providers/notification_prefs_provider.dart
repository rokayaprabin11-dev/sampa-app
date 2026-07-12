import 'package:flutter/material.dart';
import 'package:sampada/core/constants/prefs_keys.dart';
import 'package:sampada/core/services/nearby_service.dart';
import 'package:sampada/core/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Owns the two notification switches on the settings screen. Each one is
/// persisted to SharedPreferences *and* applied to the machinery that actually
/// delivers the notification:
///
///  * Push Notifications → FCM topic subscriptions (`all_users`, `lang_*`).
///    The backend broadcasts to those topics, so unsubscribing is what really
///    stops the pushes — a local flag alone would not.
///  * Nearby Site Alerts → NearbyService, which registers the OS-native
///    heritage geofences that trigger the "you are near" pushes.
///
/// Both are applied on startup too (see `applyOnStartup`), so a device that
/// opted out stays opted out across launches.
class NotificationPrefsProvider with ChangeNotifier {
  static const bool pushDefault = true;
  static const bool nearbyAlertsDefault = true;

  final NotificationService _notificationService;

  /// Null on web, where geofencing isn't wired up.
  final NearbyService? _nearbyService;

  NotificationPrefsProvider({
    required NotificationService notificationService,
    NearbyService? nearbyService,
  })  : _notificationService = notificationService,
        _nearbyService = nearbyService;

  bool _pushEnabled = pushDefault;
  bool _nearbyAlertsEnabled = nearbyAlertsDefault;

  bool get pushEnabled => _pushEnabled;
  bool get nearbyAlertsEnabled => _nearbyAlertsEnabled;

  /// Loads both prefs and brings the services in line with them. Call once at
  /// startup — NotificationService reads the push pref itself when it acquires
  /// its FCM token, so this is mainly what arms/disarms the geofences.
  Future<void> applyOnStartup() async {
    await _load();
    if (_nearbyAlertsEnabled) {
      await _nearbyService?.start();
    } else {
      debugPrint('NotificationPrefs: nearby alerts off — geofences not registered');
    }
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _pushEnabled = prefs.getBool(PrefsKeys.pushNotificationsEnabled) ?? pushDefault;
      _nearbyAlertsEnabled =
          prefs.getBool(PrefsKeys.nearbySiteAlertsEnabled) ?? nearbyAlertsDefault;
      notifyListeners();
    } catch (e) {
      debugPrint('NotificationPrefs: SharedPreferences unavailable, using defaults: $e');
    }
  }

  /// [language] is the user's UI language ('ne'/'en') — it selects the `lang_*`
  /// topic to (un)subscribe alongside `all_users`.
  Future<void> setPushEnabled(bool enabled, {String? language}) async {
    _pushEnabled = enabled;
    notifyListeners();
    await _persist(PrefsKeys.pushNotificationsEnabled, enabled);
    await _notificationService.setPushEnabled(enabled, language: language);
  }

  Future<void> setNearbyAlertsEnabled(bool enabled) async {
    _nearbyAlertsEnabled = enabled;
    notifyListeners();
    await _persist(PrefsKeys.nearbySiteAlertsEnabled, enabled);
    if (enabled) {
      await _nearbyService?.start();
    } else {
      await _nearbyService?.stop();
    }
  }

  Future<void> _persist(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (e) {
      debugPrint('NotificationPrefs: could not persist $key: $e');
    }
  }
}
