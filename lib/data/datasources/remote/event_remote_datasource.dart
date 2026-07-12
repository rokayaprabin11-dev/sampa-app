import 'package:sampada/core/network/api_client.dart';
import 'package:sampada/core/network/api_constants.dart';
import 'package:sampada/data/models/cultural_event_model.dart';

abstract class EventRemoteDataSource {
  Future<List<CulturalEventModel>> getEvents({String? dateFrom, String? dateTo, int? districtId});
  Future<List<CulturalEventModel>> getNearbyEvents({required double lat, required double lng, double radiusKm = 10, int? limit});
  Future<List<Map<String, dynamic>>> getCalendarEvents(int monthBs);
  Future<List<CulturalEventModel>> getUpcomingEvents();
  Future<Map<String, int>> getMyRsvpAffinity();
  Future<Map<String, int>> getMyBookmarkAffinity();
  Future<Map<String, int>> getMyVisitAffinity();
  Future<List<int>> getBookmarkedEventIds();
  Future<void> toggleBookmark(int eventId, {required bool currentlyBookmarked});
  Future<void> recordVisit(int eventId);
}

class EventRemoteDataSourceImpl implements EventRemoteDataSource {
  final ApiClient apiClient;

  EventRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<List<CulturalEventModel>> getEvents({String? dateFrom, String? dateTo, int? districtId}) async {
    final Map<String, dynamic> queryParams = {};
    if (dateFrom != null) queryParams['date_from'] = dateFrom;
    if (dateTo != null) queryParams['date_to'] = dateTo;
    if (districtId != null) queryParams['district_id'] = districtId;

    final data = await apiClient.get(
      ApiEndpoints.events,
      queryParameters: queryParams,
    );

    final List list = (data is Map) ? (data['results'] ?? []) : data;
    return list
        .whereType<Map<String, dynamic>>()
        .map((json) => CulturalEventModel.fromJson(json))
        .toList();
  }

  @override
  Future<List<CulturalEventModel>> getNearbyEvents({
    required double lat,
    required double lng,
    double radiusKm = 10,
    int? limit,
  }) async {
    final data = await apiClient.get(
      ApiEndpoints.eventsNearby,
      queryParameters: {
        'lat': lat,
        'lng': lng,
        'radius_km': radiusKm,
        if (limit != null) 'limit': limit,
      },
    );

    final List list = (data is Map) ? (data['results'] ?? []) : data;
    return list
        .whereType<Map<String, dynamic>>()
        .map((json) => CulturalEventModel.fromJson(json))
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getCalendarEvents(int monthBs) async {
    final data = await apiClient.get('${ApiEndpoints.eventsCalendar}$monthBs/');
    final List list = data is List ? data : [];
    return list.cast<Map<String, dynamic>>();
  }

  @override
  Future<List<CulturalEventModel>> getUpcomingEvents() async {
    final data = await apiClient.get(ApiEndpoints.eventsUpcoming);
    final List list = (data is Map) ? (data['results'] ?? []) : data;
    return list
        .whereType<Map<String, dynamic>>()
        .map((json) => CulturalEventModel.fromJson(json))
        .toList();
  }

  @override
  Future<Map<String, int>> getMyRsvpAffinity() async {
    try {
      final data = await apiClient.get(ApiEndpoints.eventsMyRsvpTypes);
      if (data is! Map) return {};
      return data.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
    } catch (_) {
      // Anonymous users (401) or transient errors — affinity is a nice-to-have boost.
      return {};
    }
  }

  @override
  Future<Map<String, int>> getMyBookmarkAffinity() async {
    try {
      final data = await apiClient.get(ApiEndpoints.eventsMyBookmarkTypes);
      if (data is! Map) return {};
      return data.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  @override
  Future<Map<String, int>> getMyVisitAffinity() async {
    try {
      final data = await apiClient.get(ApiEndpoints.eventsMyVisitTypes);
      if (data is! Map) return {};
      return data.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  @override
  Future<List<int>> getBookmarkedEventIds() async {
    try {
      final data = await apiClient.get(ApiEndpoints.eventBookmarks);
      final List list = (data is Map) ? (data['results'] ?? []) : data;
      return list
          .whereType<Map<String, dynamic>>()
          .map((json) => (json['event']?['id'] as num?)?.toInt())
          .whereType<int>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> toggleBookmark(int eventId, {required bool currentlyBookmarked}) async {
    if (currentlyBookmarked) {
      await apiClient.delete(ApiEndpoints.eventBookmarkDelete(eventId));
    } else {
      await apiClient.post(ApiEndpoints.eventBookmarkToggle, data: {'event_id': eventId});
    }
  }

  @override
  Future<void> recordVisit(int eventId) async {
    await apiClient.post(ApiEndpoints.eventRecordVisit(eventId));
  }
}







