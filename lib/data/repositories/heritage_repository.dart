import '../entities/heritage_site.dart';
import 'package:sampada/data/models/district_model.dart';

abstract class HeritageRepository {
  Future<List<HeritageSite>> getHeritageSites({
    String? query,
    String? category,
    String? district,
    double? lat,
    double? lng, 
    double? radius,
    String? bbox,
    String? sortBy,
  });
  Future<List<HeritageSite>> searchHeritageSites(String query);
  Future<List<DistrictModel>> getDistricts();
  Future<HeritageSite> createHeritageSite(HeritageSite site);
}







