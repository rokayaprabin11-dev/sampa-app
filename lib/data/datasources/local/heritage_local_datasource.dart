import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sampada/core/database/database_helper.dart';
import 'package:sampada/core/utils/geo_distance.dart';
import 'package:sampada/core/services/content_translator.dart';
import 'package:sampada/data/models/heritage_site_model.dart';

abstract class HeritageLocalDataSource {
  Future<void> saveSite(HeritageSiteModel site);
  Future<bool> isSiteDownloaded(String id);
  Future<List<HeritageSiteModel>> getLastHeritageSites({int limit = 20, int offset = 0});
  Future<HeritageSiteModel?> getSiteById(String id);
  Future<List<HeritageSiteModel>> searchSites(String query, {double? lat, double? lng});
  Future<List<HeritageSiteModel>> getNearbySites(double lat, double lng, {int limit = 20});
  Future<void> clearCache();
  Future<void> evictStaleCache({int maxAgeDays = 7});
}

class HeritageLocalDataSourceImpl implements HeritageLocalDataSource {
  final DatabaseHelper dbHelper;
  final ContentTranslator? contentTranslator;
  final String userLang;

  HeritageLocalDataSourceImpl({
    required this.dbHelper,
    this.contentTranslator,
    this.userLang = 'en',
  });

  @override
  Future<void> saveSite(HeritageSiteModel site) async {
    if (kIsWeb) return;
    final db = await dbHelper.database;
    await db.transaction((txn) async {
      await txn.insert('local_heritage_sites', site.toJson(),
          conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.insert(
        'local_heritage_sites_fts',
        {
          'id': site.id,
          'name_en': site.name,
          'name_ne': site.nameNepali,
          'district': site.district,
          'category': site.category,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  @override
  Future<bool> isSiteDownloaded(String id) async {
    if (kIsWeb) return false;
    final db = await dbHelper.database;
    final rows = await db.query('local_heritage_sites',
        columns: ['id'], where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isNotEmpty;
  }

  @override
  Future<List<HeritageSiteModel>> getLastHeritageSites({
    int limit = 20,
    int offset = 0,
  }) async {
    if (kIsWeb) return [];
    try {
      final db = await dbHelper.database;
      final maps = await db.query(
        'local_heritage_sites',
        orderBy: 'is_featured DESC, rating_avg DESC',
        limit: limit,
        offset: offset,
      );
      return maps.map(HeritageSiteModel.fromMap).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<HeritageSiteModel?> getSiteById(String id) async {
    if (kIsWeb) return null;
    try {
      final db = await dbHelper.database;
      final rows = await db.query(
        'local_heritage_sites',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return HeritageSiteModel.fromMap(rows.first);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<List<HeritageSiteModel>> searchSites(String query,
      {double? lat, double? lng}) async {
    if (kIsWeb) return [];
    try {
      final db = await dbHelper.database;

      // FTS5 match — escape double-quotes in query
      final ftsQuery = '"${query.replaceAll('"', '""')}"*';
      final ftsRows = await db.rawQuery('''
        SELECT s.*
        FROM local_heritage_sites s
        INNER JOIN local_heritage_sites_fts f ON s.id = f.id
        WHERE local_heritage_sites_fts MATCH ?
        ORDER BY s.rating_avg DESC
        LIMIT 50
      ''', [ftsQuery]);

      // Fallback to LIKE if FTS returns nothing (handles partial/special chars)
      final rows = ftsRows.isNotEmpty
          ? ftsRows
          : await db.rawQuery('''
              SELECT * FROM local_heritage_sites
              WHERE name_en LIKE ? OR name_ne LIKE ? OR district LIKE ?
              ORDER BY rating_avg DESC
              LIMIT 50
            ''', ['%$query%', '%$query%', '%$query%']);

      var sites = rows.map(HeritageSiteModel.fromMap).toList();

      if (lat != null && lng != null && sites.isNotEmpty) {
        sites.sort((a, b) {
          final dA = GeoDistance.haversineKm(lat, lng, a.latitude, a.longitude);
          final dB = GeoDistance.haversineKm(lat, lng, b.latitude, b.longitude);
          return dA.compareTo(dB);
        });
      }

      return sites;
    } catch (e) {
      debugPrint('Local search error: $e');
      return [];
    }
  }

  @override
  Future<List<HeritageSiteModel>> getNearbySites(
    double lat,
    double lng, {
    int limit = 20,
  }) async {
    if (kIsWeb) return [];
    try {
      final db = await dbHelper.database;
      // Bounding box pre-filter (~50 km) then sort by exact distance in Dart
      const deg = 0.45; // ~50 km
      final rows = await db.rawQuery('''
        SELECT * FROM local_heritage_sites
        WHERE latitude  BETWEEN ? AND ?
          AND longitude BETWEEN ? AND ?
        ORDER BY rating_avg DESC
        LIMIT 200
      ''', [lat - deg, lat + deg, lng - deg, lng + deg]);

      final sites = rows.map(HeritageSiteModel.fromMap).toList()
        ..sort((a, b) {
          return GeoDistance.haversineKm(lat, lng, a.latitude, a.longitude)
              .compareTo(
                  GeoDistance.haversineKm(lat, lng, b.latitude, b.longitude));
        });

      return sites.take(limit).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<void> clearCache() async {
    if (kIsWeb) return;
    final db = await dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete('local_heritage_sites');
      await txn.delete('local_heritage_sites_fts');
    });
  }

  @override
  Future<void> evictStaleCache({int maxAgeDays = 10}) async {
    if (kIsWeb) return;
    try {
      final db = await dbHelper.database;
      final cutoff = DateTime.now()
              .subtract(Duration(days: maxAgeDays))
              .millisecondsSinceEpoch ~/
          1000;
      final stale = await db.query(
        'local_heritage_sites',
        columns: ['id'],
        where: 'cached_at < ?',
        whereArgs: [cutoff],
      );
      if (stale.isEmpty) return;
      final ids = stale.map((r) => r['id'] as String).toList();
      final placeholders = List.filled(ids.length, '?').join(',');
      await db.transaction((txn) async {
        await txn.rawDelete(
            'DELETE FROM local_heritage_sites WHERE id IN ($placeholders)', ids);
        await txn.rawDelete(
            'DELETE FROM local_heritage_sites_fts WHERE id IN ($placeholders)', ids);
      });
    } catch (e) {
      debugPrint('Cache eviction error: $e');
    }
  }

}
