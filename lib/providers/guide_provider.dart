import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sampada/core/network/api_client.dart';
import 'package:sampada/core/network/api_constants.dart';
import 'package:sampada/core/network/network_exceptions.dart';
import 'package:sampada/core/services/location_service.dart';

class GuideProvider with ChangeNotifier {
  final ApiClient _apiClient;
  List<Map<String, dynamic>> _guides = [];
  Map<String, dynamic>? _myProfile;
  List<Map<String, dynamic>> _myBookings = [];
  List<Map<String, dynamic>> _incomingBookings = [];
  bool _isLoading = false;
  String? _error;
  String? _userId;

  GuideProvider({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Called by the AuthProvider proxy on every auth change. Clears the previous
  /// user's guide profile + bookings on login/logout/switch so they never leak
  /// into another session. The public guides list is left intact.
  void updateUserId(String? uid) {
    if (_userId == uid) return;
    _userId = uid;
    _myProfile = null;
    _myBookings = [];
    _incomingBookings = [];
    _error = null;
    _bookingsError = null;
    _bookingsSyncedAt = null;
    _syncLiveTracking(); // profile gone → stop pushing this user's location
    notifyListeners();
  }

  // ─── Live location (guide side) ───────────────────────────────
  // While the logged-in user is an approved guide who is available for
  // bookings, push a validated GPS fix every [_livePingInterval] so tourists
  // see a current distance on guide cards. Foreground-only by design: the
  // timer dies with the app; it restarts whenever the profile is refetched.

  Timer? _liveLocationTimer;
  static const Duration _livePingInterval = Duration(minutes: 5);

  // Presence heartbeat. Separate from the location ping (which is throttled to
  // 5 min because a GPS fix is expensive and a tourist-visible position doesn't
  // need to be fresher). Presence is a cheap Redis SETEX, and the dot has to go
  // grey within ~2 min of the guide closing the app, so it runs on its own
  // faster cadence. Must stay ≤ the server's presence.ONLINE_TTL (150s).
  Timer? _heartbeatTimer;
  static const Duration _heartbeatInterval = Duration(seconds: 60);

  void _syncLiveTracking() {
    final p = _myProfile;
    final shouldTrack = p != null &&
        p['status'] == 'approved' &&
        (p['available_for_bookings'] as bool? ?? false);
    if (shouldTrack && _liveLocationTimer == null) {
      _pushLiveLocation(); // immediate first ping
      _liveLocationTimer =
          Timer.periodic(_livePingInterval, (_) => _pushLiveLocation());
      _sendHeartbeat(); // go green immediately, don't wait a full interval
      _heartbeatTimer =
          Timer.periodic(_heartbeatInterval, (_) => _sendHeartbeat());
    } else if (!shouldTrack) {
      _liveLocationTimer?.cancel();
      _liveLocationTimer = null;
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
      // No explicit "go offline" call: the server key carries a TTL, so it
      // lapses on its own within ~2.5 heartbeats. And a guide who turned
      // bookings off is never shown green anyway — the server gates the dot on
      // available_for_bookings.
    }
  }

  /// Foreground-only by design: the OS suspends timers when the app is
  /// backgrounded, so the guide simply stops pinging and lapses to "last seen".
  /// That is honest — a backgrounded app can't accept a booking either.
  Future<void> _sendHeartbeat() async {
    try {
      await _apiClient.post(ApiEndpoints.guideHeartbeat);
    } catch (_) {/* best-effort; the next tick retries, TTL covers one miss */}
  }

  Future<void> _pushLiveLocation() async {
    // Accuracy-gated (Kalman-smoothed) fix first, one raw fix as fallback.
    // The backend drops mocked or >200 m fixes, so junk never goes live.
    final svc = LocationService();
    final pos = await svc.getAccurateFix() ?? await svc.getCurrentPosition();
    if (pos == null) return;
    try {
      await _apiClient.post(ApiEndpoints.guideLocationUpdate, data: {
        'lat': pos.latitude,
        'lng': pos.longitude,
        'accuracy_m': pos.accuracy,
        'is_mocked': pos.isMocked,
      });
    } catch (_) {/* best-effort; the next tick retries */}
  }

  @override
  void dispose() {
    _liveLocationTimer?.cancel();
    _heartbeatTimer?.cancel();
    super.dispose();
  }

  List<Map<String, dynamic>> get guides => _guides;
  Map<String, dynamic>? get myProfile => _myProfile;
  List<Map<String, dynamic>> get myBookings => _myBookings;
  List<Map<String, dynamic>> get incomingBookings => _incomingBookings;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// True when the tourist has an unanswered request with this guide — used to
  /// block re-hiring until the guide responds.
  bool hasPendingWith(int guideId) =>
      _myBookings.any((b) => b['guide'] == guideId && b['status'] == 'pending');

  /// The booking that authorizes a chat with this guide, or null if there is
  /// none. Chat unlocks only once the guide has accepted (`confirmed`) and stays
  /// reachable through `completed` so the two can settle up afterwards — the
  /// backend enforces the same rule and has the final say (it also closes the
  /// thread some days after the tour).
  ///
  /// Most recent first: if a tourist has toured with the same guide twice, the
  /// Message button should open the current conversation, not last year's.
  int? chatBookingIdWith(int guideId) {
    final eligible = _myBookings
        .where((b) =>
            b['guide'] == guideId &&
            (b['status'] == 'confirmed' || b['status'] == 'completed'))
        .toList()
      ..sort((a, b) => '${b['date']}'.compareTo('${a['date']}'));
    if (eligible.isEmpty) return null;
    final id = eligible.first['id'];
    return id is int ? id : null;
  }

  // Accept both a plain list and a paginated {results: [...]} response.
  List _asList(dynamic data) => data is Map ? (data['results'] as List? ?? []) : (data as List);

  Future<void> fetchGuides({String? specialization, String? language, String? search}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final queryParams = <String, dynamic>{};
      if (specialization != null) queryParams['specialization'] = specialization;
      if (language != null) queryParams['language'] = language;
      if (search != null && search.trim().isNotEmpty) queryParams['search'] = search.trim();

      final data = await _apiClient.get(ApiEndpoints.guides, queryParameters: queryParams);
      _guides = _asList(data).cast<Map<String, dynamic>>();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchMyProfile() async {
    try {
      final data = await _apiClient.get(ApiEndpoints.guideMe);
      _myProfile = (data is Map<String, dynamic>) ? data : null;
      _syncLiveTracking();
      notifyListeners();
    } on ServerException catch (e) {
      // 404 = the logged-in user simply isn't a guide. Expected, not an error —
      // clear any stale profile silently instead of logging noise.
      if (e.statusCode == 404) {
        _myProfile = null;
        _syncLiveTracking();
        notifyListeners();
      } else {
        debugPrint('Error fetching guide profile: $e');
      }
    } catch (e) {
      debugPrint('Error fetching guide profile: $e');
    }
  }

  /// PATCH the logged-in guide's own profile (bio, rate, languages, specialties,
  /// photo, booking settings). Returns null on success, else an error message.
  Future<String?> updateMyProfile(Map<String, dynamic> data) async {
    try {
      final result = await _apiClient.patch(ApiEndpoints.guideMe, data: data);
      if (result is Map<String, dynamic>) _myProfile = result;
      _syncLiveTracking(); // available_for_bookings may have toggled
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('Error updating guide profile: $e');
      return e.toString();
    }
  }

  /// Non-null when the last [fetchMyBookings] failed. Without this the bookings
  /// screen cannot tell "the request failed" apart from "you have no bookings",
  /// so a network error would silently render as an empty list.
  String? _bookingsError;
  String? get bookingsError => _bookingsError;

  /// When the bookings list last came back from the server — backs the
  /// "last synced" line shown while offline.
  DateTime? _bookingsSyncedAt;
  DateTime? get bookingsSyncedAt => _bookingsSyncedAt;

  Future<void> fetchMyBookings() async {
    try {
      final data = await _apiClient.get(ApiEndpoints.guideBookings);
      _myBookings = _asList(data).cast<Map<String, dynamic>>();
      _bookingsError = null;
      _bookingsSyncedAt = DateTime.now();
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching bookings: $e');
      _bookingsError = e.toString();
      notifyListeners();
    }
  }

  Future<void> applyAsGuide(Map<String, dynamic> data) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _apiClient.post(ApiEndpoints.guideApply, data: data);
      await fetchMyProfile();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> createBooking(Map<String, dynamic> data) async {
    final result = await _apiClient.post(ApiEndpoints.bookings, data: data);
    await fetchMyBookings();
    return result as Map<String, dynamic>;
  }

  Future<void> updateBookingStatus(int bookingId, String status) async {
    try {
      await _apiClient.patch(
        '${ApiEndpoints.guideBookings}$bookingId/',
        data: {'status': status},
      );
      await fetchMyBookings();
    } catch (e) {
      debugPrint('Error updating booking: $e');
    }
  }

  /// Booking requests addressed to the logged-in guide.
  Future<void> fetchIncomingBookings() async {
    try {
      final data = await _apiClient.get(ApiEndpoints.guideIncomingBookings);
      _incomingBookings = _asList(data).cast<Map<String, dynamic>>();
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching incoming bookings: $e');
    }
  }

  /// Guide accepts/rejects a request. Returns null on success, else an error.
  Future<String?> respondToBooking(int bookingId, String action) async {
    try {
      await _apiClient.post(ApiEndpoints.bookingRespond(bookingId), data: {'action': action});
      await fetchIncomingBookings();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Completion handshake. The guide asserts the tour happened; the tourist
  /// counter-signs, which flips the booking to `completed` and makes the
  /// payment due. Returns null on success, else an error message.
  Future<String?> completeTour(int bookingId, {required bool asGuide}) async {
    try {
      await _apiClient.post(ApiEndpoints.bookingComplete(bookingId));
      await (asGuide ? fetchIncomingBookings() : fetchMyBookings());
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// One booking, straight from the server. Used where the caller has an id but
  /// no booking — a payment push opening the payment screen, or a payment whose
  /// booking is not in this user's cached list. Returns null if it cannot be
  /// read (deleted, or not this user's).
  ///
  /// There is no `recordPayment` any more: the tourist used to POST
  /// `bookings/<id>/payment/` and the booking became `paid` on their word alone.
  /// Settlement now runs through PaymentRepository — the tourist submits a
  /// claim, the guide confirms it.
  Future<Map<String, dynamic>?> fetchBooking(int bookingId) async {
    try {
      final data = await _apiClient.get(ApiEndpoints.bookingDetail(bookingId));
      return data is Map ? data.cast<String, dynamic>() : null;
    } catch (e) {
      debugPrint('Error fetching booking $bookingId: $e');
      return null;
    }
  }

  /// Submit a review for a completed booking: an overall 1–5 rating, optional
  /// text, and optionally a 1–5 score per category (knowledge, communication,
  /// friendliness, punctuality, value). Categories the tourist skipped are
  /// simply absent — the server stores those as null rather than as a zero.
  /// Returns null on success, or an error message to show the user.
  Future<String?> reviewBooking(
    int bookingId,
    int rating,
    String text, {
    Map<String, int> categories = const {},
  }) async {
    try {
      await _apiClient.post(
        ApiEndpoints.bookingReview(bookingId),
        data: {
          'rating': rating,
          'text': text,
          if (categories.isNotEmpty) 'categories': categories,
        },
      );
      await fetchMyBookings();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// The guide's public answer to a review of them. Only the reviewed guide may
  /// call this, and only once the tourist has written the review — the server
  /// enforces both. Returns null on success, else an error message.
  Future<String?> replyToReview(int bookingId, String text) async {
    try {
      await _apiClient.post(
        ApiEndpoints.bookingReviewReply(bookingId),
        data: {'text': text},
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// A guide's public reviews, paginated, plus a `summary` (rating average,
  /// star distribution and per-category averages) computed over *all* of their
  /// reviews — not just the page or the current search.
  ///
  /// Not cached in the provider: the reviews screen owns this state (it has its
  /// own paging, sort and search), and stashing it here would make one guide's
  /// reviews leak into the next guide's screen.
  Future<Map<String, dynamic>> fetchGuideReviews(
    int guideId, {
    String sort = 'recent',
    String search = '',
    int page = 1,
  }) async {
    final data = await _apiClient.get(
      ApiEndpoints.guideReviews(guideId),
      queryParameters: {
        'sort': sort,
        'page': page,
        if (search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    return (data as Map).cast<String, dynamic>();
  }
}







