import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nepali_utils/nepali_utils.dart';
import 'package:sampada/core/services/location_service.dart';
import 'package:sampada/core/utils/geo_distance.dart';
import 'package:sampada/data/models/cultural_event.dart';
import 'package:sampada/data/repositories/event_repository.dart';

/// Shared day-bucket classification used by both `tagsFor` and
/// `_freshnessScore` so their notion of "starts today"/"this weekend" can't
/// drift apart.
enum _DayBucket { live, today, tomorrow, thisWeekend, later }

/// Context-aware score weights for `nearbyEvents` ranking. See `_weightsFor`.
class _Weights {
  final double distance;
  final double priority;
  final double popularity;
  final double freshness;
  const _Weights({
    required this.distance,
    required this.priority,
    required this.popularity,
    required this.freshness,
  });
}

class CalendarDay {
  final int bsDay;
  final int adDay;
  final bool isCurrentMonth;
  final bool hasEvent;
  final bool isToday;
  final Color? eventColor; // admin-set dot color; null → use default
  final List<CulturalEvent> events; // events falling on this day (for the popover)

  CalendarDay({
    required this.bsDay,
    required this.adDay,
    this.isCurrentMonth = true,
    this.hasEvent = false,
    this.isToday = false,
    this.eventColor,
    this.events = const [],
  });
}

/// Parses a '#RRGGBB' / '#AARRGGBB' hex string into a [Color]; null if invalid.
Color? parseHexColor(String hex) {
  var h = hex.trim().replaceAll('#', '');
  if (h.isEmpty) return null;
  if (h.length == 6) h = 'FF$h';
  if (h.length != 8) return null;
  final v = int.tryParse(h, radix: 16);
  return v == null ? null : Color(v);
}

class EventProvider with ChangeNotifier {
  final EventRepository _repository;
  List<CulturalEvent> _events = [];
  bool _isLoading = false;
  String? _error;

  // Events beginning in the next 7 days, fetched with an explicit AD date
  // window so the "Current Cultural Events" list is anchored to today rather
  // than to whichever BS month the calendar is currently parked on.
  static const int _startingSoonWindowDays = 7;
  List<CulturalEvent> _startingSoonEvents = [];
  bool _isLoadingStartingSoon = false;
  String? _startingSoonError;
  bool get isLoadingStartingSoon => _isLoadingStartingSoon;
  String? get startingSoonError => _startingSoonError;

  // Separate from `_events` (which is BS-month-scoped for the calendar view).
  // Populated by loadUpcomingEvents() from the backend's date-ranged
  // /events/upcoming/ endpoint so the home screen's nearby-events section
  // isn't blind to events just past the current calendar month's boundary.
  List<CulturalEvent> _upcomingEvents = [];
  // event_type → count of this user's past "going" RSVPs, for the
  // personalization boost in nearbyEvents. Empty for anonymous users.
  Map<String, int> _affinityCounts = {};

  // User location for proximity ranking. Starts at Kathmandu as a fallback;
  // replaced by a real accuracy-gated GPS fix (cached 5 min) when available.
  double _userLat = 27.7172;
  double _userLng = 85.3240;
  bool _hasRealFix = false;
  // Speed (m/s) from the last GPS fix — used to detect a "traveling" user for
  // dynamic ranking weights. Null when no fix has landed yet.
  double? _lastSpeedMps;

  // Event ids the current user has bookmarked (loaded best-effort; empty for
  // anonymous users). Backs the bookmark icon on EventDetailScreen.
  Set<int> _bookmarkedEventIds = {};
  bool isEventBookmarked(int eventId) => _bookmarkedEventIds.contains(eventId);

  /// True once an accuracy-gated GPS fix replaced the Kathmandu fallback.
  /// Distance *labels* are only trustworthy then; ranking works either way.
  bool get hasRealFix => _hasRealFix;

  /// Distance user → event in km, or null when the event has no coordinates
  /// or the user's real position is still unknown (fallback would lie).
  double? distanceKmOf(CulturalEvent e) => _hasRealFix
      ? GeoDistance.kmTo(_userLat, _userLng, e.latitude, e.longitude)
      : null;

