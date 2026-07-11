import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_dimensions.dart';
import 'package:sampada/core/constants/app_strings.dart';
import 'package:sampada/core/services/location_service.dart';
import 'package:sampada/core/utils/geo_distance.dart';
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

  @override
  void initState() {
    super.initState();
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
    _flyController?.dispose();
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  // ── Camera ────────────────────────────────────────────────────────────────

  /// Google-Maps-style camera flight: position and zoom tween together over
  /// many frames instead of jumping. Long hops (>50 km) zoom out to a mid
  /// level first, then dive back in, so the ride reads as one smooth arc.
  void _flyTo(LatLng dest, double destZoom, {Duration? duration}) {
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
    controller.forward();
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

  // ── Search ────────────────────────────────────────────────────────────────

  void _onSearch(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return;
    final sites = context
        .read<HeritageProvider>()
        .sites
        .where(_validCoords)
        .toList();

    HeritageSite? match;
    for (final s in sites) {
      if (s.name.toLowerCase().startsWith(q)) {
        match = s;
        break;
      }
    }
    match ??= sites.cast<HeritageSite?>().firstWhere(
          (s) =>
              s!.name.toLowerCase().contains(q) ||
              s.nameNepali.contains(query.trim()) ||
              s.location.toLowerCase().contains(q),
          orElse: () => null,
        );

    FocusScope.of(context).unfocus();
    if (match == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.labelNotFound)),
      );
      return;
    }
    setState(() => _selectedSite = match);
    _flyTo(LatLng(match.latitude, match.longitude), _siteZoom);
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
            onTap: (_, __) => setState(() => _selectedSite = null),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.sampada.app',
              maxZoom: 19,
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
          _flyTo(LatLng(site.latitude, site.longitude), _siteZoom);
        },
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

  Widget _buildNearbyPanel() {
    final l10n = AppLocalizations.of(context)!;
    return Consumer<HeritageProvider>(
      builder: (context, heritage, _) {
        final nearest = _nearestTwo(heritage.sites);
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
            SizedBox(
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
                      horizontal: AppDimensions.sp12),
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
          ],
        ),
      ),
    );
  }
}
