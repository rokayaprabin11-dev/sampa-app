import '../entities/heritage_site.dart';
import 'package:sampada/data/models/district_model.dart';

/// Where a heritage-site list actually came from. Callers use this to log
/// cache-vs-remote and to surface the "Offline data" indicator.
enum HeritageDataSource { remote, cache }

/// A heritage-site list plus the source that served it.
class HeritageSitesResult {
  final List<HeritageSite> sites;
  final HeritageDataSource source;

  const HeritageSitesResult(this.sites, this.source);

  const HeritageSitesResult.remote(List<HeritageSite> sites)
      : this(sites, HeritageDataSource.remote);

  const HeritageSitesResult.cache(List<HeritageSite> sites)
      : this(sites, HeritageDataSource.cache);

  bool get isFromCache => source == HeritageDataSource.cache;
}

abstract class HeritageRepository {
  /// Remote-first: hits the API and falls back to the SQLite cache only if the
  /// request fails. Never call this when auto-sync has vetoed network use —
  /// use [getCachedHeritageSites] instead.
  Future<HeritageSitesResult> getHeritageSites({
    String? query,
    String? category,
    String? district,
    double? lat,
    double? lng,
    double? radius,
    String? bbox,
    String? sortBy,
  });

  /// Cache-only: reads previously cached sites straight from SQLite and issues
  /// no HTTP request whatsoever. This is the path taken when Auto Sync is off
  /// (or is WiFi-only and the device is on mobile data).
  Future<HeritageSitesResult> getCachedHeritageSites({int limit = 50});

  Future<List<HeritageSite>> getFeaturedSites({double? lat, double? lng});
  Future<List<HeritageSite>> searchHeritageSites(String query);
  Future<List<DistrictModel>> getDistricts();
  Future<HeritageSite> createHeritageSite(HeritageSite site);
  Future<HeritageSite> getSiteDetail(String slug);
  Future<bool> isSiteDownloaded(String id);
  Future<void> downloadSite(HeritageSite site);
}
