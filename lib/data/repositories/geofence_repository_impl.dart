import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:geofencing_api/geofencing_api.dart';
import 'package:sampada/data/repositories/i_geofence_repository.dart';
import 'package:sampada/core/network/geofence_failure.dart';

class GeofenceRepositoryImpl implements IGeofenceRepository {
  final _eventController = StreamController<GeofenceEvent>.broadcast();

  GeofenceRepositoryImpl() {
    Geofencing.instance.addGeofenceStatusChangedListener((region, status, location) async {
      GeofenceEventType? type;
      switch (status) {
        case GeofenceStatus.enter:
          type = GeofenceEventType.enter;
          break;
        case GeofenceStatus.exit:
          type = GeofenceEventType.exit;
          break;
        case GeofenceStatus.dwell:
          type = GeofenceEventType.dwell;
          break;
      }
      if (type != null) {
        _eventController.add(GeofenceEvent(region.id, type));
      }
    });
  }

  @override
  Future<Either<GeofenceFailure, Unit>> addGeofence({
    required String id,
    required double latitude,
    required double longitude,
    required double radiusMetres,
  }) async {
    try {
      final region = GeofenceCircularRegion(
        id: id,
        center: LatLng(latitude, longitude),
        radius: radiusMetres,
      );
      Geofencing.instance.addRegion(region);
      if (!Geofencing.instance.isRunningService) {
        await Geofencing.instance.start();
      }
      return right(unit);
    } catch (e) {
      return left(GeofenceFailure.setupFailed(e.toString()));
    }
  }

  @override
  Future<Either<GeofenceFailure, Unit>> removeGeofence(String id) async {
    try {
      Geofencing.instance.removeRegionById(id);
      return right(unit);
    } catch (e) {
      return left(GeofenceFailure.setupFailed(e.toString()));
    }
  }

  @override
  Stream<GeofenceEvent> geofenceEvents() {
    return _eventController.stream;
  }
}







