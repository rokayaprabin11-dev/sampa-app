import 'package:sampada/core/network/api_client.dart';
import 'package:sampada/core/network/api_constants.dart';
import 'package:sampada/data/models/heritage_site_model.dart';
import 'package:sampada/data/models/district_model.dart';

abstract class HeritageRemoteDataSource {
  Future<List<HeritageSiteModel>> getHeritageSites({
    String? query,
    String? category,
    String? district,
    double? lat,
    double? lng, 
    double? radius,
    int? page,
    int? pageSize,
    String? bbox,
    String? sortBy,
  });
  Future<List<HeritageSiteModel>> searchHeritageSites(String query);
  Future<List<DistrictModel>> getDistricts();
  Future<HeritageSiteModel> createHeritageSite(Map<String, dynamic> siteData);
}

class HeritageRemoteDataSourceImpl implements HeritageRemoteDataSource {
  final ApiClient apiClient;
  
  HeritageRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<List<HeritageSiteModel>> searchHeritageSites(String query) async {
    final data = await apiClient.get(
      ApiEndpoints.heritageSites,
      queryParameters: {'search': query},
    );

    final List list = (data is Map) ? (data['results'] ?? []) : data;
    return list
        .whereType<Map<String, dynamic>>()
        .map((json) => HeritageSiteModel.fromJson(json))
        .toList();
  }

  @override
  Future<List<DistrictModel>> getDistricts() async {
    try {
      final data = await apiClient.get(ApiEndpoints.districts);
      final List list = (data is List) ? data : [];
      return list
          .whereType<Map<String, dynamic>>()
          .map((json) => DistrictModel.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<List<HeritageSiteModel>> getHeritageSites({
    String? query,
    String? category,
    String? district,
    double? lat,
    double? lng, 
    double? radius,
    int? page,
    int? pageSize,
    String? bbox,
    String? sortBy,
  }) async {
    final Map<String, dynamic> queryParams = {};
    if (query != null && query.isNotEmpty) queryParams['search'] = query;
    if (category != null && category.isNotEmpty) queryParams['category'] = category;
    if (district != null && district.isNotEmpty) queryParams['district'] = district;
    if (lat != null && lng != null) {
      queryParams['lat'] = lat;
      queryParams['lng'] = lng;
      if (radius != null) queryParams['r'] = radius;
    }
    if (bbox != null) queryParams['bbox'] = bbox;
    if (sortBy != null) queryParams['sort_by'] = sortBy;
    if (page != null) queryParams['page'] = page;
    if (pageSize != null) queryParams['page_size'] = pageSize;

    final data = await apiClient.get(
      ApiEndpoints.heritageSites,
      queryParameters: queryParams,
    );

    // Handle both paginated and non-paginated responses
    final List list = (data is Map) ? (data['results'] ?? []) : data;
    return list
        .whereType<Map<String, dynamic>>()
        .map((json) => HeritageSiteModel.fromJson(json))
        .toList();
  }

  @override
  Future<HeritageSiteModel> createHeritageSite(Map<String, dynamic> siteData) async {
    final data = await apiClient.post(
      ApiEndpoints.heritageSitesCreate,
      data: siteData,
    );
    
    if (data is Map<String, dynamic>) {
      return HeritageSiteModel.fromJson(data);
    }
    throw Exception('Failed to create heritage site: Invalid response format');
  }
}







