import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_dimensions.dart';
import 'package:sampada/core/network/api_client.dart';
import 'package:sampada/core/services/route_service.dart';
import 'package:sampada/core/services/tracking_service.dart';
import 'package:sampada/injection.dart' as di;
import 'package:sampada/presentation/widgets/common/sampada_app_bar.dart';

/// Mutual live tracking for a confirmed booking: each party sees the other's
/// position, the route between them, the distance and the ETA, updating in near
/// real time. Sharing is gated by the backend (see BookingTrackingView) and
/// stops the instant the tour is completed or cancelled — this screen watches
/// the channel state and shuts itself down when that happens.
class LiveTrackingScreen extends StatefulWidget {
  final int bookingId;
  final String otherPartyName;

  const LiveTrackingScreen({
    super.key,
    required this.bookingId,
    required this.otherPartyName,
  });

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  static const _nepalCenter = LatLng(28.3949, 84.1240);
  static const _pushMinInterval = Duration(seconds: 5);
  static const _routeMinInterval = Duration(seconds: 12);
  static const _distance = Distance();

  final MapController _map = MapController();
  late final TrackingService _tracking;
  late final RouteService _routeSvc;

  TrackChannel? _channel;
  LatLng? _myPos;
  LatLng? _peerPos;
  RouteResult? _route;
  DateTime? _peerUpdatedAt;

  StreamSubscription<Position>? _geoSub;
  StreamSubscription<LivePosition?>? _peerSub;
  StreamSubscription<String>? _stateSub;
  DateTime? _lastPush;
  DateTime? _lastRouteFetch;
  bool _fetchingRoute = false;
  bool _fitted = false;

