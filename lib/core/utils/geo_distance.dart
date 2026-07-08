import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:sampada/generated/app_localizations.dart';

/// Single source of truth for user↔place distance math and display.
/// Replaces the three per-file copies (event provider, guide screen, local
/// datasource) that had drifted — one of them into a flat-earth approximation
/// that was ~11% off in longitude at Nepal's latitude.
class GeoDistance {
  GeoDistance._();

  static const double _earthRadiusKm = 6371.0;

  /// Great-circle (haversine) distance in kilometres.
  static double haversineKm(
      double lat1, double lng1, double lat2, double lng2) {
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return _earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _rad(double deg) => deg * math.pi / 180;

  /// Whether a stored coordinate pair is usable. (0, 0) is the backend's
  /// "no location set" placeholder, not a real place.
  static bool hasCoords(double? lat, double? lng) =>
      lat != null && lng != null && !(lat == 0.0 && lng == 0.0);

  /// Localized label: "850 m away" under 1 km, "1.2 km away" under 10 km,
  /// "23 km away" beyond.
  static String label(BuildContext context, double km) {
    final l10n = AppLocalizations.of(context)!;
    if (km < 1.0) {
      final m = ((km * 1000) / 10).round() * 10; // nearest 10 m
      return l10n.distanceM('$m');
    }
    final text = km < 10 ? km.toStringAsFixed(1) : km.round().toString();
    return l10n.distanceKm(text);
  }

  /// Compact chip variant without the "away" suffix: "850 m" / "1.2 km".
  static String shortLabel(double km) {
    if (km < 1.0) {
      final m = ((km * 1000) / 10).round() * 10;
      return '$m m';
    }
    return km < 10
        ? '${km.toStringAsFixed(1)} km'
        : '${km.round()} km';
  }

  /// Haversine + coord guard in one step: null when the target has no real
  /// coordinates, else the distance in km from (userLat, userLng).
  static double? kmTo(
      double userLat, double userLng, double? lat, double? lng) {
    if (!hasCoords(lat, lng)) return null;
    return haversineKm(userLat, userLng, lat!, lng!);
  }
}
