import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:sampada/data/models/heritage_site.dart';

class HeritageMapScreen extends StatefulWidget {
  final List<HeritageSite> sites;
  const HeritageMapScreen({super.key, required this.sites});

  @override
  State<HeritageMapScreen> createState() => _HeritageMapScreenState();
}

class _HeritageMapScreenState extends State<HeritageMapScreen> {
  late final List<Marker> _markers;
  static const _nepalCenter = LatLng(28.3949, 84.1240);

  @override
  void initState() {
    super.initState();
    _markers = widget.sites.map(_buildMarker).whereType<Marker>().toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Heritage Map')),
      body: FlutterMap(
        options: const MapOptions(
          initialCenter: _nepalCenter,
          initialZoom: 7,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: const ['a', 'b', 'c'],
          ),
          RepaintBoundary(
            child: MarkerClusterLayerWidget(
              options: MarkerClusterLayerOptions(
                maxClusterRadius: 80,
                markers: _markers,
                builder: (ctx, markers) => FloatingActionButton.small(
                  onPressed: null,
                  child: Text('${markers.length}'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Marker? _buildMarker(HeritageSite site) {
    // Guard: skip sites with invalid coordinates (GEO-002)
    if (site.latitude == 0.0 && site.longitude == 0.0) return null;
    if (site.latitude < 26.0 || site.latitude > 30.5) return null; // Nepal bounds
    if (site.longitude < 80.0 || site.longitude > 88.2) return null;

    return Marker(
      point: LatLng(site.latitude, site.longitude),
      width: 36,
      height: 36,
      child: const Icon(Icons.place, color: Colors.red),
    );
  }
}







