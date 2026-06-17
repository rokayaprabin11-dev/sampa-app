import 'package:dartz/dartz.dart';
import 'package:sampada/data/models/user_location.dart';
import 'package:sampada/core/network/location_failure.dart';
import 'dart:math' as math;

class PredictUserMovement {
  /// Projects [current] position forward by [seconds] using simple
  /// dead-reckoning from speed + heading.
  Either<LocationFailure, UserLocation> call(
      UserLocation current, int seconds) {
    if (current.speed <= 0) {
      return right(current); // stationary — no prediction needed
    }

    const earthRadius = 6371000.0; // metres, WGS-84 mean radius
    final distanceMetres = current.speed * seconds;
    final angular = distanceMetres / earthRadius;

    final lat1 = _toRad(current.latitude);
    final lng1 = _toRad(current.longitude);
    final bearing = _toRad(current.heading);

    final lat2 = _toDeg(math.asin(math.sin(lat1) * math.cos(angular) +
        math.cos(lat1) * math.sin(angular) * math.cos(bearing)));
    final lng2 = _toDeg(lng1 +
        math.atan2(math.sin(bearing) * math.sin(angular) * math.cos(lat1),
            math.cos(angular) - math.sin(lat1) * math.sin(_toRad(lat2))));

    return right(UserLocation(
      latitude: lat2,
      longitude: lng2,
      accuracy: current.accuracy,
      altitude: current.altitude,
      speed: current.speed,
      heading: current.heading,
      timestamp: current.timestamp.add(Duration(seconds: seconds)),
    ));
  }

  double _toRad(double deg) => deg * math.pi / 180;
  double _toDeg(double rad) => rad * 180 / math.pi;
}







