import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sampada/data/models/heritage_site.dart';
import 'package:sampada/data/repositories/heritage_repository.dart';
import 'package:sampada/data/models/district_model.dart';

class HeritageProvider with ChangeNotifier {
  final HeritageRepository repository;

  List<HeritageSite> _sites = [];
  List<DistrictModel> _districts = [];
  bool _isLoading = false;
  String? _error;

  // Search state
  String _currentQuery = '';
  String _currentCategory = 'All';
  Timer? _debounceTimer;

  HeritageProvider({required this.repository});

  List<HeritageSite> get sites => _sites;
  List<DistrictModel> get districts => _districts;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get currentQuery => _currentQuery;
  String get currentCategory => _currentCategory;

  List<HeritageSite> getFeaturedSites({String? category}) {
    if (_sites.isEmpty) return [];

    final filteredList = (category == null || category.isEmpty || category.toLowerCase() == 'all')
        ? _sites
        : _sites.where((s) => s.category.toLowerCase() == category.toLowerCase()).toList();

    // Sort by rating or newest for "Featured" in simplified mode
    final sortedList = List<HeritageSite>.from(filteredList)
      ..sort((a, b) => b.rating.compareTo(a.rating));

    return sortedList.take(6).toList();
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
      case 'Durbar Sq.': return 'palace';
      case 'Stupas': return 'stupa';
      case 'Monasteries': return 'monastery';
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
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _sites = await repository.getHeritageSites(
        query: query,
        category: category,
        district: district,
        sortBy: sortBy,
      );
      // Districts are now part of site tags, but if a master list is needed,
      // we can extract them from the site list or keep the API call.
      if (_districts.isEmpty) {
        await fetchDistricts();
      }
    } catch (e) {
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







