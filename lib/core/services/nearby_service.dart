import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sampada/core/network/api_client.dart';
import 'package:sampada/core/network/api_endpoints.dart';
import 'package:sampada/core/services/device_id.dart';
import 'package:sampada/core/services/location_service.dart';
import 'package:sampada/data/repositories/geofence_repository_impl.dart';
import 'package:sampada/data/repositories/i_geofence_repository.dart';

/// Orchestrates the client half of the nearby-notification system:
///   1. fetch the nearest heritage regions from the backend,
///   2. register them as OS-native geofences (battery-cheap; fire even when the
///      app is backgrounded/killed),
///   3. on region ENTER, post a validated location fix so the server does the
///      authoritative check + dedup + push,
///   4. report the visit into the analytics funnel.
///
/// The server is the source of truth for whether/what to notify — the client
/// only supplies trustworthy fixes (accuracy + mock flag) and the entry signal.
class NearbyService {
  NearbyService({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;
  final IGeofenceRepository _geo = GeofenceRepositoryImpl();

  StreamSubscription<GeofenceEvent>? _sub;
  bool _started = false;
  DateTime? _lastRefresh;

  // iOS caps native regions at 20; register only the nearest.
  static const int _maxRegions = 20;
  static const double _regionRadiusKm = 10;

  Future<void> start() async {
    if (_started) return;
    if (!await _ensurePermission()) return;
    _started = true;
    _sub = _geo.geofenceEvents().listen(_onGeofence);
    await refreshRegions();
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _started = false;
  }

  Future<bool> _ensurePermission() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return false;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      return perm == LocationPermission.always ||
          perm == LocationPermission.whileInUse;
    } catch (_) {
      return false;
    }
  }

  Future<Position?> _fix() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
    } catch (_) {
      return null;
    }
  }

  /// Pull the nearest regions and (re)register them. Throttled to once/2 min so
  /// repeated calls (app resume, entry events) don't hammer the endpoint.
  Future<void> refreshRegions() async {
    final now = DateTime.now();
    if (_lastRefresh != null && now.difference(_lastRefresh!).inSeconds < 120) {
      return;
    }
    final pos = await _fix();
    if (pos == null) return;
    _lastRefresh = now;

    try {
      final data = await _apiClient.get(
        ApiEndpoints.locationGeofences,
        queryParameters: {
          'lat': pos.latitude,
          'lng': pos.longitude,
          'radius_km': _regionRadiusKm,
        },
      );
      final list = (data is Map ? data['results'] : data) as List? ?? [];
      for (final r in list.take(_maxRegions)) {
        if (r is! Map) continue;
        final lat = (r['lat'] as num?)?.toDouble();
        final lng = (r['lng'] as num?)?.toDouble();
        final slug = r['slug'] as String?;
        final radius = (r['geofence_radius_m'] as num?)?.toDouble() ?? 100;
        if (lat == null || lng == null || slug == null) continue;
        await _geo.addGeofence(
          id: slug, latitude: lat, longitude: lng, radiusMetres: radius);
      }
    } catch (e) {
      debugPrint('NearbyService.refreshRegions failed: $e');
    }
  }

  Future<void> _onGeofence(GeofenceEvent e) async {
    if (e.type != GeofenceEventType.enter) return;
    // Server decides whether to notify (cooldown/prefs/ranking) from the fix.
    await _postLocation();
    await reportEvent('heritage_visited', siteSlug: e.geofenceId);
  }

  Future<void> _postLocation() async {
    // Accuracy-gated + Kalman-smoothed fix — reject a poor/jittery reading and
    // wait for a good one rather than fire a false "you are near".
    final pos = await LocationService().getAccurateFix(maxAccuracyM: 30);
    if (pos == null) return;
    try {
      await _apiClient.post(ApiEndpoints.locationUpdate, data: {
        'lat': pos.latitude,
        'lng': pos.longitude,
        'accuracy_m': pos.accuracy,
        'is_mocked': pos.isMocked,
        'device_id': await DeviceId.get(),
      });
    } catch (e) {
      debugPrint('NearbyService.postLocation failed: $e');
    }
  }

  /// Report a funnel event (heritage_visited / notification_opened). Works for
  /// guests (device_id) and authed users (JWT header added by ApiClient).
  Future<void> reportEvent(String eventType, {String? siteSlug}) async {
    try {
      await _apiClient.post(ApiEndpoints.notificationEvents, data: {
        'event_type': eventType,
        'device_id': await DeviceId.get(),
        if (siteSlug != null) 'metadata': {'site_slug': siteSlug},
      });
    } catch (_) {/* analytics is best-effort */}
  }
}
