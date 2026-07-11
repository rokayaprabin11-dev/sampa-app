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
import 'package:sampada/data/models/cultural_event.dart';
import 'package:sampada/data/models/heritage_site.dart';
import 'package:sampada/generated/app_localizations.dart';
import 'package:sampada/presentation/navigation/app_bottom_nav.dart';
import 'package:sampada/presentation/screens/events/event_detail_screen.dart';
import 'package:sampada/providers/event_provider.dart';
import 'package:sampada/providers/heritage_provider.dart';

const _nepalCenter = LatLng(28.3949, 84.1240);
const _defaultZoom = 7.0;
const _siteZoom = 15.5;
const _userZoom = 13.0;

/// A point plotted on the map — either a heritage site or a cultural event.
/// Unifies the two so markers, selection, the bottom card and directions all
/// work generically; the concrete model is kept for navigation.
class _MapItem {
  final String key; // 's<id>' / 'e<id>' — unique across both types
  final double lat;
  final double lng;
  final String title;
  final String subtitle; // district (site) or location name (event)
  final String emoji;
  final bool isEvent;
  final HeritageSite? site;
  final CulturalEvent? event;

  const _MapItem({
    required this.key,
    required this.lat,
    required this.lng,
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.isEvent,
    this.site,
    this.event,
  });

  LatLng get point => LatLng(lat, lng);
}

class HeritageMapScreen extends StatefulWidget {
  final HeritageSite? focusSite;
  final CulturalEvent? focusEvent;
  const HeritageMapScreen({super.key, this.focusSite, this.focusEvent});

  @override
  State<HeritageMapScreen> createState() => _HeritageMapScreenState();
}

