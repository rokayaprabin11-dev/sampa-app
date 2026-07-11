import 'package:sampada/data/models/cultural_event.dart';
import 'package:sampada/data/repositories/event_repository.dart';
import 'package:sampada/data/datasources/remote/event_remote_datasource.dart';
import 'package:sampada/data/datasources/local/event_local_datasource.dart';

class EventRepositoryImpl implements EventRepository {
  final EventRemoteDataSource remoteDataSource;
  final EventLocalDataSource localDataSource;

  EventRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<List<CulturalEvent>> getEvents({int? monthBs, int? districtId}) async {
    try {
      final remoteEvents = await remoteDataSource.getEvents(
        monthBs: monthBs,
        districtId: districtId,
      );
      if (monthBs == null && districtId == null) {
        await localDataSource.cacheEvents(remoteEvents);
      }
      return remoteEvents;
    } catch (e) {
      return await localDataSource.getCachedEvents();
    }
  }

  @override
  Future<List<CulturalEvent>> getNearbyEvents({
    required double lat,
    required double lng,
    double radiusKm = 10,
  }) async {
    return await remoteDataSource.getNearbyEvents(
      lat: lat,
      lng: lng,
      radiusKm: radiusKm,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getCalendarEvents(int monthBs) async {
    return await remoteDataSource.getCalendarEvents(monthBs);
  }

  @override
  Future<void> refreshEvents() async {
    final remoteEvents = await remoteDataSource.getEvents();
    await localDataSource.cacheEvents(remoteEvents);
  }

  @override
  Future<List<CulturalEvent>> getUpcomingEvents() async {
    return await remoteDataSource.getUpcomingEvents();
  }

  @override
  Future<Map<String, int>> getRsvpAffinity() async {
    return await remoteDataSource.getMyRsvpAffinity();
  }
}







