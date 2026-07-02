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
  Future<List<HeritageSite>> getHeritageSites({
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
      return await remoteDataSource.getHeritageSites(
        query: query,
        category: category,
        district: district,
        lat: lat,
        lng: lng,
        radius: radius,
        bbox: bbox,
        sortBy: sortBy,
      );
    } catch (e) {
      // Offline: return previously viewed sites
      final cached = await localDataSource.getLastHeritageSites(limit: 50);
      if (cached.isNotEmpty) return cached;
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
}







