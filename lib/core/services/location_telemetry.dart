import 'package:flutter/foundation.dart';

/// Anonymous, in-memory location metrics: time-to-first-fix, accuracy,
/// failure/cache-hit counts. No coordinates and no identifiers are stored —
/// safe to surface in logs or ship to an analytics endpoint later.
///
/// Backend note: POST /notifications/events whitelists event_type, so this is
/// intentionally client-side only. To ship these metrics, add a
/// 'location_metrics' event type server-side and post [summary] as metadata.
class LocationTelemetry {
  static final LocationTelemetry _instance = LocationTelemetry._();
  factory LocationTelemetry() => _instance;
  LocationTelemetry._();

  static const int _window = 50; // rolling window per metric

  int fixSuccesses = 0;
  int fixFailures = 0;
  int cacheHits = 0;
  int poorGpsFallbacks = 0;

  final List<int> _ttffMs = [];
  final List<double> _accuraciesM = [];

  void recordFix({required int ttffMillis, required double accuracyM}) {
    fixSuccesses++;
    _push(_ttffMs, ttffMillis);
    _push(_accuraciesM, accuracyM);
    _maybeLog();
  }

  void recordFailure() {
    fixFailures++;
    _maybeLog();
  }

  void recordCacheHit() => cacheHits++;

  void recordPoorGpsFallback() => poorGpsFallbacks++;

  void _push<T>(List<T> list, T value) {
    list.add(value);
    if (list.length > _window) list.removeAt(0);
  }

  double? get avgAccuracyM => _accuraciesM.isEmpty
      ? null
      : _accuraciesM.reduce((a, b) => a + b) / _accuraciesM.length;

  double? get avgTtffMs => _ttffMs.isEmpty
      ? null
      : _ttffMs.reduce((a, b) => a + b) / _ttffMs.length;

  Map<String, Object?> summary() => {
        'fix_successes': fixSuccesses,
        'fix_failures': fixFailures,
        'cache_hits': cacheHits,
        'poor_gps_fallbacks': poorGpsFallbacks,
        'avg_accuracy_m': avgAccuracyM?.toStringAsFixed(1),
        'avg_ttff_ms': avgTtffMs?.toStringAsFixed(0),
      };

  /// Log a snapshot every 10 fix attempts so real-world accuracy/TTFF trends
  /// show up in debug builds without spamming the console.
  void _maybeLog() {
    final attempts = fixSuccesses + fixFailures;
    if (attempts % 10 == 0) {
      debugPrint('LocationTelemetry: ${summary()}');
    }
  }
}
