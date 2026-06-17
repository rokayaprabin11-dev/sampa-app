import 'package:flutter/foundation.dart';

class ApiEndpoints {
  ApiEndpoints._();

  // Injected at build time via --dart-define=API_BASE_URL=https://...
  // Falls back to local dev URLs when the constant is not provided.
  static const String _prodUrl = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_prodUrl.isNotEmpty) return _prodUrl;
    if (kIsWeb) return 'http://localhost:8000/api/v1';
    // 10.0.2.2 reaches the host machine from an Android emulator
    return 'http://10.0.2.2:8000/api/v1';
  }

  // --- Auth Endpoints ---
  static const String sync = '/auth/sync/';
  static const String tokenRefresh = '/auth/refresh/';
  static const String me = '/auth/me/';
  static const String profile = '/auth/profile/';
  static const String account = '/auth/account/';

  // --- Users Endpoints ---
  static const String userMe = '/users/me/';
  static const String bookmarks = '/users/me/bookmarks/';
  static const String visits = '/users/me/visits/';
  static const String feed = '/users/me/feed/';
  static const String interests = '/users/me/interests/';

  // --- Heritage Endpoints ---
  static const String heritageSites = '/heritage/sites/';
  static const String heritageSitesCreate = '/heritage/sites/create/';
  static const String heritageNearby = '/heritage/sites/nearby/';
  static const String heritageSearch = '/heritage/sites/search/';
  static const String districts = '/heritage/districts/';
  static const String uploadSignature = '/heritage/upload-signature/';

  // --- Events Endpoints ---
  static const String events = '/events/';
  static const String eventsNearby = '/events/nearby/';
  static const String eventsCalendar = '/events/calendar/';

  // --- Notifications ---
  static const String notifications = '/notifications/';
  static const String markRead = '/notifications/mark-read/';
  static const String fcmToken = '/auth/fcm-token/';
  static const String geofenceLocation = '/notifications/geofence/location/';
  static const String geofenceNearby = '/notifications/geofence/nearby-sites/';

  // --- Offline ---
  static const String downloads = '/offline/downloads/';

  // --- Translation ---
  static const String translate = '/translate/';
  static const String translateLanguages = '/translate/languages/';

  // --- Guides ---
  static const String guides = '/guides/';
  static const String guideApply = '/guides/apply/';
  static const String guideMe = '/guides/me/';
  static const String guideAvailability = '/guides/me/availability/';
  static const String guideBookings = '/guides/me/bookings/';
  static String guideBook(int id) => '/guides/$id/book/';
}
