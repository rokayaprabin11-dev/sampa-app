import 'package:dartz/dartz.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sampada/core/services/location_service.dart'; // mapper lives here
import 'package:sampada/data/models/user_location.dart';
import 'package:sampada/core/network/location_failure.dart';
import 'package:sampada/data/repositories/i_location_repository.dart';

class LocationRepositoryImpl implements ILocationRepository {
  @override
  Future<Either<LocationFailure, UserLocation>> getCurrentPosition() async {
    try {
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return left(const LocationFailure.permissionDenied());
      }
      final position = await Geolocator.getCurrentPosition();
      return right(position.toUserLocation());
    } catch (e) {
      return left(LocationFailure.serviceUnavailable(e.toString()));
    }
  }

  @override
  Stream<Either<LocationFailure, UserLocation>> watchPosition() {
    return Geolocator.getPositionStream().map((p) => right(p.toUserLocation()));
  }

  @override
  Future<Either<LocationFailure, Unit>> requestPermission() async {
    final p = await Geolocator.requestPermission();
    return p == LocationPermission.always || p == LocationPermission.whileInUse
        ? right(unit)
        : left(const LocationFailure.permissionDenied());
  }
}







