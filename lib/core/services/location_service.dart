import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sampada/core/services/gps_kalman.dart';
import 'package:sampada/core/services/location_telemetry.dart';
import 'package:sampada/data/models/user_location.dart';

/// How trustworthy a returned fix is. [poor] means GPS conditions are bad
/// (indoors, urban canyon) and the position is a best-effort estimate.
enum FixQuality { excellent, good, poor, none }

/// Coarse movement classification from GPS speed, used to adapt update rates.
enum MovementState { stationary, walking, driving }

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

  /// Last accuracy-gated fix, reused for [cacheTtl] so every "nearby X" surface
  /// (heritage, events, guides, map) doesn't spin up its own GPS session.
  Position? _cachedFix;
  DateTime? _cachedAt;
  static const Duration cacheTtl = Duration(minutes: 5);

  /// Best sample from the last failed accurate-fix session (accuracy above the
  /// gate). Kept briefly so poor-GPS conditions can degrade gracefully instead
  /// of yielding nothing — see [getFixWithQuality].
  Position? _lastPoorFix;
  DateTime? _lastPoorFixAt;
  static const Duration _poorFixTtl = Duration(minutes: 2);

  /// Service-enabled + permission gate shared by all fix paths.
  /// Returns true only when a location read is actually possible.
  Future<bool> _ensureReady() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      debugPrint('Location services are disabled.');
      return false;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      debugPrint('Location permission not granted ($permission).');
      return false;
    }
    // Android 12+ / iOS 14+: user may grant only approximate location. A
    // reduced fix (~1-3 km) can never pass the 30 m gate — surface why.
    try {
      final acc = await Geolocator.getLocationAccuracy();
      if (acc == LocationAccuracyStatus.reduced) {
        debugPrint('Precise Location is OFF — only approximate fixes available.');
      }
    } catch (_) {/* not supported on this platform/version */}
    return true;
  }

  /// Gets the current position of the user (single raw fix, no accuracy gate).
  Future<Position?> getCurrentPosition() async {
    if (!await _ensureReady()) return null;
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.bestForNavigation),
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
    double excellentAccuracyM = 10,
    Duration timeout = const Duration(seconds: 8),
    int minSamples = 3,
    double minConfidence = 0.5,
    bool forceRefresh = false,
  }) async {
    // Serve the cached fix while fresh — repeated "nearby" calls within
    // [cacheTtl] cost zero GPS time/battery.
    if (!forceRefresh &&
        _cachedFix != null &&
        _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < cacheTtl &&
        _cachedFix!.accuracy <= maxAccuracyM) {
      LocationTelemetry().recordCacheHit();
      return _cachedFix;
    }

    if (!await _ensureReady()) {
      LocationTelemetry().recordFailure();
      return null;
    }

    final kalman = GpsKalman();
    Position? best;
    var count = 0;
    int? ttffMs;
    final stopwatch = Stopwatch()..start();
    final deadline = DateTime.now().add(timeout);

    try {
      final stream = Geolocator.getPositionStream(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.bestForNavigation),
      );
      await for (final p in stream) {
        count++;
        ttffMs ??= stopwatch.elapsedMilliseconds;
        if (best == null || p.accuracy < best.accuracy) best = p;
        kalman.process(
          p.latitude, p.longitude, p.accuracy, p.timestamp.millisecondsSinceEpoch);

        final smoothedAcc = kalman.accuracy ?? p.accuracy;
        // Dynamic accuracy policy: an excellent fix ends the session early —
        // no point burning GPS time collecting more samples.
        if (smoothedAcc <= excellentAccuracyM) break;
        if (count >= minSamples && smoothedAcc <= maxAccuracyM) break;
        if (DateTime.now().isAfter(deadline)) break;
      }
    } catch (e) {
      debugPrint('getAccurateFix stream error: $e');
    }

    // Prefer the smoothed estimate when it's good enough; else the best raw
    // sample; else null (no trustworthy fix).
    Position? result;
    if (kalman.hasEstimate && (kalman.accuracy ?? 999) <= maxAccuracyM && best != null) {
      result = _copyWith(best, kalman.latitude!, kalman.longitude!, kalman.accuracy!);
    } else if (best != null && best.accuracy <= maxAccuracyM) {
      result = best;
    }

    // Confidence gate: accuracy alone isn't trust — stale timestamps, mock
    // providers and impossible speeds all downgrade the fix.
    if (result != null && confidenceOf(result) < minConfidence) {
      debugPrint('getAccurateFix: fix rejected by confidence gate '
          '(${confidenceOf(result).toStringAsFixed(2)} < $minConfidence)');
      best = result;
      result = null;
    }

    if (result != null) {
      _cachedFix = result;
      _cachedAt = DateTime.now();
      LocationTelemetry().recordFix(
        ttffMillis: ttffMs ?? stopwatch.elapsedMilliseconds,
        accuracyM: result.accuracy,
      );
    } else {
      // Retain the best (sub-par) sample so poor-GPS surfaces can degrade
      // gracefully via getFixWithQuality instead of showing nothing.
      if (best != null) {
        _lastPoorFix = best;
        _lastPoorFixAt = DateTime.now();
      }
      LocationTelemetry().recordFailure();
    }
    return result;
  }

  /// Score a fix 0..1 from accuracy, age, mock flag and speed plausibility.
  /// 1.0 = fresh, precise, organic; below ~0.5 should not drive user-visible
  /// "you are here / near" decisions.
  double confidenceOf(Position p) {
    var score = 1.0;
    // Accuracy: ≤10 m keeps full score, degrades linearly to −0.6 at 100 m.
    if (p.accuracy > 10) score -= ((p.accuracy - 10) / 90).clamp(0.0, 0.6);
    // Age: fixes older than 10 s decay, −0.3 by 5 min.
    final ageS = DateTime.now().difference(p.timestamp).inSeconds;
    if (ageS > 10) score -= ((ageS - 10) / 290).clamp(0.0, 0.3);
    // Mock provider (fake-GPS app) — heavy penalty; server rejects these too.
    if (p.isMocked) score -= 0.5;
    // Implausible speed (>200 km/h) — likely a jump between cell fixes.
    if (p.speed > 55) score -= 0.3;
    return score.clamp(0.0, 1.0);
  }

  /// Accuracy fix plus an explicit quality signal. Indoors/urban-canyon GPS
  /// (all samples above the gate) degrades to the best recent sample tagged
  /// [FixQuality.poor] instead of failing outright — callers decide whether a
  /// rough position is still useful (map recenter: yes; geofence post: no).
  Future<(Position?, FixQuality)> getFixWithQuality({
    double maxAccuracyM = 30,
    Duration timeout = const Duration(seconds: 8),
    bool forceRefresh = false,
  }) async {
    final fix = await getAccurateFix(
      maxAccuracyM: maxAccuracyM,
      timeout: timeout,
      forceRefresh: forceRefresh,
    );
    if (fix != null) {
      return (fix, fix.accuracy <= 10 ? FixQuality.excellent : FixQuality.good);
    }
    if (_lastPoorFix != null &&
        _lastPoorFixAt != null &&
        DateTime.now().difference(_lastPoorFixAt!) < _poorFixTtl) {
      LocationTelemetry().recordPoorGpsFallback();
      return (_lastPoorFix, FixQuality.poor);
    }
    return (null, FixQuality.none);
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

  /// Streams the user's position with adaptive update intervals: the distance
  /// filter is tuned to the current movement state so a stationary user costs
  /// almost no battery while a driving user still gets timely updates.
  ///
  ///   stationary → 50 m filter (few/no updates while standing at a site)
  ///   walking    → 10 m filter (~every 7 s at walking pace)
  ///   driving    → 25 m filter (~every 2 s at 50 km/h)
  Stream<Position> getPositionStream() {
    late StreamController<Position> controller;
    StreamSubscription<Position>? sub;
    var state = MovementState.walking; // sensible default until speed known

    int filterFor(MovementState s) => switch (s) {
          MovementState.stationary => 50,
          MovementState.walking => 10,
          MovementState.driving => 25,
        };

    MovementState classify(Position p) {
      final v = p.speed;
      // Untrustworthy speed readings keep the current state (hysteresis).
      if (v.isNaN || v < 0 || p.speedAccuracy > 3) return state;
      if (v < 0.7) return MovementState.stationary;
      if (v < 3.0) return MovementState.walking;
      return MovementState.driving;
    }

    void subscribe() {
      sub = Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: filterFor(state),
        ),
      ).listen((p) {
        controller.add(p);
        final next = classify(p);
        if (next != state) {
          state = next;
          sub?.cancel();
          subscribe(); // re-subscribe with the new distance filter
        }
      }, onError: controller.addError);
    }

    controller = StreamController<Position>(
      onListen: subscribe,
      onCancel: () async => sub?.cancel(),
    );
    return controller.stream;
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







