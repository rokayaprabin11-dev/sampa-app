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

  /// Returns events happening within the next 30 days and ordered by proximity.
  /// Events that have already ended are automatically excluded.
  List<CulturalEvent> get nearbyEvents {
    if (_events.isEmpty) return [];

    final now = DateTime.now();
    final thirtyDaysFromNow = now.add(const Duration(days: 30));

    // 1. Filter events happening soon or currently active, but NOT already ended
    final upcomingEvents = _events.where((e) {
      // Event is currently active or starts within the next 30 days
      bool isRelevant = (e.startDate.isAfter(now) && e.startDate.isBefore(thirtyDaysFromNow)) ||
             (e.startDate.isBefore(now) && e.endDate.isAfter(now));
      
      // Ensure the event hasn't already ended (end date is in the future)
      bool hasNotEnded = e.endDate.isAfter(now);
      
      return isRelevant && hasNotEnded;
    }).toList();

    if (upcomingEvents.isEmpty) return [];

    // 2. Score by proximity (events without coordinates sort last).
    final List<Map<String, dynamic>> scoredEvents = upcomingEvents.map((event) {
      final distance =
          GeoDistance.kmTo(_userLat, _userLng, event.latitude, event.longitude);
      return {'event': event, 'distance': distance ?? double.infinity};
    }).toList();

    // 3. Sort by distance ascending
    scoredEvents.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));

    return scoredEvents.map((e) => e['event'] as CulturalEvent).toList();
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







