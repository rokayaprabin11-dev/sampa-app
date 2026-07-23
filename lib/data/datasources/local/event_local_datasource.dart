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
    await _pruneExpired(db);
    final List<Map<String, dynamic>> maps = await db.query(
      'local_events',
      // A bounded chronological result is inexpensive to materialize and is
      // sufficient for calendar, current-events, and offline detail screens.
      orderBy: 'event_date_ad ASC',
      limit: 250,
    );

    return maps.map((map) {
      // Convert SQLite fields back to GeoJSON-like structure if model expects it
      // or handle flat map in model
      return CulturalEventModel(
        id: map['id'],
        siteId: map['site_id'],
        title: map['title_en'] as String,
        titleNepali: (map['title_ne'] as String?) ?? '',
        eventType: (map['event_type'] as String?) ?? '',
        description: (map['description_en'] as String?) ?? '',
        descriptionNepali: (map['description_ne'] as String?) ?? '',
        startDate: DateTime.parse(map['event_date_ad'] as String),
        endDate: DateTime.parse(map['event_date_ad'] as String),
        startTime: map['start_time'] as String?,
        endTime: map['end_time'] as String?,
        latitude: 0.0,
        longitude: 0.0,
        locationName: (map['district'] as String?) ?? '',
      );
    }).toList();
  }

  @override
  Future<void> cacheEvents(List<CulturalEventModel> events) async {
    if (kIsWeb) return;

    final db = await dbHelper.database;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final hasFts = await _hasTable(db, 'local_events_fts');
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
          'event_date_bs': '', // set by caller when available
          'start_time': event.startTime,
          'end_time': event.endTime,
          'district': event.locationName,
          'cached_at': now,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      // FTS is a separate virtual table and needs explicit replacement.
      if (hasFts) {
        batch
            .delete('local_events_fts', where: 'id = ?', whereArgs: [event.id]);
        batch.insert('local_events_fts', {
          'id': event.id,
          'title_en': event.title,
          'title_ne': event.titleNepali,
        });
      }
    }
    batch.insert(
        'cache_metadata',
        {
          'table_name': 'local_events',
          'last_sync_at': now,
          'version': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
    await batch.commit(noResult: true);
    await _pruneExpired(db);
  }

  @override
  Future<void> clearCache() async {
    if (kIsWeb) return;
    final db = await dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete('local_events');
      try {
        await txn.delete('local_events_fts');
      } catch (_) {}
    });
  }

  /// Offline events are intentionally bounded to today through the next sixty
  /// days.  This runs after sync and before cached reads, so expired events do
  /// not slowly grow the database between app launches.
  Future<void> _pruneExpired(DatabaseExecutor db) async {
    final today = DateTime.now();
    final firstDay = DateTime(today.year, today.month, today.day);
    final lastDay = firstDay.add(const Duration(days: 60));
    final removed = await db.query(
      'local_events',
      columns: ['id'],
      where: 'event_date_ad < ? OR event_date_ad > ?',
      whereArgs: [
        firstDay.toIso8601String().split('T').first,
        lastDay.toIso8601String().split('T').first,
      ],
    );
    if (removed.isEmpty) return;
    final ids = removed.map((row) => row['id']).toList(growable: false);
    final marks = List.filled(ids.length, '?').join(',');
    await db.delete('local_events', where: 'id IN ($marks)', whereArgs: ids);
    try {
      await db.delete('local_events_fts',
          where: 'id IN ($marks)', whereArgs: ids);
    } catch (_) {}
  }

  Future<bool> _hasTable(DatabaseExecutor db, String table) async {
    final rows = await db.rawQuery(
      "SELECT 1 FROM sqlite_master WHERE type IN ('table', 'view') AND name = ?",
      [table],
    );
    return rows.isNotEmpty;
  }
}
