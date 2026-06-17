import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sampada/core/database/database_helper.dart';
import 'package:sampada/data/models/heritage_site_model.dart';

abstract class HeritageLocalDataSource {
  Future<void> cacheHeritageSites(List<HeritageSiteModel> sites);
  Future<List<HeritageSiteModel>> getLastHeritageSites();
  Future<List<HeritageSiteModel>> searchSites(String query, {double? lat, double? lng});
  Future<void> clearCache();
}

class HeritageLocalDataSourceImpl implements HeritageLocalDataSource {
  final DatabaseHelper dbHelper;

  HeritageLocalDataSourceImpl({required this.dbHelper});

  @override
  Future<void> cacheHeritageSites(List<HeritageSiteModel> sites) async {
    if (kIsWeb) return;

    final db = await dbHelper.database;
    final batch = db.batch();
    for (var site in sites) {
      batch.insert(
        'local_heritage_sites',
        site.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<List<HeritageSiteModel>> getLastHeritageSites() async {
    if (kIsWeb) return [];

    try {
      final db = await dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query('local_heritage_sites');
      return maps.map((map) => HeritageSiteModel.fromMap(map)).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<List<HeritageSiteModel>> searchSites(String query, {double? lat, double? lng}) async {
    if (kIsWeb) return [];

    try {
      final db = await dbHelper.database;
      final results = await db.rawQuery('''
        SELECT s.*, f.rank as fts_rank FROM local_heritage_sites s
        INNER JOIN local_heritage_sites_fts f ON s.id = f.id
        WHERE local_heritage_sites_fts MATCH ?
        ORDER BY rank
      ''', ['$query*']);

      var sitesAndRanks = results.map((map) {
        return {
          'site': HeritageSiteModel.fromMap(map),
          'rank': map['fts_rank'] as double,
        };
      }).toList();

      // Local Hybrid Ranking (Text Relevance + Distance)
      if (lat != null && lng != null && sitesAndRanks.isNotEmpty) {
        sitesAndRanks.sort((a, b) {
          final siteA = a['site'] as HeritageSiteModel;
          final siteB = b['site'] as HeritageSiteModel;
          
          final distA = _calculateDistance(lat, lng, siteA.latitude, siteA.longitude);
          final distB = _calculateDistance(lat, lng, siteB.latitude, siteB.longitude);
          
          // Simple hybrid score: (Distance penalty) + (FTS Rank penalty)
          // Note: FTS5 rank is often negative (more negative = better) depending on weight config.
          final scoreA = distA + ((a['rank'] as double).abs() * 10);
          final scoreB = distB + ((b['rank'] as double).abs() * 10);
          
          return scoreA.compareTo(scoreB);
        });
      }

      return sitesAndRanks.map((e) => e['site'] as HeritageSiteModel).toList();
    } catch (e) {
      debugPrint('Local search error: $e');
      return [];
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double r = 6371; // Earth radius in km
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  double _toRadians(double degree) {
    return degree * math.pi / 180;
  }

  @override
  Future<void> clearCache() async {
    if (kIsWeb) return;
    final db = await dbHelper.database;
    await db.delete('local_heritage_sites');
  }
}







