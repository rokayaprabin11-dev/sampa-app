import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sampada/providers/auto_sync_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Builds a provider whose connectivity check is stubbed, so `shouldSync()` is
/// exercised without touching a platform channel.
AutoSyncProvider _providerOn(List<ConnectivityResult> connections) {
  return AutoSyncProvider(checkConnectivity: () async => connections);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('AutoSyncProvider.shouldSync', () {
    test('off never syncs, even on WiFi', () async {
      final provider = _providerOn([ConnectivityResult.wifi]);
      await provider.setSyncMode(AutoSyncMode.off);

      expect(await provider.shouldSync(), isFalse);
    });

    test('wifiOnly syncs on WiFi', () async {
      final provider = _providerOn([ConnectivityResult.wifi]);
      await provider.setSyncMode(AutoSyncMode.wifiOnly);

      expect(await provider.shouldSync(), isTrue);
    });

    test('wifiOnly does not sync on mobile data', () async {
      final provider = _providerOn([ConnectivityResult.mobile]);
      await provider.setSyncMode(AutoSyncMode.wifiOnly);

      expect(await provider.shouldSync(), isFalse);
    });

    test('wifiOnly syncs when WiFi and mobile are both up', () async {
      final provider = _providerOn([
        ConnectivityResult.mobile,
        ConnectivityResult.wifi,
      ]);
      await provider.setSyncMode(AutoSyncMode.wifiOnly);

      expect(await provider.shouldSync(), isTrue);
    });

    test('dataAndWifi syncs on mobile data', () async {
      final provider = _providerOn([ConnectivityResult.mobile]);
      await provider.setSyncMode(AutoSyncMode.dataAndWifi);

      expect(await provider.shouldSync(), isTrue);
    });

    test('dataAndWifi does not sync with no connection', () async {
      final provider = _providerOn([ConnectivityResult.none]);
      await provider.setSyncMode(AutoSyncMode.dataAndWifi);

      expect(await provider.shouldSync(), isFalse);
    });

    test('wifiOnly does not sync with no connection', () async {
      final provider = _providerOn([ConnectivityResult.none]);
      await provider.setSyncMode(AutoSyncMode.wifiOnly);

      expect(await provider.shouldSync(), isFalse);
    });
  });

  group('AutoSyncProvider persistence', () {
    test('defaults to wifiOnly on a fresh install', () {
      expect(_providerOn([]).syncMode, AutoSyncMode.wifiOnly);
    });

    test('setSyncMode writes the mode to SharedPreferences', () async {
      final provider = _providerOn([]);
      await provider.setSyncMode(AutoSyncMode.off);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('auto_sync_mode'), 'off');
    });

    test('a stored mode is restored on construction', () async {
      SharedPreferences.setMockInitialValues({'auto_sync_mode': 'dataAndWifi'});

      final provider = _providerOn([]);
      // The constructor kicks off an async load; let it settle.
      await Future<void>.delayed(Duration.zero);

      expect(provider.syncMode, AutoSyncMode.dataAndWifi);
    });
  });
}
