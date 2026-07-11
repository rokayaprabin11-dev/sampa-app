import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_dimensions.dart';
import 'package:sampada/core/constants/app_strings.dart';
import 'package:sampada/core/network/api_client.dart';
import 'package:sampada/core/services/location_service.dart';
import 'package:sampada/core/services/route_service.dart';
import 'package:sampada/core/utils/geo_distance.dart';
import 'package:sampada/injection.dart' as di;
import 'package:sampada/data/models/heritage_site.dart';
import 'package:sampada/generated/app_localizations.dart';
import 'package:sampada/presentation/navigation/app_bottom_nav.dart';
import 'package:sampada/providers/heritage_provider.dart';

const _nepalCenter = LatLng(28.3949, 84.1240);
const _defaultZoom = 7.0;
const _siteZoom = 15.5;
const _userZoom = 13.0;

class HeritageMapScreen extends StatefulWidget {
  final HeritageSite? focusSite;
  const HeritageMapScreen({super.key, this.focusSite});

  @override
  State<HeritageMapScreen> createState() => _HeritageMapScreenState();
}

class _HeritageMapScreenState extends State<HeritageMapScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  AnimationController? _flyController;

  Position? _userPosition;
  HeritageSite? _selectedSite;
  bool _locating = false;

  late final RouteService _routeService =
      RouteService(apiClient: di.sl<ApiClient>());
  RouteResult? _route;
  HeritageSite? _routeSite;
  bool _routing = false;

  Timer? _debounce;
  List<HeritageSite> _suggestions = const [];
  late final AnimationController _bounceController;
  late final Animation<double> _bounce;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    // One up-and-down hop for the selected marker when the camera arrives.
    _bounce = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 1.0)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 40),
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 0.0)
              .chain(CurveTween(curve: Curves.bounceOut)),
          weight: 60),
    ]).animate(_bounceController);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<HeritageProvider>().fetchSites();
      if (!mounted) return;
      final site = widget.focusSite;
      if (site != null && _validCoords(site)) {
        setState(() => _selectedSite = site);
        // Let FlutterMap finish its own init before the camera flight.
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) _flyTo(LatLng(site.latitude, site.longitude), _siteZoom);
      } else {
        _tryLocate();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _bounceController.dispose();
    _flyController?.dispose();
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  // ── Camera ────────────────────────────────────────────────────────────────

  /// Google-Maps-style camera flight: position and zoom tween together over
  /// many frames instead of jumping. Long hops (>50 km) zoom out to a mid
  /// level first, then dive back in, so the ride reads as one smooth arc.
  void _flyTo(LatLng dest, double destZoom,
      {Duration? duration, bool bounceOnArrival = false}) {
    final camera = _mapController.camera;
    final start = camera.center;
    final startZoom = camera.zoom;

    final distKm = GeoDistance.haversineKm(
        start.latitude, start.longitude, dest.latitude, dest.longitude);
    final flight = duration ??
        Duration(milliseconds: (600 + distKm * 3).clamp(600, 1600).round());

    _flyController?.dispose();
    final controller = AnimationController(vsync: this, duration: flight);
    _flyController = controller;

    final move = CurvedAnimation(parent: controller, curve: Curves.easeInOutCubic);
    final latTween = Tween<double>(begin: start.latitude, end: dest.latitude);
    final lngTween = Tween<double>(begin: start.longitude, end: dest.longitude);

    Animation<double> zoom;
    if (distKm > 50) {
      final midZoom = math.max(5.0, math.min(startZoom, destZoom) - 2.0);
      zoom = TweenSequence<double>([
        TweenSequenceItem(
            tween: Tween(begin: startZoom, end: midZoom), weight: 45),
        TweenSequenceItem(
            tween: Tween(begin: midZoom, end: destZoom), weight: 55),
      ]).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));
    } else {
      zoom = Tween<double>(begin: startZoom, end: destZoom)
          .animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));
    }

    controller.addListener(() {
      _mapController.move(
        LatLng(latTween.evaluate(move), lngTween.evaluate(move)),
        zoom.value,
      );
    });
    controller.forward().whenComplete(() {
      if (bounceOnArrival && mounted && _selectedSite != null) {
        _bounceController.forward(from: 0);
      }
    });
  }

  void _zoomBy(double delta) {
    final camera = _mapController.camera;
    final target = (camera.zoom + delta).clamp(5.0, 18.0);
    _flyTo(camera.center, target,
        duration: const Duration(milliseconds: 250));
  }

  Future<void> _tryLocate() async {
    if (!mounted) return;
    setState(() => _locating = true);
    try {
      // Quality-aware fix first (accuracy-gated + smoothed), raw fix as the
      // last resort — same ladder as the guide screens.
      final (fix, _) = await LocationService().getFixWithQuality();
      final pos = fix ?? await LocationService().getCurrentPosition();
      if (!mounted) return;
      setState(() => _userPosition = pos);
      if (pos != null) {
        _flyTo(LatLng(pos.latitude, pos.longitude), _userZoom);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  // ── Directions ────────────────────────────────────────────────────────────

  /// User GPS → backend /geo/route/ (Django proxies OSRM) → decoded polyline
  /// drawn on the map, camera fitted to the whole route.
  Future<void> _onDirections(HeritageSite site) async {
    final l10n = AppLocalizations.of(context)!;

    var pos = _userPosition;
    if (pos == null) {
      await _tryLocate();
      pos = _userPosition;
    }
    if (pos == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.mapRouteNeedLocation)),
      );
      return;
    }

    setState(() {
      _routing = true;
      _routeSite = site;
      _selectedSite = site;
    });
    try {
      final route = await _routeService.fetchRoute(
        start: LatLng(pos.latitude, pos.longitude),
        dest: LatLng(site.latitude, site.longitude),
      );
      if (!mounted) return;
      if (route == null) {
        setState(() => _routing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.mapRouteError)),
        );
        return;
      }
      setState(() {
        _route = route;
        _routing = false;
      });
      _fitRoute(route.points);
    } catch (_) {
      if (!mounted) return;
      setState(() => _routing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.mapRouteError)),
      );
    }
  }

  void _fitRoute(List<LatLng> points) {
    final fitted = CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(points),
      padding: const EdgeInsets.fromLTRB(48, 48, 48, 64),
    ).fit(_mapController.camera);
    _flyTo(fitted.center, fitted.zoom);
  }

  void _clearRoute() {
    setState(() {
      _route = null;
      _routeSite = null;
    });
  }

  // ── Search ────────────────────────────────────────────────────────────────

  /// Viewport-aware ranking, Google-Maps style. Weights:
  /// name match 40% · visible in current viewport 25% · near user 15% ·
  /// popularity 10% · featured/UNESCO 10%. So "Durbar" prefers Bhaktapur
  /// Durbar Square when the camera is already over Bhaktapur.
  List<HeritageSite> _rankSuggestions(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];

    final sites = context.read<HeritageProvider>().sites.where(_validCoords);
    final bounds = _mapController.camera.visibleBounds;
    final pos = _userPosition;

    final scored = <(HeritageSite, double)>[];
    for (final s in sites) {
      final name = s.name.toLowerCase();
      double match;
      if (name == q) {
        match = 1.0;
      } else if (name.startsWith(q)) {
        match = 0.8;
      } else if (name.contains(q) || s.nameNepali.contains(query.trim())) {
        match = 0.5;
      } else if (s.location.toLowerCase().contains(q) ||
          s.district.toLowerCase().contains(q)) {
        match = 0.35;
      } else {
        continue;
      }

      final visible =
          bounds.contains(LatLng(s.latitude, s.longitude)) ? 1.0 : 0.0;

      var proximity = 0.0;
      if (pos != null) {
        final km = GeoDistance.haversineKm(
            pos.latitude, pos.longitude, s.latitude, s.longitude);
        proximity = (1 - km / 50).clamp(0.0, 1.0);
      }

      final popularity =
          (s.rating / 5).clamp(0.0, 1.0) * (s.reviewsCount > 0 ? 1.0 : 0.5);
      final priority = (s.isFeatured || s.isUnesco) ? 1.0 : 0.0;

      scored.add((
        s,
        0.40 * match +
            0.25 * visible +
            0.15 * proximity +
            0.10 * popularity +
            0.10 * priority
      ));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored.take(6).map((e) => e.$1).toList();
  }

  /// Live search: 250 ms debounce, dropdown only — the camera never moves
  /// while typing.
  void _onSearchChanged(String text) {
    _debounce?.cancel();
    if (text.trim().isEmpty) {
      setState(() => _suggestions = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _suggestions = _rankSuggestions(text));
    });
    setState(() {}); // refresh clear-button visibility
  }

  void _selectSuggestion(HeritageSite site) {
    _debounce?.cancel();
    _searchController.text = site.name;
    FocusScope.of(context).unfocus();
    setState(() {
      _suggestions = const [];
      _selectedSite = site;
    });
    _flyTo(LatLng(site.latitude, site.longitude), _siteZoom,
        bounceOnArrival: true);
  }

  void _onSearch(String query) {
    final ranked = _rankSuggestions(query);
    if (ranked.isEmpty) {
      FocusScope.of(context).unfocus();
      if (query.trim().isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.labelNotFound)),
        );
      }
      return;
    }
    _selectSuggestion(ranked.first);
  }

  // ── Data helpers ──────────────────────────────────────────────────────────

  bool _validCoords(HeritageSite site) {
    if (site.latitude == 0.0 && site.longitude == 0.0) return false; // GEO-002
    if (site.latitude < 26.0 || site.latitude > 30.5) return false; // Nepal bounds
    if (site.longitude < 80.0 || site.longitude > 88.2) return false;
    return true;
  }

  /// Two closest sites to the user; without a fix, the first two sites
  /// (distance hidden — never show a km label that isn't from a real fix).
  List<(HeritageSite, double?)> _nearestTwo(List<HeritageSite> sites) {
    final valid = sites.where(_validCoords).toList();
    final pos = _userPosition;
    if (pos == null) {
      return valid.take(2).map((s) => (s, null as double?)).toList();
    }
    final ranked = valid
        .map((s) => (
              s,
              GeoDistance.haversineKm(
                  pos.latitude, pos.longitude, s.latitude, s.longitude)
            ))
        .toList()
      ..sort((a, b) => a.$2.compareTo(b.$2));
    return ranked.take(2).map((e) => (e.$1, e.$2 as double?)).toList();
  }

  String _categoryEmoji(HeritageSite site) {
    final c = site.category.toLowerCase();
    if (c.contains('temple')) return '🛕';
    if (c.contains('stupa')) return '⛩️';
    if (c.contains('monaster') || c.contains('gumba')) return '🏯';
    if (c.contains('palace') || c.contains('durbar')) return '🏰';
    if (c.contains('museum')) return '🏛️';
    if (c.contains('lake')) return '🏞️';
    if (c.contains('mountain') || c.contains('peak')) return '🏔️';
    if (c.contains('park') || c.contains('garden')) return '🌳';
    if (c.contains('monument')) return '🗿';
    return '🏛️';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kColorBgPage,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Stack(
              children: [
                _buildMap(),
                Positioned(top: 12, right: 12, child: _buildMapControls()),
                if (_route != null)
                  Positioned(top: 12, left: 12, child: _buildRouteBanner()),
                if (_suggestions.isNotEmpty)
                  Positioned(
                      top: 8, left: 12, right: 12, child: _buildSuggestions()),
              ],
            ),
          ),
          _buildNearbyPanel(),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }

  Widget _buildHeader() {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.kColorDeep,
            AppColors.kColorPrimaryMid,
            AppColors.kColorPrimaryLight,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppDimensions.sp16, AppDimensions.sp8, AppDimensions.sp16, AppDimensions.sp16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${l10n.heritageMapTitle} 🏯',
                style: textTheme.displayMedium
                    ?.copyWith(color: AppColors.kColorTextOnHeader),
              ),
              const SizedBox(height: AppDimensions.sp2),
              Text(
                l10n.mapSubtitle,
                style: textTheme.bodyMedium
                    ?.copyWith(color: AppColors.kColorAccentPale),
              ),
              const SizedBox(height: AppDimensions.sp12),
              _buildSearchField(l10n),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField(AppLocalizations l10n) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.kColorBgPage,
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusPill),
        boxShadow: const [
          BoxShadow(
              color: AppColors.kShadowColor,
              blurRadius: 6,
              offset: Offset(0, 2)),
        ],
      ),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        onChanged: _onSearchChanged,
        onSubmitted: _onSearch,
        style: const TextStyle(
            color: AppColors.kColorTextBody, fontSize: 14),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          hintText: l10n.searchHeritageHint,
          hintStyle: const TextStyle(
              color: AppColors.kColorTextMuted, fontSize: 14),
          prefixIcon: const Icon(Icons.search,
              color: AppColors.kColorTextMuted, size: AppDimensions.iconMd),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close,
                      color: AppColors.kColorTextMuted,
                      size: AppDimensions.iconMd),
                  onPressed: () {
                    _debounce?.cancel();
                    _searchController.clear();
                    setState(() => _suggestions = const []);
                  },
                ),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 12, horizontal: AppDimensions.sp16),
        ),
      ),
    );
  }

  Widget _buildMap() {
    final l10n = AppLocalizations.of(context)!;
    return Consumer<HeritageProvider>(
      builder: (context, heritage, _) {
        final sites = heritage.sites.where(_validCoords).toList();

        // Always pin the focused site (from "View on Map") even if the
        // provider list is stale or doesn't include it yet.
        final focus = widget.focusSite;
        if (focus != null &&
            _validCoords(focus) &&
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
            backgroundColor: AppColors.kColorMapSurface,
            onTap: (_, __) {
              FocusScope.of(context).unfocus();
              setState(() {
                _selectedSite = null;
                _suggestions = const [];
              });
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.sampada.app',
              maxZoom: 19,
            ),
            if (_route != null)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _route!.points,
                    strokeWidth: 5,
                    color: AppColors.statusInfo,
                    borderStrokeWidth: 2,
                    borderColor: Colors.white,
                  ),
                ],
              ),
            RepaintBoundary(
              child: MarkerLayer(
                markers: [
                  ...sites.map(_siteMarker),
                  if (_userPosition != null) _userMarker(l10n),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Marker _siteMarker(HeritageSite site) {
    final isSelected = _selectedSite?.id == site.id;
    final size = isSelected ? 46.0 : 38.0;
    return Marker(
      point: LatLng(site.latitude, site.longitude),
      width: size,
      height: size,
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedSite = site);
          _flyTo(LatLng(site.latitude, site.longitude), _siteZoom,
              bounceOnArrival: true);
        },
        child: AnimatedBuilder(
          animation: _bounce,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, isSelected ? -10 * _bounce.value : 0),
            child: child,
          ),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.kColorAccentLight,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? AppColors.kColorPrimary
                    : AppColors.kColorTextOnPrimary,
                width: isSelected ? 3 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: isSelected ? 8 : 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              _categoryEmoji(site),
              style: TextStyle(fontSize: isSelected ? 22 : 18, height: 1),
            ),
          ),
        ),
      ),
    );
  }

  Marker _userMarker(AppLocalizations l10n) {
    final pos = _userPosition!;
    return Marker(
      point: LatLng(pos.latitude, pos.longitude),
      width: 64,
      height: 44,
      alignment: Alignment.topCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: AppColors.statusInfo,
              shape: BoxShape.circle,
              border: Border.all(
                  color: AppColors.kColorTextOnPrimary, width: 2.5),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 1)),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.sp2),
          Text(
            l10n.mapYouLabel,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.kColorTextHeading,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapControls() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.kColorSurface,
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusLg),
        boxShadow: const [
          BoxShadow(
              color: AppColors.kShadowColor,
              blurRadius: 6,
              offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.kColorTextHeading),
            onPressed: () => _zoomBy(1),
            tooltip: '+',
          ),
          Container(
            width: 24,
            height: 1,
            color: AppColors.kColorBorderSubtle,
          ),
          IconButton(
            icon: const Icon(Icons.remove, color: AppColors.kColorTextHeading),
            onPressed: () => _zoomBy(-1),
            tooltip: '−',
          ),
          Container(
            width: 24,
            height: 1,
            color: AppColors.kColorBorderSubtle,
          ),
          IconButton(
            icon: _locating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.kColorPrimary),
                  )
                : const Icon(Icons.my_location,
                    color: AppColors.kColorTextHeading),
            onPressed: _locating ? null : _tryLocate,
            tooltip: 'My Location',
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestions() {
    final pos = _userPosition;
    return Container(
      constraints: const BoxConstraints(maxHeight: 320),
      decoration: BoxDecoration(
        color: AppColors.kColorSurface,
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusLg),
        border: Border.all(color: AppColors.kColorBorderSubtle),
        boxShadow: const [
          BoxShadow(
              color: AppColors.kShadowColor,
              blurRadius: 10,
              offset: Offset(0, 4)),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.sp4),
        itemCount: _suggestions.length,
        separatorBuilder: (_, __) => const Divider(
            height: 1, color: AppColors.kColorBorderFaint),
        itemBuilder: (context, i) {
          final site = _suggestions[i];
          final km = pos == null
              ? null
              : GeoDistance.haversineKm(pos.latitude, pos.longitude,
                  site.latitude, site.longitude);
          return InkWell(
            onTap: () => _selectSuggestion(site),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.sp12, vertical: AppDimensions.sp10),
              child: Row(
                children: [
                  Text(_categoryEmoji(site),
                      style: const TextStyle(fontSize: 18, height: 1)),
                  const SizedBox(width: AppDimensions.sp10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          site.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.kColorTextHeading,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          site.district,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.kColorTextSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (km != null) ...[
                    const SizedBox(width: AppDimensions.sp8),
                    Text(
                      GeoDistance.shortLabel(km),
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.kColorTextSecondary),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRouteBanner() {
    final l10n = AppLocalizations.of(context)!;
    final route = _route!;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.sp12, vertical: AppDimensions.sp8),
      decoration: BoxDecoration(
        color: AppColors.kColorSurface,
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusPill),
        boxShadow: const [
          BoxShadow(
              color: AppColors.kShadowColor,
              blurRadius: 6,
              offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.directions_car,
              size: AppDimensions.iconSm, color: AppColors.statusInfo),
          const SizedBox(width: AppDimensions.sp6),
          Text(
            l10n.mapRouteEta(
              GeoDistance.shortLabel(route.distanceKm),
              '${route.durationMin}',
            ),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.kColorTextHeading,
            ),
          ),
          const SizedBox(width: AppDimensions.sp6),
          InkWell(
            onTap: _clearRoute,
            child: const Icon(Icons.close,
                size: AppDimensions.iconSm,
                color: AppColors.kColorTextSecondary),
          ),
        ],
      ),
    );
  }

  /// Default: two closest sites. When a marker is tapped, that site takes
  /// over the panel (same card style) until the map is tapped to deselect.
  Widget _buildNearbyPanel() {
    final l10n = AppLocalizations.of(context)!;
    return Consumer<HeritageProvider>(
      builder: (context, heritage, _) {
        final selected = _selectedSite;
        final List<(HeritageSite, double?)> nearest;
        if (selected != null && _validCoords(selected)) {
          final pos = _userPosition;
          nearest = [
            (
              selected,
              pos == null
                  ? null
                  : GeoDistance.haversineKm(pos.latitude, pos.longitude,
                      selected.latitude, selected.longitude)
            ),
          ];
        } else {
          nearest = _nearestTwo(heritage.sites);
        }
        if (nearest.isEmpty) return const SizedBox.shrink();
        return Container(
          color: AppColors.kColorBgPage,
          padding: const EdgeInsets.fromLTRB(AppDimensions.sp16,
              AppDimensions.sp12, AppDimensions.sp16, AppDimensions.sp12),
          child: Row(
            children: [
              for (var i = 0; i < nearest.length; i++) ...[
                if (i > 0) const SizedBox(width: AppDimensions.sp12),
                Expanded(
                    child: _nearbyCard(l10n, nearest[i].$1, nearest[i].$2)),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _nearbyCard(AppLocalizations l10n, HeritageSite site, double? km) {
    return GestureDetector(
      onTap: () {
        setState(() => _selectedSite = site);
        _flyTo(LatLng(site.latitude, site.longitude), _siteZoom);
      },
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.sp12),
        decoration: BoxDecoration(
          color: AppColors.kColorSurface,
          borderRadius: BorderRadius.circular(AppDimensions.kRadiusXl),
          border: Border.all(color: AppColors.kColorBorderSubtle),
          boxShadow: const [
            BoxShadow(
                color: AppColors.kShadowColorSubtle,
                blurRadius: 6,
                offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_categoryEmoji(site),
                    style: const TextStyle(fontSize: 20, height: 1.2)),
                const SizedBox(width: AppDimensions.sp8),
                Expanded(
                  child: Text(
                    site.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.kColorTextHeading,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.sp6),
            Row(
              children: [
                const Icon(Icons.place,
                    size: AppDimensions.iconSm - 2,
                    color: AppColors.kColorTextSecondary),
                const SizedBox(width: AppDimensions.sp4),
                Expanded(
                  child: Text(
                    km != null ? GeoDistance.shortLabel(km) : site.district,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.kColorTextSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.sp8),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 28,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pushNamed(
                        context,
                        AppStrings.heritageDetailsPath,
                        arguments: site,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.kColorDeep,
                        foregroundColor: AppColors.kColorTextOnPrimary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppDimensions.sp8),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppDimensions.kRadiusSm),
                        ),
                      ),
                      child: Text(l10n.mapDetailsButton,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
                const SizedBox(width: AppDimensions.sp8),
                Expanded(
                  child: SizedBox(
                    height: 28,
                    child: OutlinedButton(
                      onPressed: _routing && _routeSite?.id == site.id
                          ? null
                          : () => _onDirections(site),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.kColorPrimary,
                        side: const BorderSide(
                            color: AppColors.kColorPrimary, width: 1.2),
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppDimensions.sp8),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppDimensions.kRadiusSm),
                        ),
                      ),
                      child: _routing && _routeSite?.id == site.id
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.kColorPrimary),
                            )
                          : Text(l10n.mapDirectionsButton,
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
