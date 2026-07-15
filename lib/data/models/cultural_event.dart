import 'package:equatable/equatable.dart';

class CulturalEvent extends Equatable {
  final String id;
  final String? siteId;
  final String title;
  final String titleNepali;
  final String eventType;
  final String description;
  final String descriptionNepali;
  final String shortDescription;
  final String imageUrl;
  final List<String> gallery;
  final String color;
  final DateTime startDate;
  final DateTime endDate;
  /// Local (Asia/Kathmandu) wall-clock times, "HH:MM" or null. Kept as strings
  /// rather than DateTime because the backend stores a time-of-day with no date.
  final String? startTime;
  final String? endTime;
  final double latitude;
  final double longitude;
  final String locationName;
  final bool isActive;
  final String priority;
  final int rsvpCount;
  final int? capacity;
  final int? seatsRemaining;
  final bool isFull;

  const CulturalEvent({
    required this.id,
    this.siteId,
    required this.title,
    required this.titleNepali,
    required this.eventType,
    required this.description,
    required this.descriptionNepali,
    this.shortDescription = '',
    this.imageUrl = '',
    this.gallery = const [],
    this.color = '',
    required this.startDate,
    required this.endDate,
    this.startTime,
    this.endTime,
    required this.latitude,
    required this.longitude,
    required this.locationName,
    this.isActive = true,
    this.priority = 'normal',
    this.rsvpCount = 0,
    this.capacity,
    this.seatsRemaining,
    this.isFull = false,
  });

  /// A human label for the event time, e.g. "10:00 AM – 4:00 PM", "10:00 AM",
  /// or null when no start time is set (an all-day event).
  String? get timeLabel {
    final start = _fmt(startTime);
    if (start == null) return null;
    final end = _fmt(endTime);
    return end == null ? start : '$start – $end';
  }

  /// "HH:MM[:SS]" (24-h) → "H:MM AM/PM". Returns null for null/blank input.
  static String? _fmt(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final parts = raw.split(':');
    final h = int.tryParse(parts[0]);
    final m = parts.length > 1 ? int.tryParse(parts[1]) : 0;
    if (h == null || m == null) return null;
    final period = h < 12 ? 'AM' : 'PM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:${m.toString().padLeft(2, '0')} $period';
  }

  @override
  List<Object?> get props => [
        id,
        siteId,
        title,
        titleNepali,
        eventType,
        description,
        descriptionNepali,
        shortDescription,
        imageUrl,
        gallery,
        color,
        startDate,
        endDate,
        startTime,
        endTime,
        latitude,
        longitude,
        locationName,
        isActive,
        priority,
        rsvpCount,
        capacity,
        seatsRemaining,
        isFull,
      ];
}







