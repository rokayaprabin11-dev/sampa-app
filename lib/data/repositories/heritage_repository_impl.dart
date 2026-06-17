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
      // Try fetching from remote
      final remoteSites = await remoteDataSource.getHeritageSites(
        query: query,
        category: category,
        district: district,
        lat: lat,
        lng: lng,
        radius: radius,
        bbox: bbox,
        sortBy: sortBy,
      );
      // Cache the result
      await localDataSource.cacheHeritageSites(remoteSites);
      return remoteSites;
    } catch (e) {
      // If remote fails, return from local cache
      final localSites = await localDataSource.getLastHeritageSites();
      if (localSites.isNotEmpty) {
        return localSites;
      } else {
        rethrow;
      }
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
  Future<List<HeritageSite>> searchHeritageSites(String query) async {
    try {
      return await remoteDataSource.searchHeritageSites(query);
    } catch (e) {
      // Fallback to local search on failure
      final allSites = await localDataSource.getLastHeritageSites();
      return allSites.where((site) => 
        site.name.toLowerCase().contains(query.toLowerCase()) ||
        site.district.toLowerCase().contains(query.toLowerCase())
      ).toList();
    }
  }
}







