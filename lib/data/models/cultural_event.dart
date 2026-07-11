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
  final double latitude;
  final double longitude;
  final String locationName;
  final bool isActive;
  final String priority;
  final int rsvpCount;

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
    required this.latitude,
    required this.longitude,
    required this.locationName,
    this.isActive = true,
    this.priority = 'normal',
    this.rsvpCount = 0,
  });

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
        latitude,
        longitude,
        locationName,
        isActive,
        priority,
        rsvpCount,
      ];
}







