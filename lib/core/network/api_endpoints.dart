
class ApiEndpoints {
  ApiEndpoints._();

  // Injected at build time via --dart-define=API_BASE_URL=https://...
  // Falls back to local dev URLs when the constant is not provided.
  static const String _prodUrl = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_prodUrl.isNotEmpty) return _prodUrl;
    return 'https://sampada-backend-8svi.onrender.com/api/v1';
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
  static const String userPreferences = '/users/me/preferences/';

  // --- Heritage ---
  static const String heritageSites = '/heritage/sites/';
  static const String heritageSitesCreate = '/heritage/admin/sites/';
  static const String heritageNearby = '/heritage/sites/nearby/';
  static const String heritageFeatured = '/heritage/sites/featured/';
  static const String heritageSearch = '/heritage/search/';
  static const String heritageAutocomplete = '/heritage/autocomplete/';
  static const String heritageCategories = '/heritage/categories/';
  static const String districts = '/geo/districts/';
  static const String uploadSignature = '/heritage/upload-signature/';
  static String siteDetail(String slug) => '/heritage/sites/$slug/';
  static String siteBookmark(String slug) => '/heritage/sites/$slug/bookmark/';
  static String siteVisit(String slug) => '/heritage/sites/$slug/visit/';

  // --- Events ---
  static const String events = '/events/';
  static const String eventsUpcoming = '/events/upcoming/';
  static const String eventsNearby = '/events/nearby/';
  static const String eventsCategories = '/events/categories/';
  static const String eventsCalendar = '/events/calendar/';
  static const String eventsMyRsvpTypes = '/events/my-rsvp-types/';
  static String eventDetail(int id) => '/events/$id/';
  static String eventRsvp(int id) => '/events/$id/rsvp/';

  // --- Notifications ---
  static const String notifications = '/notifications/';
  static const String markRead = '/notifications/mark-read/';
  static const String readAll = '/notifications/read-all/';
  static String markOneRead(int id) => '/notifications/$id/read/';
  static const String geofenceCheck = '/notifications/geofence-check/';
  static const String adminSendNotification = '/notifications/admin/send/';
  static const String notificationPreferences = '/notifications/preferences/';
  static const String deviceRegister = '/notifications/devices/register/';
  static const String deviceUnregister = '/notifications/devices/unregister/';
  static const String notificationEvents = '/notifications/events/';

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
  static const String guidesNearby = '/guides/nearby/';
  static const String guideMe = '/guides/me/';
  static const String guideLocationUpdate = '/guides/me/location/';
  static const String guideApply = '/guides/apply/';
  static const String guideBookings = '/guides/bookings/';
  static String guideDetail(int id) => '/guides/$id/';
  static String guideAvailability(int id) => '/guides/$id/availability/';

  // --- Bookings ---
  static const String bookings = '/guides/bookings/';
  static const String guideIncomingBookings = '/guides/bookings/incoming/';
  static String bookingDetail(int id) => '/guides/bookings/$id/';
  static String bookingRespond(int id) => '/guides/bookings/$id/respond/';
  static String bookingReview(int id) => '/guides/bookings/$id/review/';

  // --- Offline Downloads ---
  static const String downloads = '/users/me/downloads/';

  static const String bookmarks = '/heritage/bookmarks/';
  static const String bookmarkToggle = '/heritage/bookmarks/toggle/';
  static const String visitsLog = '/heritage/visits/';
  static const String visits = '/heritage/visits/recent/';
}
