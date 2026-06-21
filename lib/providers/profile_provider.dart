import 'package:flutter/material.dart';
import 'package:sampada/core/database/database_helper.dart';
import 'package:sampada/core/network/api_client.dart';
import 'package:sampada/core/network/api_endpoints.dart';
import 'package:sampada/data/models/heritage_site_model.dart';
import 'package:sqflite/sqflite.dart';

class ProfileProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper;
  final ApiClient? _apiClient;
  final String? _userId;

  int _visitHistoryCount = 0;
  int _bookmarksCount = 0;
  int _downloadsCount = 0;

  List<HeritageSiteModel> _visitHistory = [];
  List<HeritageSiteModel> _bookmarks = [];
  final List<Map<String, dynamic>> _downloads = [];

  bool _isLoading = false;
  double _cacheSizeMB = 0.0;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  ProfileProvider(this._dbHelper, this._apiClient, this._userId) {
    if (_userId != null) {
      fetchStats();
      calculateCacheSize();
    }
  }

  int get visitHistoryCount => _visitHistoryCount;
  int get bookmarksCount => _bookmarksCount;
  int get downloadsCount => _downloadsCount;

  List<HeritageSiteModel> get visitHistory => _visitHistory;
  List<HeritageSiteModel> get bookmarks => _bookmarks;
  List<Map<String, dynamic>> get downloads => _downloads;
  bool get isLoading => _isLoading;
  double get cacheSizeMB => _cacheSizeMB;

  double get totalDownloadSizeMB {
    double total = 0;
    for (var download in _downloads) {
      total += (download['download_size'] ?? 0).toDouble();
    }
    return total;
  }

  Future<void> calculateCacheSize() async {
    try {
      final db = await _dbHelper.database;
      final siteResult = await db.rawQuery('SELECT COUNT(*) as count FROM local_heritage_sites');
      final eventResult = await db.rawQuery('SELECT COUNT(*) as count FROM local_events');

      final siteCount = Sqflite.firstIntValue(siteResult) ?? 0;
      final eventCount = Sqflite.firstIntValue(eventResult) ?? 0;

      _cacheSizeMB = (siteCount * 0.1) + (eventCount * 0.05);
      notifyListeners();
    } catch (e) {
      debugPrint('Error calculating cache size: $e');
    }
  }

  Future<void> clearLocalCache() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _dbHelper.clearContentCache();
      _cacheSizeMB = 0.0;
      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchStats() async {
    if (_userId == null || _apiClient == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final stats = await _apiClient.get(ApiEndpoints.userMe);
      
      _visitHistoryCount = stats['visited_count'] ?? 0;
      _bookmarksCount = stats['bookmarks_count'] ?? 0;
      _downloadsCount = stats['downloads_count'] ?? 0;

      await Future.wait([
        fetchBookmarks(),
        fetchVisits(),
      ]);

    } catch (e) {
      debugPrint('Error fetching stats from backend: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchBookmarks() async {
    if (_apiClient == null) return;
    try {
      final data = await _apiClient.get(ApiEndpoints.bookmarks);
      final List list = data is List ? data : (data['results'] ?? []);
      _bookmarks = list
          .map((item) => HeritageSiteModel.fromJson(item['site_details']))
          .toList();
      _bookmarksCount = _bookmarks.length;
    } catch (e) {
      debugPrint('Error fetching bookmarks: $e');
    }
  }

  Future<void> fetchVisits() async {
    if (_apiClient == null) return;
    try {
      final data = await _apiClient.get(ApiEndpoints.visits);
      final List list = data is List ? data : (data['results'] ?? []);
      _visitHistory = list
          .map((item) => HeritageSiteModel.fromJson(item['site_details']))
          .toList();
      _visitHistoryCount = _visitHistory.length;
    } catch (e) {
      debugPrint('Error fetching visits: $e');
    }
  }

  Future<void> fetchDownloads() async {
    _downloadsCount = 0;
  }

  Future<void> toggleBookmark(String siteId) async {
    if (_apiClient == null) return;
    try {
      final isBookmarked = _bookmarks.any((s) => s.id == siteId);
      if (isBookmarked) {
        await _apiClient.delete('${ApiEndpoints.bookmarks}$siteId/');
      } else {
        await _apiClient.post(ApiEndpoints.bookmarks, data: {'site': siteId});
      }
      await fetchStats();
    } catch (e) {
      debugPrint('Error toggling bookmark: $e');
    }
  }

  Future<void> logVisit(String siteId) async {
    if (_apiClient == null) return;
    try {
      await _apiClient.post(ApiEndpoints.visits, data: {'site': siteId});
      await fetchStats();
    } catch (e) {
      debugPrint('Error logging visit: $e');
    }
  }

  // Compatibility methods for UI
  Future<void> fetchVisitHistory() => fetchVisits();
  Future<void> clearVisitHistory() async {
    // Backend doesn't have clear history yet, but we can reset local state
    _visitHistory = [];
    _visitHistoryCount = 0;
    notifyListeners();
  }
  Future<void> addToVisitHistory(String siteId) => logVisit(siteId);
  Future<bool> isBookmarked(String siteId) async {
    return _bookmarks.any((s) => s.id == siteId);
  }
}
