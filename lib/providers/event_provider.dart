import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nepali_utils/nepali_utils.dart';
import 'package:sampada/core/services/location_service.dart';
import 'package:sampada/core/utils/geo_distance.dart';
import 'package:sampada/data/models/cultural_event.dart';
import 'package:sampada/data/repositories/event_repository.dart';

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

  /// Up to 7 current/upcoming events, earliest first. Events whose end date has
  /// already passed are hidden. Used by the "Current Cultural Events" list.
  List<CulturalEvent> get currentEvents {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final list = _events.where((e) {
      final end = DateTime(e.endDate.year, e.endDate.month, e.endDate.day);
      return !end.isBefore(today); // keep events that haven't ended yet
    }).toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
    return list.take(7).toList();
  }

  static const double _distanceCeilingKm = 50.0;
  static const int _popularityCeiling = 50;
  static const double _personalizationBoost = 0.05;

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
    final isActive = e.startDate.isBefore(now) && e.endDate.isAfter(now);
    if (isActive) return 1.0;
    final daysUntilStart = e.startDate.difference(now).inHours / 24.0;
    return (1 - daysUntilStart / 30).clamp(0.0, 1.0);
  }

  double _popularityScore(CulturalEvent e) =>
      (e.rsvpCount / _popularityCeiling).clamp(0.0, 1.0);

  double _scoreOf(CulturalEvent e, DateTime now) {
    final priority = _priorityScore(e);
    final freshness = _freshnessScore(e, now);
    final popularity = _popularityScore(e);

    double score;
    if (_hasRealFix) {
      final distanceKm =
          GeoDistance.kmTo(_userLat, _userLng, e.latitude, e.longitude);
      final distanceScore = distanceKm == null
          ? 0.0
          : (1 - (distanceKm.clamp(0.0, _distanceCeilingKm)) / _distanceCeilingKm);
      score = 0.40 * distanceScore + 0.25 * priority + 0.20 * popularity + 0.15 * freshness;
    } else {
      // No trustworthy GPS fix — rank by priority/freshness/popularity only.
      // Never falls back to the Kathmandu placeholder coordinates for ranking.
      score = 0.40 * priority + 0.35 * freshness + 0.25 * popularity;
    }

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

    final ranked = eligible.toList()
      ..sort((a, b) => _scoreOf(b, now).compareTo(_scoreOf(a, now)));

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

    final isActive = e.startDate.isBefore(now) && e.endDate.isAfter(now);
    if (isActive) {
      tags.add('🔴 Live now');
    } else {
      final startDay = DateTime(e.startDate.year, e.startDate.month, e.startDate.day);
      final today = DateTime(now.year, now.month, now.day);
      final daysAway = startDay.difference(today).inDays;
      if (daysAway == 0) {
        tags.add('🎉 Starts today');
      } else if (daysAway == 1) {
        tags.add('🎉 Starts tomorrow');
      }
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

  Future<void> loadEvents({int? monthBs, int? districtId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Kick off a location refresh in parallel — nearbyEvents re-ranks via
    // notifyListeners() when a real fix lands. Never blocks event loading.
    unawaited(_refreshUserLocation());

    try {
      _events = await _repository.getEvents(
        monthBs: monthBs ?? _selectedMonthIndex + 1,
        districtId: districtId,
      );
    } catch (e) {
      _error = 'Failed to load events: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Loads events for the home screen's "Nearby Events" section from the
  /// backend's date-ranged /events/upcoming/ endpoint (separate from the
  /// BS-month-scoped `_events`/`loadEvents()` used by the calendar screen,
  /// so the 30-day nearbyEvents window is never short of data near a month
  /// boundary). Also best-effort loads the user's RSVP-affinity counts.
  Future<void> loadUpcomingEvents() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    unawaited(_refreshUserLocation());

    try {
      _upcomingEvents = await _repository.getUpcomingEvents();
      _affinityCounts = await _repository.getRsvpAffinity();
    } catch (e) {
      _error = 'Failed to load upcoming events: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
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
    loadEvents(monthBs: index + 1);
  }

  void nextMonth() {
    _currentBSDate = NepaliDateTime(_currentBSDate.year, _currentBSDate.month + 1, 1);
    _selectedMonthIndex = _currentBSDate.month - 1;
    loadEvents(monthBs: _selectedMonthIndex + 1);
  }

  void previousMonth() {
    _currentBSDate = NepaliDateTime(_currentBSDate.year, _currentBSDate.month - 1, 1);
    _selectedMonthIndex = _currentBSDate.month - 1;
    loadEvents(monthBs: _selectedMonthIndex + 1);
  }

  void resetToToday() {
    final now = NepaliDateTime.now();
    _currentBSDate = now;
    _selectedMonthIndex = now.month - 1;
    loadEvents();
  }
}







