import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sampada/data/models/heritage_site.dart';
import 'package:sampada/data/repositories/heritage_repository.dart';
import 'package:sampada/data/datasources/local/heritage_local_datasource.dart';
import 'package:sampada/data/datasources/remote/heritage_remote_datasource.dart';
import 'package:sampada/data/models/district_model.dart';
import 'package:sampada/data/models/heritage_site_model.dart';

class HeritageRepositoryImpl implements HeritageRepository {
  final HeritageRemoteDataSource remoteDataSource;
  final HeritageLocalDataSource localDataSource;

  HeritageRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<List<DistrictModel>> getDistricts() async {
    return await remoteDataSource.getDistricts();
  }

  @override
  Future<HeritageSitesResult> getHeritageSites({
    String? query,
    String? category,
    String? district,
    double? lat,
    double? lng,
    double? radius,
    String? bbox,
    String? sortBy,
  }) async {
    try {
      final sites = await remoteDataSource.getHeritageSites(
        query: query,
        category: category,
        district: district,
        lat: lat,
        lng: lng,
        radius: radius,
        bbox: bbox,
        sortBy: sortBy,
      );
      // Persist list pages after the response has been returned.  SQLite writes
      // must not delay the first visible frame, and failures never invalidate a
      // successful server response.
      unawaited(_cacheSites(sites));
      debugPrint('HeritageRepository: ${sites.length} sites from REMOTE');
      return HeritageSitesResult.remote(sites);
    } catch (e) {
      // Offline: return previously viewed sites
      final cached = await localDataSource.getLastHeritageSites(limit: 50);
      debugPrint('HeritageRepository: remote failed ($e) — '
          'falling back to CACHE (${cached.length} sites)');
      if (cached.isNotEmpty) return HeritageSitesResult.cache(cached);
      rethrow;
    }
  }

  @override
  Future<HeritageSitesResult> getCachedHeritageSites({int limit = 50}) async {
    final cached = await localDataSource.getLastHeritageSites(limit: limit);
    debugPrint('HeritageRepository: ${cached.length} sites from CACHE '
        '(cache-only request — no network call)');
    return HeritageSitesResult.cache(cached);
  }

  @override
  Future<List<HeritageSite>> getFeaturedSites(
      {double? lat, double? lng}) async {
    try {
      return await remoteDataSource.getFeaturedSites(lat: lat, lng: lng);
    } catch (e) {
      // Offline: fall back to previously cached featured sites (no ranking,
      // diversity, rotation or reason — just the last known featured set).
      final cached = await localDataSource.getLastHeritageSites(limit: 50);
      final featured = cached.where((s) => s.isFeatured).toList();
      if (featured.isNotEmpty) return featured;
      rethrow;
    }
  }

  @override
  Future<HeritageSite> createHeritageSite(HeritageSite site) async {
    final siteModel = HeritageSiteModel(
      id: site.id,
      name: site.name,
      nameNepali: site.nameNepali,
      description: site.description,
      descriptionNepali: site.descriptionNepali,
      location: site.location,
      latitude: site.latitude,
      longitude: site.longitude,
      imageUrl: site.imageUrl,
      isUnesco: site.isUnesco,
      rating: site.rating,
      reviewsCount: site.reviewsCount,
      avgVisitHours: site.avgVisitHours,
      category: site.category,
      district: site.district,
      districtId: site.districtId,
      isFeatured: site.isFeatured,
      createdAt: site.createdAt,
    );

    return await remoteDataSource.createHeritageSite(siteModel.toJson());
  }

  @override
  Future<HeritageSite> getSiteDetail(String slug) async {
    final site = await remoteDataSource.getHeritageSiteDetail(slug);
    try {
      await localDataSource.saveSite(site);
    } catch (_) {}
    return site;
  }

  @override
  Future<bool> isSiteDownloaded(String id) async {
    return await localDataSource.isSiteDownloaded(id);
  }

  @override
  Future<void> downloadSite(HeritageSite site) async {
    final model = HeritageSiteModel(
      id: site.id,
      slug: site.slug,
      name: site.name,
      nameNepali: site.nameNepali,
      description: site.description,
      descriptionNepali: site.descriptionNepali,
      location: site.location,
      latitude: site.latitude,
      longitude: site.longitude,
      imageUrl: site.imageUrl,
      isUnesco: site.isUnesco,
      rating: site.rating,
      reviewsCount: site.reviewsCount,
      avgVisitHours: site.avgVisitHours,
      category: site.category,
      district: site.district,
      districtId: site.districtId,
      isFeatured: site.isFeatured,
      createdAt: site.createdAt,
    );
    await localDataSource.saveSite(model);
  }

  @override
  Future<List<HeritageSite>> searchHeritageSites(String query) async {
    try {
      return await remoteDataSource.searchHeritageSites(query);
    } catch (e) {
      return localDataSource.searchSites(query);
    }
  }

  Future<void> _cacheSites(Iterable<HeritageSiteModel> sites) async {
    try {
      await localDataSource.saveSites(sites);
    } catch (e) {
      // A local cache failure must never turn a successful remote fetch into
      // an apparent network failure (including when a test double omits it).
      debugPrint('HeritageRepository: cache write failed: $e');
    }
  }
}
