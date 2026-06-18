import 'package:flutter/foundation.dart';

class ApiEndpoints {
  ApiEndpoints._();

  // Injected at build time via --dart-define=API_BASE_URL=https://...
  // Falls back to local dev URLs when the constant is not provided.
  static const String _prodUrl = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_prodUrl.isNotEmpty) return _prodUrl;
    if (kIsWeb) return 'http://localhost:8000/api/v1';
    // For local emulator dev: --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
    return 'https://sampada-backend-1.onrender.com/api/v1';
  }

  // --- Auth ---
  static const String sync = '/auth/sync/';
  static const String tokenRefresh = '/auth/refresh/';
  static const String logout = '/auth/logout/';
  static const String me = '/auth/me/';
  static const String profile = '/auth/profile/';
  static const String account = '/auth/account/';
  static const String fcmToken = '/auth/fcm-token/';

  // --- Users ---
  static const String userMe = '/auth/me/';
  static const String userBookmarks = '/users/me/bookmarks/';
  static const String userHistory = '/users/me/history/';
  static const String userReviews = '/users/me/reviews/';
  static const String userPreferences = '/users/me/preferences/';

  // --- Heritage ---
  static const String heritageSites = '/heritage/sites/';
  static const String heritageSitesCreate = '/heritage/admin/sites/';
  static const String heritageNearby = '/heritage/sites/nearby/';
  static const String heritageFeatured = '/heritage/sites/featured/';
  static const String heritageSearch = '/heritage/search/';
  static const String districts = '/geo/districts/';
  static const String uploadSignature = '/heritage/upload-signature/';
  static String siteDetail(String slug) => '/heritage/sites/$slug/';
  static String siteReviews(String slug) => '/heritage/sites/$slug/reviews/';
  static String siteBookmark(String slug) => '/heritage/sites/$slug/bookmark/';
  static String siteVisit(String slug) => '/heritage/sites/$slug/visit/';

  // --- Events ---
  static const String events = '/events/';
  static const String eventsUpcoming = '/events/upcoming/';
  static const String eventsNearby = '/events/nearby/';
  static const String eventsCategories = '/events/categories/';
  static String eventDetail(int id) => '/events/$id/';
  static String eventRsvp(int id) => '/events/$id/rsvp/';

  // --- Notifications ---
  static const String notifications = '/notifications/';
  static const String markRead = '/notifications/mark-read/';
  static const String readAll = '/notifications/read-all/';
  static String markOneRead(int id) => '/notifications/$id/read/';
  static const String geofenceCheck = '/notifications/geofence-check/';

  // --- Location ---
  static const String locationUpdate = '/location/update/';
  static const String locationGeofences = '/location/geofences/';

  // --- Discovery ---
  static const String search = '/search/';
  static const String feed = '/feed/';
  static const String categories = '/categories/';
  static const String config = '/config/';
  static const String health = '/health/';

  // --- Translation ---
  static const String translate = '/translate/';
  static const String translateLanguages = '/translate/languages/';

  // --- Guides ---
  static const String guides = '/guides/';
  static String guideDetail(int id) => '/guides/$id/';
  static String guideAvailability(int id) => '/guides/$id/availability/';

  // --- Bookings ---
  static const String bookings = '/guides/bookings/';
  static String bookingDetail(int id) => '/guides/bookings/$id/';
  static String bookingReview(int id) => '/guides/bookings/$id/review/';

  // --- Legacy (kept for backward compat) ---
  static const String bookmarks = '/heritage/bookmarks/';
  static const String visits = '/heritage/visits/recent/';
}