  /// Best-effort GPS refresh — keeps the Kathmandu fallback when the user
  /// denies permission or no trustworthy fix arrives in time.
  Future<void> _refreshUserLocation() async {
    final pos = await LocationService().getAccurateFix();
    if (pos == null) return;
    _lastSpeedMps = pos.speed;
    if (_hasRealFix && pos.latitude == _userLat && pos.longitude == _userLng) {
      return;
    }
    _userLat = pos.latitude;
    _userLng = pos.longitude;
    _hasRealFix = true;
    notifyListeners(); // re-rank nearbyEvents with the real position
  }

  // BS Months in Nepali
  final List<String> _bsMonths = ['बैशाख', 'जेठ', 'असार', 'साउन', 'भदौ', 'असोज', 'कार्तिक', 'मंसिर', 'पुष', 'माघ', 'फागुन', 'चैत'];
  int _selectedMonthIndex;
  late NepaliDateTime _currentBSDate;

  EventProvider({required EventRepository repository}) 
      : _repository = repository,
        _selectedMonthIndex = NepaliDateTime.now().month - 1 {
    _currentBSDate = NepaliDateTime.now();
  }

  List<CulturalEvent> get events => _events;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<String> get bsMonths => _bsMonths;
  int get selectedMonthIndex => _selectedMonthIndex;
  String get selectedMonthName => _bsMonths[_selectedMonthIndex];

  /// Events that *begin* within the next 7 days (today inclusive), earliest
  /// first. Backs the "Current Cultural Events" list. Fetched separately from
  /// `_events` so it stays anchored to today no matter which BS month the
  /// calendar above it is showing.
  List<CulturalEvent> get currentEvents {
    final today = _today();
    final until = today.add(const Duration(days: _startingSoonWindowDays));
    return _startingSoonEvents.where((e) {
      final start = _dateOnly(e.startDate);
      return !start.isBefore(today) && !start.isAfter(until);
    }).toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
  }

  /// Events whose start date falls inside the selected BS month, earliest
  /// first. Backs the "Events in This Month" list. `_events` also carries a
  /// 30-day lead-in (for calendar dots on festivals that began last month), so
  /// the range check here is what keeps this list to the month proper.
  List<CulturalEvent> get monthEvents {
    final (start: monthStart, end: monthEnd) = _selectedMonthAdRange;
    return _events.where((e) {
      final start = _dateOnly(e.startDate);
      return !start.isBefore(monthStart) && !start.isAfter(monthEnd);
    }).toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
  }

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _apiDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// AD [start, end] dates of the currently selected BS month.
  ({DateTime start, DateTime end}) get _selectedMonthAdRange {
    final firstDay = NepaliDateTime(_currentBSDate.year, _selectedMonthIndex + 1, 1);
    final lastDay = firstDay.add(Duration(days: firstDay.totalDays - 1));
    return (start: _dateOnly(firstDay.toDateTime()), end: _dateOnly(lastDay.toDateTime()));
  }

  /// All known events carrying real coordinates, deduped by id — backs the
  /// heritage map's event markers. Merges the upcoming-events pool and the
  /// calendar-month set so a map opened from either surface still has pins.
  List<CulturalEvent> get eventsWithLocation {
    final seen = <String>{};
    final out = <CulturalEvent>[];
    for (final e in [..._upcomingEvents, ..._events]) {
      if (!GeoDistance.hasCoords(e.latitude, e.longitude)) continue;
      if (seen.add(e.id)) out.add(e);
    }
    return out;
  }

  static const double _distanceCeilingKm = 50.0;
  static const int _popularityCeiling = 50;
  static const double _personalizationBoost = 0.05;
  // Above this speed the user is treated as "traveling" for ranking-weight
  // purposes (~9 km/h — brisk walk/cycling, not just GPS jitter while still).
  static const double _travelingSpeedMps = 2.5;

