import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sampada/core/database/database_helper.dart';
import 'package:sampada/core/services/content_translator.dart';
import 'package:sampada/data/models/heritage_site_model.dart';

abstract class HeritageLocalDataSource {
  Future<void> cacheHeritageSites(List<HeritageSiteModel> sites);
  Future<List<HeritageSiteModel>> getLastHeritageSites();
  Future<List<HeritageSiteModel>> searchSites(String query, {double? lat, double? lng});
  Future<void> clearCache();
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
  Future<void> cacheHeritageSites(List<HeritageSiteModel> sites) async {
    if (kIsWeb) return;

    final db = await dbHelper.database;
    await db.delete('local_heritage_sites');
    final batch = db.batch();
    for (var site in sites) {
      batch.insert(
        'local_heritage_sites',
        site.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);

    if (contentTranslator != null && userLang != 'en') {
      for (final site in sites) {
        await contentTranslator!.translateAndCacheSiteDescriptions(
          siteId: site.id,
          shortDescEn: '',           // HeritageSite has no separate short desc field
          descriptionEn: site.description,
          targetLang: userLang,
        );
      }
    }
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
      final like = '%$query%';
      final results = await db.rawQuery('''
        SELECT * FROM local_heritage_sites
        WHERE name_en LIKE ? OR name_ne LIKE ? OR district LIKE ?
      ''', [like, like, like]);

      var sites = results.map((map) => HeritageSiteModel.fromMap(map)).toList();

      if (lat != null && lng != null && sites.isNotEmpty) {
        sites.sort((a, b) {
          final distA = _calculateDistance(lat, lng, a.latitude, a.longitude);
          final distB = _calculateDistance(lat, lng, b.latitude, b.longitude);
          return distA.compareTo(distB);
        });
      }

      return sites;
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







