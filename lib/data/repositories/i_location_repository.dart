import 'package:dartz/dartz.dart';
import 'package:sampada/data/models/user_location.dart';
import 'package:sampada/core/network/location_failure.dart';

abstract class ILocationRepository {
  Stream<Either<LocationFailure, UserLocation>> watchPosition();
  Future<Either<LocationFailure, UserLocation>> getCurrentPosition();
  Future<Either<LocationFailure, Unit>> requestPermission();
}







