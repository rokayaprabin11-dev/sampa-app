import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  // True when `_sites` came out of SQLite rather than the API — either because
  // auto-sync vetoed the network, or because the request failed and the
  // repository fell back. Drives the "Offline data" indicator.
  bool _isShowingCachedData = false;

  // Server-ranked featured-sites pool (scored, diversified, rotated, and —
  // when signed in — personalized by the backend). Category chip filtering
  // happens client-side over this pool; never re-sort it.
  List<HeritageSite> _featuredPool = [];
  bool _isFeaturedLoading = false;

  // Search state
  String _currentQuery = '';
  String _currentCategory = 'All';
  Timer? _debounceTimer;

  // Backend semantic-search state (separate from the full `_sites` catalogue).
  List<HeritageSite> _searchResults = [];
  bool _isSearching = false;
  String _activeSearch = '';
  String? _searchError;
  int _searchSeq = 0; // monotonic id — drops out-of-order (stale) responses

  static const int _maxQueryLen = 100;
  static const int _maxRecent = 8;
  static const String _recentKey = 'heritage_recent_searches';
  List<String> _recentSearches = [];

  HeritageProvider({required this.repository, this.autoSyncProvider});

  List<HeritageSite> get sites => _sites;
  List<DistrictModel> get districts => _districts;
  bool get isLoading => _isLoading;
  bool get isFeaturedLoading => _isFeaturedLoading;
  String? get error => _error;

  /// True while the visible site list is cached (offline) data.
  bool get isShowingCachedData => _isShowingCachedData;
  String get currentQuery => _currentQuery;
  String get currentCategory => _currentCategory;

  List<HeritageSite> get searchResults => _searchResults;
  bool get isSearching => _isSearching;
  String get activeSearch => _activeSearch;
  String? get searchError => _searchError;
  List<String> get recentSearches => List.unmodifiable(_recentSearches);

  /// Debounced full-text search against `/heritage/search/`. An empty query
  /// clears results so the caller falls back to showing the full catalogue.
  void onSearchChanged(String query) {
    // Clamp length so a pathological paste can't hit the backend / FTS.
    final q = query.trim();
    final clamped = q.length > _maxQueryLen ? q.substring(0, _maxQueryLen) : q;
    _debounceTimer?.cancel();
    _currentQuery = clamped;
    _searchError = null;
    if (clamped.isEmpty) {
      _activeSearch = '';
      _searchResults = [];
      _isSearching = false;
      _searchSeq++; // invalidate any in-flight response
      notifyListeners();
      return;
    }
    _isSearching = true;
    notifyListeners();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () => _runSearch(clamped));
  }

  Future<void> _runSearch(String query) async {
    final seq = ++_searchSeq; // this call's id
    _isSearching = true;
    _activeSearch = query;
    notifyListeners();
    try {
      final results = await repository.searchHeritageSites(query);
      if (seq != _searchSeq) return; // a newer query superseded this one — drop it
      _searchResults = results;
      _searchError = null;
    } catch (e) {
      if (seq != _searchSeq) return;
      debugPrint('heritage search failed: $e');
      _searchResults = []; // UI falls back to client-side filtering
      _searchError = 'Search is temporarily unavailable.';
    } finally {
      if (seq == _searchSeq) {
        _isSearching = false;
        notifyListeners();
      }
    }
  }

  // ── Recent searches (persisted) ───────────────────────────────────────────

  Future<void> loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _recentSearches = prefs.getStringList(_recentKey) ?? [];
      notifyListeners();
    } catch (_) {/* non-fatal */}
  }

  Future<void> addRecentSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    _recentSearches
      ..removeWhere((e) => e.toLowerCase() == q.toLowerCase())
      ..insert(0, q);
    if (_recentSearches.length > _maxRecent) {
      _recentSearches = _recentSearches.sublist(0, _maxRecent);
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_recentKey, _recentSearches);
    } catch (_) {/* non-fatal */}
  }

  Future<void> clearRecentSearches() async {
    _recentSearches = [];
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_recentKey);
    } catch (_) {/* non-fatal */}
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// Fetches the server-ranked featured pool (score + diversity + rotation +
  /// personalization all applied backend-side). Call once with no coords for
  /// a fast first paint, then again once a location fix resolves.
  Future<void> fetchFeaturedSites({double? lat, double? lng}) async {
    _isFeaturedLoading = _featuredPool.isEmpty;
    if (_isFeaturedLoading) notifyListeners();
    try {
      _featuredPool = await repository.getFeaturedSites(lat: lat, lng: lng);
    } catch (e) {
      debugPrint('fetchFeaturedSites failed: $e');
    } finally {
      _isFeaturedLoading = false;
      notifyListeners();
    }
  }

  /// Filters the already-ranked featured pool by category. Deliberately does
  /// NOT re-sort — the server has already applied score + diversity +
  /// rotation ordering, so filtering must preserve it.
  List<HeritageSite> getFeaturedSites({String? category}) {
    if (_featuredPool.isEmpty) return [];

    final slug = _slugify(category ?? '');
    if (slug.isEmpty || slug == 'all') return _featuredPool;
    return _featuredPool.where((s) => _slugify(s.category) == slug).toList();
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

    // Auto-sync gates *automatic* refreshes only. A user-initiated action — a
    // search, a category filter, or an explicit pull-to-refresh (forceRemote) —
    // always goes to the network: the user asked for fresh data by acting.
    final isUserInitiated = forceRemote || query != null || category != null;
    final canSync = isUserInitiated
        ? true
        : await (autoSyncProvider?.shouldSync() ?? Future.value(true));

    if (!canSync) {
      // Auto-sync vetoed the network. Read straight from SQLite — this must not
      // issue an HTTP request, which is why it goes through the cache-only API
      // rather than the remote-first getHeritageSites().
      final result = await repository.getCachedHeritageSites();
      _sites = result.sites;
      _isShowingCachedData = true;
      debugPrint('fetchSites: auto-sync off/unmet — served ${_sites.length} '
          'sites from CACHE, no network call');
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      final result = await repository.getHeritageSites(
        query: query,
        category: category,
        district: district,
        sortBy: sortBy,
      );
      _sites = result.sites;
      // The repository silently falls back to cache when the request fails, so
      // trust its reported source rather than assuming this was a live fetch.
      _isShowingCachedData = result.isFromCache;
      debugPrint('fetchSites OK: ${_sites.length} sites from '
          '${result.isFromCache ? 'CACHE (remote failed)' : 'REMOTE'}');
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