  bool _loading = true;
  bool _ended = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tracking = TrackingService(apiClient: di.sl<ApiClient>());
    _routeSvc = RouteService(apiClient: di.sl<ApiClient>());
    _init();
  }

  Future<void> _init() async {
    final channel = await _tracking.openChannel(widget.bookingId);
    if (!mounted) return;
    if (channel == null || !channel.isActive) {
      setState(() {
        _loading = false;
        _error = 'Live location is not available for this booking yet. '
            'It starts once the guide accepts and stays on until the tour ends.';
      });
      return;
    }

    setState(() {
      _channel = channel;
      _loading = false;
    });

    // Watch the authoritative state: the moment Django ends the tour, stop.
    _stateSub = _tracking.channelState(channel.channelId).listen((state) {
      if (state != 'active' && mounted && !_ended) _endTracking();
    });

    // Stream the other party's position.
    _peerSub =
        _tracking.peerPosition(channel.channelId, channel.otherUid).listen((p) {
      if (p == null || !mounted) return;
      setState(() {
        _peerPos = p.point;
        _peerUpdatedAt = p.updatedAt;
      });
      _maybeFit();
      _maybeRefreshRoute();
    });

    await _startMyLocation(channel);
  }

  Future<void> _startMyLocation(TrackChannel channel) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      _showSnack('Turn on location services to share your position.');
      return;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      _showSnack('Location permission is needed to share your position.');
      return;
    }

    _geoSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // metres — don't spam on a stationary phone
      ),
    ).listen((pos) => _onMyFix(channel, pos));
  }

  void _onMyFix(TrackChannel channel, Position pos) {
    if (!mounted || _ended) return;
    setState(() => _myPos = LatLng(pos.latitude, pos.longitude));
    _maybeFit();
    _maybeRefreshRoute();

    // Throttle the Firestore write: the 10 m distance filter already thins
    // these, and 5 s is smooth enough for a person walking.
    final now = DateTime.now();
    if (_lastPush != null && now.difference(_lastPush!) < _pushMinInterval) {
      return;
    }
    _lastPush = now;
    _tracking.pushPosition(
      channel.channelId,
      uid: channel.myUid,
      lat: pos.latitude,
      lng: pos.longitude,
      accuracyM: pos.accuracy,
      heading: pos.heading >= 0 ? pos.heading : null,
    );
  }

  Future<void> _maybeRefreshRoute() async {
    final me = _myPos, peer = _peerPos;
    if (me == null || peer == null || _fetchingRoute) return;
    final now = DateTime.now();
    if (_lastRouteFetch != null &&
        now.difference(_lastRouteFetch!) < _routeMinInterval) {
      return;
    }
    _fetchingRoute = true;
    _lastRouteFetch = now;
    try {
      final r = await _routeSvc.fetchRoute(start: me, dest: peer);
      if (mounted && r != null) setState(() => _route = r);
    } catch (_) {
      // Routing is best-effort; the straight-line distance still shows.
    } finally {
      _fetchingRoute = false;
    }
  }

  void _maybeFit() {
    if (_fitted || _myPos == null || _peerPos == null) return;
    _fitted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final fit = CameraFit.bounds(
        bounds: LatLngBounds.fromPoints([_myPos!, _peerPos!]),
        padding: const EdgeInsets.all(64),
      ).fit(_map.camera);
      _map.move(fit.center, fit.zoom);
    });
  }

  void _endTracking() {
    _geoSub?.cancel();
    _peerSub?.cancel();
    if (mounted) setState(() => _ended = true);
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _geoSub?.cancel();
    _peerSub?.cancel();
    _stateSub?.cancel();
    super.dispose();
  }

  // ── Derived display values ────────────────────────────────────────────────

  double? get _distanceM {
    final me = _myPos, peer = _peerPos;
    if (me == null || peer == null) return null;
    // Route distance is truer than straight-line once we have it.
    return _route?.distanceM ?? _distance.as(LengthUnit.Meter, me, peer);
  }

  String get _distanceLabel {
    final d = _distanceM;
    if (d == null) return '—';
    return d < 1000 ? '${d.round()} m' : '${(d / 1000).toStringAsFixed(1)} km';
  }

  String get _etaLabel {
    final r = _route;
    if (r == null) return '—';
    return '${r.durationMin} min';
  }

  String get _peerFreshness {
    final at = _peerUpdatedAt;
    if (at == null) return 'waiting for location…';
    final secs = DateTime.now().difference(at).inSeconds;
    if (secs < 10) return 'live now';
    if (secs < 60) return 'updated ${secs}s ago';
    return 'updated ${(secs / 60).floor()} min ago';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SampadaAppBar(
        title: Text('Live location · ${widget.otherPartyName}'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorView(_error!)
              : _mapView(),
    );
  }

  Widget _errorView(String msg) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.sp24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_off_outlined,
                  size: 48, color: AppColors.statusInfo),
              const SizedBox(height: AppDimensions.sp12),
              Text(msg, textAlign: TextAlign.center),
            ],
          ),
        ),
      );

  Widget _mapView() {
    return Stack(
      children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: _myPos ?? _peerPos ?? _nepalCenter,
            initialZoom: 14,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.sampada.app',
            ),
            if (_route != null)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _route!.points,
                    strokeWidth: 5,
                    color: AppColors.statusInfo,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                if (_peerPos != null)
                  Marker(
                    point: _peerPos!,
                    width: 44,
                    height: 44,
                    child: _pin(
                      icon: _channel?.otherRole == 'guide'
                          ? Icons.badge
                          : Icons.person_pin_circle,
                      color: AppColors.statusError,
                    ),
                  ),
                if (_myPos != null)
                  Marker(
                    point: _myPos!,
                    width: 30,
                    height: 30,
                    child: _meDot(),
                  ),
              ],
            ),
          ],
        ),
        _infoBanner(),
        if (_ended) _endedOverlay(),
      ],
    );
  }

  Widget _infoBanner() {
    return Positioned(
      top: AppDimensions.sp12,
      left: AppDimensions.sp12,
      right: AppDimensions.sp12,
      child: Card(
        elevation: 3,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.sp16, vertical: AppDimensions.sp12),
          child: Row(
            children: [
              _stat('Distance', _distanceLabel, Icons.straighten),
              _divider(),
              _stat('ETA', _etaLabel, Icons.schedule),
              _divider(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.otherPartyName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Row(
                      children: [
                        Icon(Icons.circle,
                            size: 8,
                            color: _peerUpdatedAt != null &&
                                    DateTime.now()
                                            .difference(_peerUpdatedAt!)
                                            .inSeconds <
                                        15
                                ? AppColors.statusSuccess
                                : AppColors.kColorPendingText),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(_peerFreshness,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, String value, IconData icon) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.statusInfo),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13)),
          Text(label, style: const TextStyle(fontSize: 10)),
        ],
      );

  Widget _divider() => Container(
        width: 1,
        height: 34,
        color: Colors.black12,
        margin: const EdgeInsets.symmetric(horizontal: AppDimensions.sp12),
      );

  Widget _pin({required IconData icon, required Color color}) => Icon(
        icon,
        color: color,
        size: 40,
        shadows: const [Shadow(blurRadius: 4, color: Colors.black38)],
      );

  Widget _meDot() => Container(
        decoration: BoxDecoration(
          color: AppColors.statusInfo,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)],
        ),
      );

  Widget _endedOverlay() => Positioned.fill(
        child: Container(
          color: Colors.black54,
          alignment: Alignment.center,
          child: Card(
            margin: const EdgeInsets.all(AppDimensions.sp24),
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.sp24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.flag_outlined, size: 40),
                  const SizedBox(height: AppDimensions.sp12),
                  const Text('Tour ended',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: AppDimensions.sp8),
                  const Text('Location sharing has stopped.',
                      textAlign: TextAlign.center),
                  const SizedBox(height: AppDimensions.sp16),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
