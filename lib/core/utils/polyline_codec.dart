import 'package:latlong2/latlong.dart';

/// Decoder for Google's encoded-polyline format (precision 5), which OSRM
/// returns as route geometry. Kept in-house — ~25 lines beats a dependency.
class PolylineCodec {
  PolylineCodec._();

  static List<LatLng> decode(String encoded) {
    final points = <LatLng>[];
    var index = 0, lat = 0, lng = 0;

    int nextDelta() {
      var result = 0, shift = 0, b = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      return (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    }

    while (index < encoded.length) {
      lat += nextDelta();
      lng += nextDelta();
      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }
}
