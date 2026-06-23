import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AutoSyncMode { wifiOnly, dataAndWifi, off }

class AutoSyncProvider with ChangeNotifier {
  static const _prefKey = 'auto_sync_mode';

  AutoSyncMode _syncMode = AutoSyncMode.wifiOnly;
  AutoSyncMode get syncMode => _syncMode;

  AutoSyncProvider() {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved != null) {
        _syncMode = AutoSyncMode.values.firstWhere(
          (m) => m.name == saved,
          orElse: () => AutoSyncMode.wifiOnly,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('AutoSyncProvider: SharedPreferences unavailable, using default: $e');
    }
  }

  Future<void> setSyncMode(AutoSyncMode mode) async {
    _syncMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, mode.name);
    } catch (e) {
      debugPrint('AutoSyncProvider: Could not persist sync mode: $e');
    }
  }

  /// Returns true if a remote sync should be attempted right now.
  Future<bool> shouldSync() async {
    if (_syncMode == AutoSyncMode.off) return false;
    final result = await Connectivity().checkConnectivity();
    final hasWifi = result.contains(ConnectivityResult.wifi);
    final hasMobile = result.contains(ConnectivityResult.mobile);
    if (_syncMode == AutoSyncMode.wifiOnly) return hasWifi;
    return hasWifi || hasMobile;
  }

  String getSyncModeLabel(BuildContext context) {
    switch (_syncMode) {
      case AutoSyncMode.wifiOnly:   return 'WiFi Only';
      case AutoSyncMode.dataAndWifi: return 'Data & WiFi';
      case AutoSyncMode.off:        return 'Off';
    }
  }
}
