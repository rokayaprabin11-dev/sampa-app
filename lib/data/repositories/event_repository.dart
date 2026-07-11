import '../entities/cultural_event.dart';

abstract class EventRepository {
  Future<List<CulturalEvent>> getEvents({int? monthBs, int? districtId});
  Future<List<CulturalEvent>> getNearbyEvents({required double lat, required double lng, double radiusKm = 10});
  Future<List<Map<String, dynamic>>> getCalendarEvents(int monthBs);
  Future<void> refreshEvents();
  Future<List<CulturalEvent>> getUpcomingEvents();
  Future<Map<String, int>> getRsvpAffinity();
}