  /// Shared day-bucket classification so `tagsFor` and `_freshnessScore`
  /// can't drift apart on what counts as "starts today"/"this weekend".
  _DayBucket _dayBucketOf(CulturalEvent e, DateTime now) {
    final isActive = e.startDate.isBefore(now) && e.endDate.isAfter(now);
    if (isActive) return _DayBucket.live;

    final startDay = DateTime(e.startDate.year, e.startDate.month, e.startDate.day);
    final today = DateTime(now.year, now.month, now.day);
    final daysAway = startDay.difference(today).inDays;
    if (daysAway == 0) return _DayBucket.today;
    if (daysAway == 1) return _DayBucket.tomorrow;
    if (daysAway >= 0 && daysAway <= 3 &&
        (startDay.weekday == DateTime.friday ||
            startDay.weekday == DateTime.saturday ||
            startDay.weekday == DateTime.sunday)) {
      return _DayBucket.thisWeekend;
    }
    return _DayBucket.later;
  }

  double _priorityScore(CulturalEvent e) {
    switch (e.priority) {
      case 'high':
        return 1.0;
      case 'low':
        return 0.0;
      default:
        return 0.5;
    }
  }

  double _freshnessScore(CulturalEvent e, DateTime now) {
    switch (_dayBucketOf(e, now)) {
      case _DayBucket.live:
        return 1.0;
      case _DayBucket.today:
        return 0.95;
      case _DayBucket.tomorrow:
        return 0.85;
      case _DayBucket.thisWeekend:
        return 0.75;
      case _DayBucket.later:
        final daysUntilStart = e.startDate.difference(now).inHours / 24.0;
        return (1 - daysUntilStart / 30).clamp(0.0, 1.0);
    }
  }

  double _popularityScore(CulturalEvent e) =>
      (e.rsvpCount / _popularityCeiling).clamp(0.0, 1.0);

  /// Context-aware score weights — replaces the old static two-branch split.
  /// No GPS fix → distance contributes 0% (same effective behavior as
  /// before, just expressed as one code path). A fast-moving user shifts
  /// weight toward distance; an imminent high-priority event in the pool
  /// (e.g. a major festival happening today/tomorrow) shifts weight toward
  /// priority.
  _Weights _weightsFor({
    required bool hasFix,
    required bool isTraveling,
    required bool hasImminentHighPriority,
  }) {
    if (!hasFix) {
      return const _Weights(distance: 0, priority: 0.40, popularity: 0.25, freshness: 0.35);
    }
    if (isTraveling) {
      return const _Weights(distance: 0.55, priority: 0.20, popularity: 0.15, freshness: 0.10);
    }
    if (hasImminentHighPriority) {
      return const _Weights(distance: 0.30, priority: 0.35, popularity: 0.20, freshness: 0.15);
    }
    return const _Weights(distance: 0.40, priority: 0.25, popularity: 0.20, freshness: 0.15);
  }

  double _scoreOf(CulturalEvent e, DateTime now, _Weights weights) {
    final priority = _priorityScore(e);
    final freshness = _freshnessScore(e, now);
    final popularity = _popularityScore(e);

    double distanceScore = 0.0;
    if (weights.distance > 0) {
      final distanceKm =
          GeoDistance.kmTo(_userLat, _userLng, e.latitude, e.longitude);
      distanceScore = distanceKm == null
          ? 0.0
          : (1 - (distanceKm.clamp(0.0, _distanceCeilingKm)) / _distanceCeilingKm);
    }

    double score = weights.distance * distanceScore +
        weights.priority * priority +
        weights.popularity * popularity +
        weights.freshness * freshness;

    if ((_affinityCounts[e.eventType] ?? 0) > 0) {
      score += _personalizationBoost;
    }
    return score;
  }

