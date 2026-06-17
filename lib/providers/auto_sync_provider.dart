import 'package:flutter/material.dart';

enum AutoSyncMode { wifiOnly, dataAndWifi, off }

class AutoSyncProvider with ChangeNotifier {
  AutoSyncMode _syncMode = AutoSyncMode.wifiOnly;

  AutoSyncMode get syncMode => _syncMode;

  String getSyncModeLabel(BuildContext context) {
    // Note: Can be moved to l10n later
    switch (_syncMode) {
      case AutoSyncMode.wifiOnly:
        return 'WiFi Only';
      case AutoSyncMode.dataAndWifi:
        return 'Data & WiFi';
      case AutoSyncMode.off:
        return 'Off';
    }
  }

  void setSyncMode(AutoSyncMode mode) {
    _syncMode = mode;
    notifyListeners();
  }
}







