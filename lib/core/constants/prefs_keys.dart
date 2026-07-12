/// SharedPreferences keys that are read from more than one layer, so the string
/// literal lives in exactly one place.
class PrefsKeys {
  const PrefsKeys._();

  /// Master push switch. NotificationService checks it at startup before
  /// subscribing to FCM topics; NotificationPrefsProvider writes it.
  static const String pushNotificationsEnabled = 'push_notifications_enabled';

  /// Whether native heritage geofences are registered (NearbyService).
  static const String nearbySiteAlertsEnabled = 'nearby_site_alerts_enabled';

  /// Serialized [AutoSyncMode] name.
  static const String autoSyncMode = 'auto_sync_mode';
}
