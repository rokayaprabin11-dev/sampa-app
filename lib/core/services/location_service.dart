import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import 'package:sampada/core/services/gps_kalman.dart';
import 'package:sampada/data/models/user_location.dart';

extension PositionMapper on Position {
  UserLocation toUserLocation() => UserLocation(
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
        altitude: altitude,
        speed: speed,
        heading: heading,
        timestamp: timestamp,
      );
}

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  /// Registers a Geofence at the OS level (Next-Gen Battery Optimization)
  Future<void> registerGeofence({
    required String id,
    required double latitude,
    required double longitude,
    required double radius,
  }) async {
    // In production, use a plugin like flutter_background_geofencing
    // for native Android Geofencing and iOS Region Monitoring
    debugPrint('Geofence registered: $id at ($latitude, $longitude) with radius $radius');
  }

  /// Gets the current position of the user.
  Future<Position?> getCurrentPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Location services are disabled.');
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('Location permissions are denied');
        return null;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      debugPrint('Location permissions are permanently denied, we cannot request permissions.');
      return null;
    } 

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
    } catch (e) {
      debugPrint('Error getting current position: $e');
      return null;
    }
  }

  /// Collect several GPS fixes, Kalman-smooth them, and return a position that
  /// meets [maxAccuracyM] — or null if none arrives within [timeout] ("wait for
  /// better GPS" instead of acting on a jittery/poor fix). Used before posting a
  /// geofence entry so a 60m-accuracy fix can't fire a false "you are near".
  Future<Position?> getAccurateFix({
    double maxAccuracyM = 30,
    Duration timeout = const Duration(seconds: 8),
    int minSamples = 3,
  }) async {
    final kalman = GpsKalman();
    Position? best;
    var count = 0;
    final deadline = DateTime.now().add(timeout);

    try {
      final stream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      await for (final p in stream) {
        count++;
        if (best == null || p.accuracy < best.accuracy) best = p;
        kalman.process(
          p.latitude, p.longitude, p.accuracy, p.timestamp.millisecondsSinceEpoch);

        final smoothedAcc = kalman.accuracy ?? p.accuracy;
        if (count >= minSamples && smoothedAcc <= maxAccuracyM) break;
        if (DateTime.now().isAfter(deadline)) break;
      }
    } catch (e) {
      debugPrint('getAccurateFix stream error: $e');
    }

    // Prefer the smoothed estimate when it's good enough; else the best raw
    // sample; else null (no trustworthy fix).
    if (kalman.hasEstimate && (kalman.accuracy ?? 999) <= maxAccuracyM && best != null) {
      return _copyWith(best, kalman.latitude!, kalman.longitude!, kalman.accuracy!);
    }
    if (best != null && best.accuracy <= maxAccuracyM) return best;
    return null;
  }

  Position _copyWith(Position base, double lat, double lng, double accuracy) => Position(
        latitude: lat,
        longitude: lng,
        timestamp: base.timestamp,
        accuracy: accuracy,
        altitude: base.altitude,
        altitudeAccuracy: base.altitudeAccuracy,
        heading: base.heading,
        headingAccuracy: base.headingAccuracy,
        speed: base.speed,
        speedAccuracy: base.speedAccuracy,
        isMocked: base.isMocked,
      );

  /// Gets the user's current bearing (heading) in degrees.
  double? getBearing(Position current, Position previous) {
    return Geolocator.bearingBetween(
      previous.latitude, previous.longitude,
      current.latitude, current.longitude,
    );
  }

  /// Calculates the distance between two coordinates in meters.
  double calculateDistance(double startLat, double startLng, double endLat, double endLng) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  /// Streams the user's position.
  Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    );
  }

  /// Predicts the user's position in [seconds] using a simple Kalman-like constant velocity model.
  Position predictFuturePosition(Position current, double? bearing, double velocity, int seconds) {
    if (bearing == null || velocity == 0) return current;

    // Convert bearing to radians
    final double angle = (bearing * math.pi) / 180;
    
    // Calculate displacement (d = v * t)
    final double distance = velocity * seconds;
    
    // Earth's radius in meters
    const double radius = 6371000;

    final double lat1 = (current.latitude * math.pi) / 180;
    final double lon1 = (current.longitude * math.pi) / 180;

    final double lat2 = math.asin(math.sin(lat1) * math.cos(distance / radius) +
        math.cos(lat1) * math.sin(distance / radius) * math.cos(angle));

    final double lon2 = lon1 +
        math.atan2(math.sin(angle) * math.sin(distance / radius) * math.cos(lat1),
            math.cos(distance / radius) - math.sin(lat1) * math.sin(lat2));

    return Position(
      latitude: (lat2 * 180) / math.pi,
      longitude: (lon2 * 180) / math.pi,
      timestamp: DateTime.now(),
      accuracy: current.accuracy,
      altitude: current.altitude,
      heading: bearing,
      speed: velocity,
      speedAccuracy: current.speedAccuracy,
      altitudeAccuracy: current.altitudeAccuracy,
      headingAccuracy: current.headingAccuracy,
    );
  }
}