  /// Returns upcoming/active events (next 30 days, not yet ended) ranked by a
  /// weighted score of distance, priority, popularity and freshness — plus a
  /// small personalization boost from the user's past RSVP history — with a
  /// category-diversity pass so the top results aren't all the same event_type.
  List<CulturalEvent> get nearbyEvents {
    if (_upcomingEvents.isEmpty) return [];

    final now = DateTime.now();
    final thirtyDaysFromNow = now.add(const Duration(days: 30));

    final eligible = _upcomingEvents.where((e) {
      final isRelevant = (e.startDate.isAfter(now) && e.startDate.isBefore(thirtyDaysFromNow)) ||
          (e.startDate.isBefore(now) && e.endDate.isAfter(now));
      final hasNotEnded = e.endDate.isAfter(now);
      return isRelevant && hasNotEnded;
    }).toList();

    if (eligible.isEmpty) return [];

    final isTraveling = (_lastSpeedMps ?? 0) > _travelingSpeedMps;
    final hasImminentHighPriority = eligible.any((e) =>
        e.priority == 'high' &&
        const {_DayBucket.live, _DayBucket.today, _DayBucket.tomorrow}
            .contains(_dayBucketOf(e, now)));
    final weights = _weightsFor(
      hasFix: _hasRealFix,
      isTraveling: isTraveling,
      hasImminentHighPriority: hasImminentHighPriority,
    );

    final ranked = eligible.toList()
      ..sort((a, b) => _scoreOf(b, now, weights).compareTo(_scoreOf(a, now, weights)));

    // Diversity pass: prefer the next-best-scoring event whose eventType
    // differs from what's already picked, falling back to strict score
    // order if every remaining candidate shares a type with a picked one.
    final result = <CulturalEvent>[];
    final usedTypes = <String>{};
    final remaining = List<CulturalEvent>.from(ranked);
    while (remaining.isNotEmpty) {
      var pickIndex = remaining.indexWhere((e) => !usedTypes.contains(e.eventType));
      if (pickIndex == -1) pickIndex = 0;
      final picked = remaining.removeAt(pickIndex);
      usedTypes.add(picked.eventType);
      result.add(picked);
    }
    return result;
  }

  /// Explain-tags for [e], capped to 2, in priority order: live/imminent,
  /// editor's pick, popular, distance.
  List<String> tagsFor(CulturalEvent e) {
    final now = DateTime.now();
    final tags = <String>[];

    switch (_dayBucketOf(e, now)) {
      case _DayBucket.live:
        tags.add('🔴 Live now');
        break;
      case _DayBucket.today:
        tags.add('🎉 Starts today');
        break;
      case _DayBucket.tomorrow:
        tags.add('🎉 Starts tomorrow');
        break;
      case _DayBucket.thisWeekend:
      case _DayBucket.later:
        break;
    }

    if (e.priority == 'high') tags.add("⭐ Editor's Pick");
    if (tags.length < 2 && e.rsvpCount >= 10) tags.add('🔥 Popular');

    // The 📍 distance tag isn't included here — it needs a BuildContext
    // (GeoDistance.label) and is already rendered separately by the caller
    // via distanceKmOf() into EventCard's `distance` prop.
    return tags.take(2).toList();
  }

  /// All loaded events whose [startDate, endDate] range (AD, date-only)
  /// covers [cellAd].
  List<CulturalEvent> _eventsOn(DateTime cellAd) {
    return _events.where((e) {
      final start = DateTime(e.startDate.year, e.startDate.month, e.startDate.day);
      final end = DateTime(e.endDate.year, e.endDate.month, e.endDate.day);
      return !cellAd.isBefore(start) && !cellAd.isAfter(end);
    }).toList();
  }

  // Dynamic calendar data using nepali_utils
  List<CalendarDay> get calendarDays {
    List<CalendarDay> days = [];
    
    // Create a date for the first day of the selected month
    NepaliDateTime firstDayOfMonth = NepaliDateTime(_currentBSDate.year, _selectedMonthIndex + 1, 1);
    
    // Get the weekday of the first day (1 = Monday, 7 = Sunday)
    // Nepali Calendar weekday: 1 = Sunday, 7 = Saturday
    int firstWeekday = firstDayOfMonth.weekday; // 1 (Sunday) to 7 (Saturday)
    
    // Calculate days from previous month to fill the first row
    int prevMonthDaysCount = firstWeekday - 1;
    NepaliDateTime prevMonthLastDay = firstDayOfMonth.subtract(const Duration(days: 1));
    
    for (int i = prevMonthDaysCount - 1; i >= 0; i--) {
      NepaliDateTime date = prevMonthLastDay.subtract(Duration(days: i));
      days.add(CalendarDay(
        bsDay: date.day,
        adDay: date.toDateTime().day,
        isCurrentMonth: false,
      ));
    }
    
    // Current month days
    int daysInMonth = firstDayOfMonth.totalDays;
    NepaliDateTime today = NepaliDateTime.now();
    
    for (int i = 1; i <= daysInMonth; i++) {
      NepaliDateTime date = NepaliDateTime(firstDayOfMonth.year, firstDayOfMonth.month, i);
      final ad = date.toDateTime();
      final cellAd = DateTime(ad.year, ad.month, ad.day);

      // Events whose date range covers this cell's AD date.
      final dayEvents = _eventsOn(cellAd);

      days.add(CalendarDay(
        bsDay: i,
        adDay: ad.day,
        isToday: date.year == today.year && date.month == today.month && date.day == today.day,
        hasEvent: dayEvents.isNotEmpty,
        eventColor: dayEvents.isNotEmpty ? parseHexColor(dayEvents.first.color) : null,
        events: dayEvents,
      ));
    }
    
    return days;
  }

