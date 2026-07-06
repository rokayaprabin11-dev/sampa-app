import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

/// Stable per-install device identifier used as the guest visitor key for
/// nearby notifications + funnel analytics. Mirrors the id NotificationService
/// registers with (DeviceRegistration.device_id) so guest geofencing lines up.
class DeviceId {
  DeviceId._();

  static String? _cached;

  static Future<String> get() async {
    if (_cached != null) return _cached!;
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        _cached = (await info.androidInfo).id;
      } else if (Platform.isIOS) {
        _cached = (await info.iosInfo).identifierForVendor ?? 'unknown';
      }
    } catch (_) {/* fall through */}
    _cached ??= 'unknown';
    return _cached!;
  }
}
