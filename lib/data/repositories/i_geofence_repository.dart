import 'package:dartz/dartz.dart';
import 'package:sampada/core/network/geofence_failure.dart';

abstract class IGeofenceRepository {
  Future<Either<GeofenceFailure, Unit>> addGeofence({
    required String id,
    required double latitude,
    required double longitude,
    required double radiusMetres,
  });
  Future<Either<GeofenceFailure, Unit>> removeGeofence(String id);
  Stream<GeofenceEvent> geofenceEvents();
}

enum GeofenceEventType { enter, dwell, exit }

class GeofenceEvent {
  final String geofenceId;
  final GeofenceEventType type;
  const GeofenceEvent(this.geofenceId, this.type);
}







