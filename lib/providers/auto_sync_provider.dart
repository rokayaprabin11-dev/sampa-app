import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:sampada/core/constants/prefs_keys.dart';
import 'package:sampada/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AutoSyncMode { wifiOnly, dataAndWifi, off }

/// Reports the device's active connections. Injectable so `shouldSync()` can be
/// unit-tested without a platform channel.
typedef ConnectivityCheck = Future<List<ConnectivityResult>> Function();

class AutoSyncProvider with ChangeNotifier {
  static const _prefKey = PrefsKeys.autoSyncMode;

  final ConnectivityCheck _checkConnectivity;

  AutoSyncMode _syncMode = AutoSyncMode.wifiOnly;
  AutoSyncMode get syncMode => _syncMode;

  AutoSyncProvider({ConnectivityCheck? checkConnectivity})
      : _checkConnectivity =
            checkConnectivity ?? (() => Connectivity().checkConnectivity()) {
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

  /// Whether an *automatic* refresh may hit the network right now. User-initiated
  /// actions (search, filter, pull-to-refresh) bypass this by design — see
  /// `HeritageProvider.fetchSites`.
  Future<bool> shouldSync() async {
    if (_syncMode == AutoSyncMode.off) return false;
    final result = await _checkConnectivity();
    final hasWifi = result.contains(ConnectivityResult.wifi);
    final hasMobile = result.contains(ConnectivityResult.mobile);
    if (_syncMode == AutoSyncMode.wifiOnly) return hasWifi;
    return hasWifi || hasMobile;
  }

  String getSyncModeLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (_syncMode) {
      case AutoSyncMode.wifiOnly:    return l10n.settingsWifiOnly;
      case AutoSyncMode.dataAndWifi: return l10n.settingsOn;
      case AutoSyncMode.off:         return l10n.settingsOff;
    }
  }
}
