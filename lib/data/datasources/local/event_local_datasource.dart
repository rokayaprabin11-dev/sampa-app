import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';
import 'package:sampada/core/database/database_helper.dart';
import 'package:sampada/data/models/cultural_event_model.dart';

abstract class EventLocalDataSource {
  Future<List<CulturalEventModel>> getCachedEvents();
  Future<void> cacheEvents(List<CulturalEventModel> events);
  Future<void> clearCache();
}

class EventLocalDataSourceImpl implements EventLocalDataSource {
  final DatabaseHelper dbHelper;

  EventLocalDataSourceImpl({required this.dbHelper});

  @override
  Future<List<CulturalEventModel>> getCachedEvents() async {
    if (kIsWeb) return [];
    
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('local_events');
    
    return maps.map((map) {
      // Convert SQLite fields back to GeoJSON-like structure if model expects it
      // or handle flat map in model
      return CulturalEventModel(
        id: map['id'],
        siteId: map['site_id'],
        title: map['title_en'] as String,
        titleNepali: (map['title_ne'] as String?) ?? '',
        eventType: map['event_type'] as String?,
        description: (map['description_en'] as String?) ?? '',
        descriptionNepali: (map['description_ne'] as String?) ?? '',
        startDate: DateTime.parse(map['event_date_ad'] as String),
        endDate: DateTime.parse(map['event_date_ad'] as String),
        latitude: null,
        longitude: null,
        locationName: (map['district'] as String?) ?? '',
      );
    }).toList();
  }

  @override
  Future<void> cacheEvents(List<CulturalEventModel> events) async {
    if (kIsWeb) return;

    final db = await dbHelper.database;
    final batch = db.batch();
    
    for (var event in events) {
      batch.insert(
        'local_events',
        {
          'id': event.id,
          'site_id': event.siteId,
          'title_en': event.title,
          'title_ne': event.titleNepali,
          'description_en': event.description,
          'description_ne': event.descriptionNepali,
          'event_type': event.eventType,
          'event_date_ad': event.startDate.toIso8601String().split('T')[0],
          'event_date_bs': '',   // set by caller when available
          'district': event.locationName,
          'cached_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    await batch.commit(noResult: true);
  }

  @override
  Future<void> clearCache() async {
    if (kIsWeb) return;
    final db = await dbHelper.database;
    await db.delete('local_events');
  }
}







