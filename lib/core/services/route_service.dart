import 'package:latlong2/latlong.dart';
import 'package:sampada/core/network/api_client.dart';
import 'package:sampada/core/network/api_endpoints.dart';
import 'package:sampada/core/utils/polyline_codec.dart';

class RouteResult {
  final double distanceM;
  final double durationS;
  final List<LatLng> points;

  const RouteResult({
    required this.distanceM,
    required this.durationS,
    required this.points,
  });

  double get distanceKm => distanceM / 1000;
  int get durationMin => (durationS / 60).ceil();
}

/// Fetches a route from the backend, which proxies OSRM (see geo.RouteView).
/// The app never calls the routing server directly — auth, caching and
/// provider swaps all live behind /geo/route/.
class RouteService {
  RouteService({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  Future<RouteResult?> fetchRoute({
    required LatLng start,
    required LatLng dest,
    String mode = 'driving',
  }) async {
    final data = await _api.get(ApiEndpoints.geoRoute, queryParameters: {
      'start': '${start.latitude},${start.longitude}',
      'dest': '${dest.latitude},${dest.longitude}',
      'mode': mode,
    });
    if (data is! Map || data['geometry'] is! String) return null;
    final points = PolylineCodec.decode(data['geometry'] as String);
    if (points.length < 2) return null;
    return RouteResult(
      distanceM: (data['distance_m'] as num).toDouble(),
      durationS: (data['duration_s'] as num).toDouble(),
      points: points,
    );
  }
}
