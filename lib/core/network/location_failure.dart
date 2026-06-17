import 'package:freezed_annotation/freezed_annotation.dart';

part 'location_failure.freezed.dart';

@freezed
class LocationFailure with _$LocationFailure {
  const factory LocationFailure.permissionDenied() = _PermissionDenied;
  const factory LocationFailure.serviceUnavailable(String message) = _ServiceUnavailable;
  const factory LocationFailure.positionNotFound() = _PositionNotFound;
}







