import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sampada/data/models/heritage_site.dart';
import 'package:sampada/data/repositories/heritage_repository.dart';
import 'package:sampada/data/models/district_model.dart';
import 'package:sampada/providers/auto_sync_provider.dart';

class HeritageProvider with ChangeNotifier {
  final HeritageRepository repository;
  AutoSyncProvider? autoSyncProvider;

  List<HeritageSite> _sites = [];
  List<DistrictModel> _districts = [];
  bool _isLoading = false;
  String? _error;

  // Search state
  String _currentQuery = '';
  String _currentCategory = 'All';
  Timer? _debounceTimer;

  HeritageProvider({required this.repository, this.autoSyncProvider});

  List<HeritageSite> get sites => _sites;
  List<DistrictModel> get districts => _districts;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get currentQuery => _currentQuery;
  String get currentCategory => _currentCategory;

  List<HeritageSite> getFeaturedSites({String? category}) {
    if (_sites.isEmpty) return [];

    final slug = _slugify(category ?? '');
    final filteredList = (slug.isEmpty || slug == 'all')
        ? _sites
        : _sites.where((s) => _slugify(s.category) == slug).toList();

    final sortedList = List<HeritageSite>.from(filteredList)
      ..sort((a, b) => (b.isFeatured ? 1 : 0).compareTo(a.isFeatured ? 1 : 0));

    return sortedList.take(6).toList();
  }

  // Normalize plural UI labels + locale strings → backend singular slug
  String _slugify(String raw) {
    final s = raw.toLowerCase().trim();
    const map = {
      'temples': 'temple',
      'stupas': 'stupa',
      'palaces': 'palace',
      'monasteries': 'monastery',
      'monuments': 'monument',
      'lakes': 'lake',
      'durbar sq.': 'durbar',
      'durbar squares': 'durbar',
      'durbar square': 'durbar',
      // Nepali equivalents map to same slugs if needed
    };
    return map[s] ?? s.replaceAll(RegExp(r's$'), ''); // strip trailing 's' as fallback
  }

  // Backwards compatibility getter (unfiltered)
  List<HeritageSite> get featuredSites => getFeaturedSites();

  /// Advanced search with category and query
  Future<void> search({String? query, String? category}) async {
    // Update local state if provided
    if (query != null) _currentQuery = query;
    if (category != null) _currentCategory = category;

    // Reset debounce timer
    _debounceTimer?.cancel();

    // Start loading state immediately to show progress
    _isLoading = true;
    notifyListeners();

    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      await fetchSites(
        query: _currentQuery.isEmpty ? null : _currentQuery,
        category: _currentCategory == 'All' ? null : _mapCategory(_currentCategory),
      );
    });
  }

  String _mapCategory(String category) {
    switch (category) {
      case 'Temples': return 'temple';
      case 'Durbar Sq.': return 'durbar';
      case 'Stupas': return 'stupa';
      case 'Monasteries': return 'monastery';  // NOTE: no 'monastery' slug in backend
      default: return category.toLowerCase();
    }
  }

  /// Simplified Tag-Based Search Method
  Future<void> fetchSites({
    String? query,
    String? category,
    String? district,
    String? province,
    String sortBy = 'name',
    bool forceRemote = false,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Respect auto-sync setting (only skip for background refresh, not user-initiated search)
    final canSync = forceRemote || query != null || category != null
        ? true
        : await (autoSyncProvider?.shouldSync() ?? Future.value(true));

    if (!canSync) {
      // Serve from local cache only
      final cached = await repository.getHeritageSites();
      _sites = cached;
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      _sites = await repository.getHeritageSites(
        query: query,
        category: category,
        district: district,
        sortBy: sortBy,
      );
      debugPrint('fetchSites OK: ${_sites.length} sites');
      // Districts are now part of site tags, but if a master list is needed,
      // we can extract them from the site list or keep the API call.
      if (_districts.isEmpty) {
        await fetchDistricts();
      }
    } catch (e, st) {
      debugPrint('fetchSites ERROR: $e\n$st');
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createSite(HeritageSite site) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final newSite = await repository.createHeritageSite(site);
      _sites.insert(0, newSite);
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> isSiteDownloaded(String id) async {
    try {
      return await repository.isSiteDownloaded(id);
    } catch (_) {
      return false;
    }
  }

  Future<void> downloadSite(HeritageSite site) async {
    await repository.downloadSite(site);
  }

  Future<HeritageSite?> fetchSiteDetail(String slug) async {
    try {
      return await repository.getSiteDetail(slug);
    } catch (e) {
      debugPrint('fetchSiteDetail ERROR: $e');
      return null;
    }
  }

  Future<void> fetchDistricts() async {
    try {
      final response = await repository.getDistricts();
      _districts = response;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to fetch districts: $e');
    }
  }

  Future<void> searchSites(String query) async {
    if (query.isEmpty) {
      await fetchSites();
      return;
    }
    // Simple keyword search
    await fetchSites(query: query);
  }
}







