import 'package:flutter/material.dart';
import 'package:sampada/core/network/api_client.dart';
import 'package:sampada/core/network/api_constants.dart';

class GuideProvider with ChangeNotifier {
  final ApiClient _apiClient;
  List<Map<String, dynamic>> _guides = [];
  Map<String, dynamic>? _myProfile;
  List<Map<String, dynamic>> _myBookings = [];
  bool _isLoading = false;
  String? _error;

  GuideProvider({required ApiClient apiClient}) : _apiClient = apiClient;

  List<Map<String, dynamic>> get guides => _guides;
  Map<String, dynamic>? get myProfile => _myProfile;
  List<Map<String, dynamic>> get myBookings => _myBookings;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Accept both a plain list and a paginated {results: [...]} response.
  List _asList(dynamic data) => data is Map ? (data['results'] as List? ?? []) : (data as List);

  Future<void> fetchGuides({String? specialization, String? language}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final queryParams = <String, dynamic>{};
      if (specialization != null) queryParams['specialization'] = specialization;
      if (language != null) queryParams['language'] = language;

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
}







