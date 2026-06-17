import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  /// Requests location permission.
  Future<bool> requestLocationPermission() async {
    final status = await Permission.location.request();
    return status.isGranted;
  }

  /// Checks if location permission is granted.
  Future<bool> isLocationPermissionGranted() async {
    return await Permission.location.isGranted;
  }

  /// Requests notification permission.
  Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Checks if notification permission is granted.
  Future<bool> isNotificationPermissionGranted() async {
    return await Permission.notification.isGranted;
  }

  /// Requests multiple permissions at once (e.g., during onboarding).
  Future<Map<Permission, PermissionStatus>> requestInitialPermissions() async {
    return await [
      Permission.location,
      Permission.notification,
    ].request();
  }

  /// Opens app settings if permissions are permanently denied.
  Future<bool> openAppSettings() async {
    return await openAppSettings();
  }
}







