import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/services/location_service.dart';
import 'package:sampada/data/models/heritage_site.dart';
import 'package:sampada/presentation/navigation/app_bottom_nav.dart';
import 'package:sampada/providers/heritage_provider.dart';

// Nepal centre fallback
const _nepalCenter = LatLng(28.3949, 84.1240);
const _defaultZoom = 7.0;
const _siteZoom = 13.0;

class MapPlaceholderScreen extends StatefulWidget {
  final HeritageSite? focusSite;
  const MapPlaceholderScreen({super.key, this.focusSite});

  @override
  State<MapPlaceholderScreen> createState() => _MapPlaceholderScreenState();
}

class _MapPlaceholderScreenState extends State<MapPlaceholderScreen> {
  final MapController _mapController = MapController();
  Position? _userPosition;
  HeritageSite? _selectedSite;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadSites();
      final site = widget.focusSite;
      if (site != null && site.latitude != 0.0 && site.longitude != 0.0) {
        setState(() => _selectedSite = site);
        // Slight delay so FlutterMap finishes its own init before we move
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) _mapController.move(LatLng(site.latitude, site.longitude), _siteZoom);
      } else {
        _tryLocate();
      }
    });
  }

  Future<void> _loadSites() async {
    final provider = context.read<HeritageProvider>();
    // Always refresh so sites added since the last fetch (e.g. via admin)
    // show up on the map; fall back to whatever is cached on failure.
    await provider.fetchSites();
  }

  Future<void> _tryLocate() async {
    setState(() => _locating = true);
    try {
      final pos = await LocationService().getCurrentPosition();
      if (!mounted) return;
      setState(() => _userPosition = pos);
      if (pos != null) {
        _mapController.move(LatLng(pos.latitude, pos.longitude), _siteZoom);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _onMarkerTap(HeritageSite site) {
    setState(() => _selectedSite = site);
    _mapController.move(LatLng(site.latitude, site.longitude), _siteZoom);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        title: const Text('Map'),
        backgroundColor: AppColors.primaryBrown,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: _locating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
            onPressed: _locating ? null : _tryLocate,
            tooltip: 'My Location',
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildMap(),
          if (_selectedSite != null) _buildSiteCard(),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }

  Widget _buildMap() {
    return Consumer<HeritageProvider>(
      builder: (context, heritage, _) {
        final sites = heritage.sites
            .where((s) => s.latitude != 0.0 && s.longitude != 0.0)
            .toList();

        // Always pin the focused site (from "View on Map") even if the
        // provider list is stale or doesn't include it yet — otherwise a
        // newly-added site shows no marker.
        final focus = widget.focusSite;
        if (focus != null &&
            focus.latitude != 0.0 &&
            focus.longitude != 0.0 &&
            !sites.any((s) => s.id == focus.id)) {
          sites.add(focus);
        }

        return FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _nepalCenter,
            initialZoom: _defaultZoom,
            minZoom: 5.0,
            maxZoom: 18.0,
            onTap: (_, __) => setState(() => _selectedSite = null),
          ),
          children: [
            // OSM tile layer
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.sampada.app',
              maxZoom: 19,
            ),
            // Heritage site markers
            MarkerLayer(
              markers: [
                ...sites.map((site) => _siteMarker(site)),
                if (_userPosition != null) _userMarker(),
              ],
            ),
          ],
        );
      },
    );
  }

  Marker _siteMarker(HeritageSite site) {
    final isSelected = _selectedSite?.id == site.id;
    return Marker(
      point: LatLng(site.latitude, site.longitude),
      width: isSelected ? 44 : 36,
      height: isSelected ? 44 : 36,
      child: GestureDetector(
        onTap: () => _onMarkerTap(site),
        child: Container(
          decoration: BoxDecoration(
            color: site.isUnesco
                ? Colors.amber
                : (isSelected ? AppColors.primaryBrown : AppColors.primaryBrown.withValues(alpha: 0.85)),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: isSelected ? 3 : 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: isSelected ? 8 : 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            site.isUnesco ? Icons.star : Icons.location_on,
            color: Colors.white,
            size: isSelected ? 22 : 18,
          ),
        ),
      ),
    );
  }

  Marker _userMarker() {
    return Marker(
      point: LatLng(_userPosition!.latitude, _userPosition!.longitude),
      width: 40,
      height: 40,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: const Icon(Icons.person, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildSiteCard() {
    final site = _selectedSite!;
    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: site.imageUrl != null
                    ? Image.network(
                        site.imageUrl!,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _sitePlaceholder(),
                      )
                    : _sitePlaceholder(),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (site.isUnesco)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.star, color: Colors.amber, size: 14),
                          ),
                        Expanded(
                          child: Text(
                            site.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      site.district,
                      style: const TextStyle(
                          color: AppColors.secondaryText, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      site.category,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.primaryBrown,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Close
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() => _selectedSite = null),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sitePlaceholder() {
    return Container(
      width: 72,
      height: 72,
      color: AppColors.primaryBrown.withValues(alpha: 0.15),
      child: const Icon(Icons.temple_hindu,
          color: AppColors.primaryBrown, size: 32),
    );
  }
}
