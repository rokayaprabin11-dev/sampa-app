import 'dart:math' as math;

/// Lightweight 1-D-per-axis Kalman filter for GPS smoothing (the well-known
/// "smooth GPS data" model): measurement variance = reported accuracy², process
/// noise grows with elapsed time. Removes jitter so a stationary visitor near a
/// geofence edge doesn't flap in/out of the radius.
class GpsKalman {
  GpsKalman({double processNoiseMetresPerSec = 3.0})
      : _q = processNoiseMetresPerSec;

  final double _q; // process noise (m/s) — higher = trusts new fixes more
  static const double _minAccuracy = 1.0;

  double? _lat;
  double? _lng;
  double? _variance; // metres²
  int _timestampMs = 0;

  /// Fold a new raw fix into the estimate.
  void process(double lat, double lng, double accuracy, int timestampMs) {
    if (accuracy < _minAccuracy) accuracy = _minAccuracy;

    if (_variance == null) {
      _lat = lat;
      _lng = lng;
      _variance = accuracy * accuracy;
      _timestampMs = timestampMs;
      return;
    }

    final dtMs = timestampMs - _timestampMs;
    if (dtMs > 0) {
      _variance = _variance! + (dtMs / 1000.0) * _q * _q;
      _timestampMs = timestampMs;
    }

    // Kalman gain, then blend measurement into the estimate.
    final k = _variance! / (_variance! + accuracy * accuracy);
    _lat = _lat! + k * (lat - _lat!);
    _lng = _lng! + k * (lng - _lng!);
    _variance = (1 - k) * _variance!;
  }

  double? get latitude => _lat;
  double? get longitude => _lng;

  /// Current estimated accuracy (metres, 1σ).
  double? get accuracy => _variance == null ? null : math.sqrt(_variance!);

  bool get hasEstimate => _variance != null;
}
