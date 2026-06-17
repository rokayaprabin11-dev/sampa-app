import 'package:freezed_annotation/freezed_annotation.dart';

part 'geofence_failure.freezed.dart';

@freezed
class GeofenceFailure with _$GeofenceFailure {
  const factory GeofenceFailure.setupFailed(String message) = _SetupFailed;
}