class _HeritageMapScreenState extends State<HeritageMapScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  AnimationController? _flyController;

  Position? _userPosition;
  _MapItem? _selected;
  bool _locating = false;

  late final RouteService _routeService =
      RouteService(apiClient: di.sl<ApiClient>());
  RouteResult? _route;
  String? _routeKey;
  bool _routing = false;

  Timer? _debounce;
  List<_MapItem> _suggestions = const [];
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
      // Capture providers before any await so we don't touch context across
      // the async gap.
      final heritage = context.read<HeritageProvider>();
      final events = context.read<EventProvider>();
      await heritage.fetchSites();
      if (events.eventsWithLocation.isEmpty) {
        // Best-effort: don't await — sites render immediately, event pins
        // drop in when the fetch lands (Consumer rebuilds the marker layer).
        unawaited(events.loadUpcomingEvents());
      }
      if (!mounted) return;

      final focus = _focusItem();
      if (focus != null) {
        setState(() => _selected = focus);
        // Let FlutterMap finish its own init before the camera flight.
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) _flyTo(focus.point, _siteZoom, bounceOnArrival: true);
      } else {
        _tryLocate();
      }
    });
  }

  _MapItem? _focusItem() {
    final site = widget.focusSite;
    if (site != null && _inNepal(site.latitude, site.longitude)) {
      return _fromSite(site);
    }
    final event = widget.focusEvent;
    if (event != null && _inNepal(event.latitude, event.longitude)) {
      return _fromEvent(event);
    }
    return null;
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
      if (bounceOnArrival && mounted && _selected != null) {
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
  /// drawn on the map, camera fitted to the whole route. Works for both a
  /// heritage site and an event — the destination is just a coordinate.
  Future<void> _onDirections(_MapItem item) async {
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
      _routeKey = item.key;
      _selected = item;
    });
    try {
      final route = await _routeService.fetchRoute(
        start: LatLng(pos.latitude, pos.longitude),
        dest: item.point,
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
      _routeKey = null;
    });
  }

  // ── Search (heritage sites + events) ───────────────────────────────────────

  /// Viewport-aware ranking, Google-Maps style, over both sites and events.
  /// Weights: name match 40% · visible in current viewport 25% · near user
  /// 15% · popularity 10% · priority (featured/UNESCO, or event priority) 10%.
  /// So "Durbar" prefers Bhaktapur Durbar Square when the camera is already
  /// over Bhaktapur; an event named "…Jatra" surfaces alongside sites.
  List<_MapItem> _rankSuggestions(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final qRaw = query.trim();

    final bounds = _mapController.camera.visibleBounds;
    final pos = _userPosition;

    // Tiered name/location match; null means "no match, skip".
    double? matchOf(String name, String nepali, String location, String tag) {
      final n = name.toLowerCase();
      if (n == q) return 1.0;
      if (n.startsWith(q)) return 0.8;
      if (n.contains(q) || (nepali.isNotEmpty && nepali.contains(qRaw))) {
        return 0.5;
      }
      if (location.toLowerCase().contains(q) || tag.toLowerCase().contains(q)) {
        return 0.35;
      }
      return null;
    }

    double score(_MapItem item, double match, double popularity, double priority) {
      final visible = bounds.contains(item.point) ? 1.0 : 0.0;
      var proximity = 0.0;
      if (pos != null) {
        final km = GeoDistance.haversineKm(
            pos.latitude, pos.longitude, item.lat, item.lng);
        proximity = (1 - km / 50).clamp(0.0, 1.0);
      }
      return 0.40 * match +
          0.25 * visible +
          0.15 * proximity +
          0.10 * popularity +
          0.10 * priority;
    }

    final scored = <(_MapItem, double)>[];

    for (final s in context.read<HeritageProvider>().sites) {
      if (!_inNepal(s.latitude, s.longitude)) continue;
      final m = matchOf(s.name, s.nameNepali, s.location, s.district);
      if (m == null) continue;
      final popularity =
          (s.rating / 5).clamp(0.0, 1.0) * (s.reviewsCount > 0 ? 1.0 : 0.5);
      final priority = (s.isFeatured || s.isUnesco) ? 1.0 : 0.0;
      final item = _fromSite(s);
      scored.add((item, score(item, m, popularity, priority)));
    }

    for (final e in context.read<EventProvider>().eventsWithLocation) {
      if (!_inNepal(e.latitude, e.longitude)) continue;
      final m = matchOf(e.title, e.titleNepali, e.locationName, e.eventType);
      if (m == null) continue;
      final popularity = (e.rsvpCount / 50).clamp(0.0, 1.0);
      final priority =
          e.priority == 'high' ? 1.0 : (e.priority == 'low' ? 0.0 : 0.5);
      final item = _fromEvent(e);
      scored.add((item, score(item, m, popularity, priority)));
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

  void _selectItem(_MapItem item, {bool fromSearch = false}) {
    _debounce?.cancel();
    if (fromSearch) {
      _searchController.text = item.title;
      FocusScope.of(context).unfocus();
    }
    setState(() {
      _suggestions = const [];
      _selected = item;
    });
    _flyTo(item.point, _siteZoom, bounceOnArrival: true);
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
    _selectItem(ranked.first, fromSearch: true);
  }

  // ── Data helpers ──────────────────────────────────────────────────────────

  bool _inNepal(double lat, double lng) {
    if (lat == 0.0 && lng == 0.0) return false; // GEO-002 placeholder
    if (lat < 26.0 || lat > 30.5) return false; // Nepal bounds
    if (lng < 80.0 || lng > 88.2) return false;
    return true;
  }

  _MapItem _fromSite(HeritageSite s) => _MapItem(
        key: 's${s.id}',
        lat: s.latitude,
        lng: s.longitude,
        title: s.name,
        subtitle: s.district,
        emoji: _siteEmoji(s.category),
        isEvent: false,
        site: s,
      );

  _MapItem _fromEvent(CulturalEvent e) => _MapItem(
        key: 'e${e.id}',
        lat: e.latitude,
        lng: e.longitude,
        title: e.title,
        subtitle: e.locationName,
        emoji: _eventEmoji(e.eventType),
        isEvent: true,
        event: e,
      );

  List<_MapItem> _allItems(HeritageProvider heritage, EventProvider events) {
    final items = <_MapItem>[];
    for (final s in heritage.sites) {
      if (_inNepal(s.latitude, s.longitude)) items.add(_fromSite(s));
    }
    for (final e in events.eventsWithLocation) {
      if (_inNepal(e.latitude, e.longitude)) items.add(_fromEvent(e));
    }
    // Always keep the focused item pinned even if its provider list is stale.
    final focus = _focusItem();
    if (focus != null && !items.any((i) => i.key == focus.key)) {
      items.add(focus);
    }
    return items;
  }

  /// Two closest heritage sites to the user; without a fix, the first two
  /// (distance hidden — never show a km label that isn't from a real fix).
  List<(_MapItem, double?)> _nearestTwoSites(HeritageProvider heritage) {
    final valid = heritage.sites
        .where((s) => _inNepal(s.latitude, s.longitude))
        .toList();
    final pos = _userPosition;
    if (pos == null) {
      return valid.take(2).map((s) => (_fromSite(s), null as double?)).toList();
    }
    final ranked = valid
        .map((s) => (
              s,
              GeoDistance.haversineKm(
                  pos.latitude, pos.longitude, s.latitude, s.longitude)
            ))
        .toList()
      ..sort((a, b) => a.$2.compareTo(b.$2));
    return ranked
        .take(2)
        .map((e) => (_fromSite(e.$1), e.$2 as double?))
        .toList();
  }

  double? _distanceTo(_MapItem item) {
    final pos = _userPosition;
    if (pos == null) return null;
    return GeoDistance.haversineKm(
        pos.latitude, pos.longitude, item.lat, item.lng);
  }

  String _siteEmoji(String category) {
    final c = category.toLowerCase();
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

  String _eventEmoji(String eventType) {
    final t = eventType.toLowerCase();
    if (t.contains('festival')) return '🎉';
    if (t.contains('music') || t.contains('concert')) return '🎵';
    if (t.contains('dance')) return '💃';
    if (t.contains('food') || t.contains('feast')) return '🍲';
    if (t.contains('fair') || t.contains('mela')) return '🎪';
    if (t.contains('jatra') || t.contains('puja') || t.contains('ritual')) {
      return '🪔';
    }
    return '📅';
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
    return Consumer2<HeritageProvider, EventProvider>(
      builder: (context, heritage, events, _) {
        final items = _allItems(heritage, events);
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
                _selected = null;
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
                  ...items.map(_itemMarker),
                  if (_userPosition != null) _userMarker(l10n),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Marker _itemMarker(_MapItem item) {
    final isSelected = _selected?.key == item.key;
    final size = isSelected ? 46.0 : 38.0;
    // Events use the temple-red brand fill; sites keep the heritage gold —
    // so the two kinds are distinguishable at a glance.
    final fill = item.isEvent
        ? AppColors.kColorPrimary
        : AppColors.kColorAccentLight;
    return Marker(
      point: item.point,
      width: size,
      height: size,
      child: GestureDetector(
        onTap: () => _selectItem(item),
        child: AnimatedBuilder(
          animation: _bounce,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, isSelected ? -10 * _bounce.value : 0),
            child: child,
          ),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: fill,
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
              item.emoji,
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
            onTap: () => _selectItem(_fromSite(site), fromSearch: true),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.sp12, vertical: AppDimensions.sp10),
              child: Row(
                children: [
                  Text(_siteEmoji(site.category),
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

  /// Default: two closest sites. When a marker (site or event) is tapped, that
  /// item takes over the panel until the map is tapped to deselect.
  Widget _buildNearbyPanel() {
    final l10n = AppLocalizations.of(context)!;
    return Consumer<HeritageProvider>(
      builder: (context, heritage, _) {
        final selected = _selected;
        final List<(_MapItem, double?)> cards;
        if (selected != null) {
          cards = [(selected, _distanceTo(selected))];
        } else {
          cards = _nearestTwoSites(heritage);
        }
        if (cards.isEmpty) return const SizedBox.shrink();
        return Container(
          color: AppColors.kColorBgPage,
          padding: const EdgeInsets.fromLTRB(AppDimensions.sp16,
              AppDimensions.sp12, AppDimensions.sp16, AppDimensions.sp12),
          child: Row(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: AppDimensions.sp12),
                Expanded(child: _itemCard(l10n, cards[i].$1, cards[i].$2)),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _itemCard(AppLocalizations l10n, _MapItem item, double? km) {
    return GestureDetector(
      onTap: () => _selectItem(item),
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
                Text(item.emoji,
                    style: const TextStyle(fontSize: 20, height: 1.2)),
                const SizedBox(width: AppDimensions.sp8),
                Expanded(
                  child: Text(
                    item.title,
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
                Icon(item.isEvent ? Icons.event : Icons.place,
                    size: AppDimensions.iconSm - 2,
                    color: AppColors.kColorTextSecondary),
                const SizedBox(width: AppDimensions.sp4),
                Expanded(
                  child: Text(
                    km != null ? GeoDistance.shortLabel(km) : item.subtitle,
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
                      onPressed: () => _openDetails(item),
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
                      onPressed: _routing && _routeKey == item.key
                          ? null
                          : () => _onDirections(item),
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
                      child: _routing && _routeKey == item.key
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

  void _openDetails(_MapItem item) {
    if (item.isEvent && item.event != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EventDetailScreen(event: item.event!)),
      );
    } else if (item.site != null) {
      Navigator.pushNamed(context, AppStrings.heritageDetailsPath,
          arguments: item.site);
    }
  }
}
