import 'package:flutter/material.dart';
import 'package:sampada/core/network/api_client.dart';
import 'package:sampada/core/network/api_constants.dart';

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
    notifyListeners();
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
      _myProfile = await _apiClient.get(ApiEndpoints.guideMe);
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching guide profile: $e');
    }
  }

  Future<void> fetchMyBookings() async {
    try {
      final data = await _apiClient.get(ApiEndpoints.guideBookings);
      _myBookings = _asList(data).cast<Map<String, dynamic>>();
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching bookings: $e');
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

  /// Submit a review (1–5 + optional text) for a completed booking. Returns
  /// null on success, or an error message to show the user.
  Future<String?> reviewBooking(int bookingId, int rating, String text) async {
    try {
      await _apiClient.post(
        ApiEndpoints.bookingReview(bookingId),
        data: {'rating': rating, 'text': text},
      );
      await fetchMyBookings();
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}







