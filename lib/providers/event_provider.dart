import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:nepali_utils/nepali_utils.dart';
import 'package:sampada/data/models/cultural_event.dart';
import 'package:sampada/data/repositories/event_repository.dart';

class CalendarDay {
  final int bsDay;
  final int adDay;
  final bool isCurrentMonth;
  final bool hasEvent;
  final bool isToday;

  CalendarDay({
    required this.bsDay,
    required this.adDay,
    this.isCurrentMonth = true,
    this.hasEvent = false,
    this.isToday = false,
  });
}

class EventProvider with ChangeNotifier {
  final EventRepository _repository;
  List<CulturalEvent> _events = [];
  bool _isLoading = false;
  String? _error;
  
  // Mock user location (Kathmandu area)
  final double _userLat = 27.7172;
  final double _userLng = 85.3240;

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

    // 2. Score by proximity
    final List<Map<String, dynamic>> scoredEvents = upcomingEvents.map((event) {
      final distance = _calculateDistance(_userLat, _userLng, event.latitude, event.longitude);
      return {'event': event, 'distance': distance};
    }).toList();

    // 3. Sort by distance ascending
    scoredEvents.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));

    return scoredEvents.map((e) => e['event'] as CulturalEvent).toList();
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double longitude2) {
    return math.sqrt(math.pow(lat2 - lat1, 2) + math.pow(longitude2 - lon1, 2)) * 111; // Approx km
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
      
      // Check if there's an event on this day
      // (This is a simplified check for demo purposes)
      bool hasEvent = _events.any((e) => 
        e.startDate.day == date.toDateTime().day && 
        e.startDate.month == date.toDateTime().month
      );

      days.add(CalendarDay(
        bsDay: i,
        adDay: date.toDateTime().day,
        isToday: date.year == today.year && date.month == today.month && date.day == today.day,
        hasEvent: hasEvent,
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