  String get calendarHeaderTitle {
    NepaliDateTime firstDay = NepaliDateTime(_currentBSDate.year, _selectedMonthIndex + 1, 1);
    int totalDaysInMonth = firstDay.totalDays;
    NepaliDateTime lastDay = firstDay.add(Duration(days: totalDaysInMonth - 1));
    
    DateTime adStartDate = firstDay.toDateTime();
    DateTime adEndDate = lastDay.toDateTime();
    
    String bsYear = NepaliUnicode.convert(firstDay.year.toString());
    
    String adMonth;
    if (adStartDate.month == adEndDate.month) {
      adMonth = _getEnglishMonth(adStartDate.month);
    } else {
      adMonth = "${_getEnglishMonth(adStartDate.month)} / ${_getEnglishMonth(adEndDate.month)}";
    }

    String adYear;
    if (adStartDate.year == adEndDate.year) {
      adYear = adStartDate.year.toString();
    } else {
      adYear = "${adStartDate.year} / ${adEndDate.year}";
    }
    
    return "$selectedMonthName - $bsYear BS / $adMonth - $adYear AD";
  }

  String _getEnglishMonth(int month) {
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return months[month - 1];
  }

  /// Loads the events of the selected BS month into `_events` — the source for
  /// both the calendar grid and the "Events in This Month" list.
  Future<void> loadEvents({int? districtId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Kick off a location refresh in parallel — nearbyEvents re-ranks via
    // notifyListeners() when a real fix lands. Never blocks event loading.
    unawaited(_refreshUserLocation());

    final (start: monthStart, end: monthEnd) = _selectedMonthAdRange;
    try {
      _events = await _repository.getEvents(
        // Lead-in: a multi-day festival that began late last month still has to
        // light up its cells in this month's grid, so ask for it too. The
        // `monthEvents` getter trims the lead-in back off for the list.
        dateFrom: _apiDate(monthStart.subtract(const Duration(days: 30))),
        dateTo: _apiDate(monthEnd),
        districtId: districtId,
      );
    } catch (e) {
      _error = 'Failed to load events: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Loads events beginning between today and 7 days out, for `currentEvents`.
  Future<void> loadStartingSoonEvents() async {
    _isLoadingStartingSoon = true;
    _startingSoonError = null;
    notifyListeners();

    final today = _today();
    try {
      _startingSoonEvents = await _repository.getEvents(
        dateFrom: _apiDate(today),
        dateTo: _apiDate(today.add(const Duration(days: _startingSoonWindowDays))),
      );
    } catch (e) {
      _startingSoonError = 'Failed to load events: $e';
    } finally {
      _isLoadingStartingSoon = false;
      notifyListeners();
    }
  }

  static const List<double> _adaptiveRadiiKm = [10, 25, 50, 100];

  /// Loads candidates for the home screen's "Nearby Events" section. Gets a
  /// best-effort GPS fix first: with a real fix, escalates through
  /// `/events/nearby/` at increasing radii (10→25→50→100km) until at least 2
  /// candidates turn up; without a fix — or if even 100km turns up nothing
  /// (e.g. events with no coordinates set) — falls back to the nationwide
  /// `/events/upcoming/` list, same as before. Also best-effort loads blended
  /// RSVP/bookmark/view affinity and the user's bookmarked event ids.
  Future<void> loadUpcomingEvents() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final pos = await LocationService().getAccurateFix();
      if (pos != null) {
        _lastSpeedMps = pos.speed;
        _userLat = pos.latitude;
        _userLng = pos.longitude;
        _hasRealFix = true;
        _upcomingEvents = await _fetchWithAdaptiveRadius(pos.latitude, pos.longitude);
        if (_upcomingEvents.isEmpty) {
          _upcomingEvents = await _repository.getUpcomingEvents();
        }
      } else {
        _upcomingEvents = await _repository.getUpcomingEvents();
      }
      _affinityCounts = await _blendedAffinity();
      unawaited(loadBookmarkedEventIds());
    } catch (e) {
      _error = 'Failed to load upcoming events: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<CulturalEvent>> _fetchWithAdaptiveRadius(double lat, double lng) async {
    List<CulturalEvent> results = [];
    for (final radius in _adaptiveRadiiKm) {
      results = await _repository.getNearbyEvents(lat: lat, lng: lng, radiusKm: radius);
      if (results.length >= 2) return results;
    }
    return results;
  }

  /// RSVP (full weight) + bookmark (×0.7) + view (×0.3), blended into one
  /// event_type→count map for the personalization boost in `_scoreOf`.
  Future<Map<String, int>> _blendedAffinity() async {
    final rsvp = await _repository.getRsvpAffinity();
    final bookmark = await _repository.getBookmarkAffinity();
    final view = await _repository.getVisitAffinity();
    final merged = <String, double>{};
    rsvp.forEach((k, v) => merged[k] = (merged[k] ?? 0) + v);
    bookmark.forEach((k, v) => merged[k] = (merged[k] ?? 0) + v * 0.7);
    view.forEach((k, v) => merged[k] = (merged[k] ?? 0) + v * 0.3);
    return merged.map((k, v) => MapEntry(k, v.round()));
  }

  Future<void> loadBookmarkedEventIds() async {
    try {
      final ids = await _repository.getBookmarkedEventIds();
      _bookmarkedEventIds = ids.toSet();
      notifyListeners();
    } catch (_) {
      // Anonymous user or transient error — bookmark state just stays empty.
    }
  }

  Future<void> toggleEventBookmark(int eventId) async {
    final wasBookmarked = isEventBookmarked(eventId);
    if (wasBookmarked) {
      _bookmarkedEventIds.remove(eventId);
    } else {
      _bookmarkedEventIds.add(eventId);
    }
    notifyListeners();
    try {
      await _repository.toggleBookmark(eventId, currentlyBookmarked: wasBookmarked);
    } catch (e) {
      if (wasBookmarked) {
        _bookmarkedEventIds.add(eventId);
      } else {
        _bookmarkedEventIds.remove(eventId);
      }
      notifyListeners();
      debugPrint('Error toggling event bookmark: $e');
    }
  }

  Future<void> recordEventVisit(int eventId) async {
    try {
      await _repository.recordVisit(eventId);
    } catch (e) {
      debugPrint('Error recording event visit: $e');
    }
  }

  Future<void> loadNearbyEvents({required double lat, required double lng, double radiusKm = 10}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _events = await _repository.getNearbyEvents(
        lat: lat,
        lng: lng,
        radiusKm: radiusKm,
      );
    } catch (e) {
      _error = 'Failed to load nearby events: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setSelectedMonthIndex(int index) {
    _selectedMonthIndex = index;
    _currentBSDate = NepaliDateTime(_currentBSDate.year, index + 1, 1);
    loadEvents();
  }

  void nextMonth() => _goToMonth(_currentBSDate.year, _currentBSDate.month + 1);

  void previousMonth() => _goToMonth(_currentBSDate.year, _currentBSDate.month - 1);

  /// NepaliDateTime does not normalize out-of-range months: month 13 or 0 blows
  /// up later in totalDays/weekday, so roll the year over here instead.
  void _goToMonth(int year, int month) {
    if (month > 12) {
      year += 1;
      month = 1;
    } else if (month < 1) {
      year -= 1;
      month = 12;
    }
    _currentBSDate = NepaliDateTime(year, month, 1);
    _selectedMonthIndex = month - 1;
    loadEvents();
  }

  void resetToToday() {
    final now = NepaliDateTime.now();
    _currentBSDate = now;
    _selectedMonthIndex = now.month - 1;
    loadEvents();
  }
}







