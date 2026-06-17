import 'package:sampada/core/network/api_client.dart';
import 'package:sampada/core/network/api_constants.dart';
import 'package:sampada/data/models/cultural_event_model.dart';

abstract class EventRemoteDataSource {
  Future<List<CulturalEventModel>> getEvents({int? monthBs, int? districtId});
  Future<List<CulturalEventModel>> getNearbyEvents({required double lat, required double lng, double radiusKm = 10});
  Future<List<Map<String, dynamic>>> getCalendarEvents(int monthBs);
}

class EventRemoteDataSourceImpl implements EventRemoteDataSource {
  final ApiClient apiClient;

  EventRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<List<CulturalEventModel>> getEvents({int? monthBs, int? districtId}) async {
    final Map<String, dynamic> queryParams = {};
    if (monthBs != null) queryParams['month_bs'] = monthBs;
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
  }) async {
    final data = await apiClient.get(
      ApiEndpoints.eventsNearby,
      queryParameters: {
        'lat': lat,
        'lon': lng,
        'radius_km': radiusKm,
      },
    );

    final List list = data is List ? data : (data['results'] ?? []);
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
}







