import 'package:sampada/data/models/cultural_event.dart';

class CulturalEventModel extends CulturalEvent {
  const CulturalEventModel({
    required super.id,
    super.siteId,
    required super.title,
    required super.titleNepali,
    required super.eventType,
    required super.description,
    required super.descriptionNepali,
    super.shortDescription,
    super.imageUrl,
    super.gallery,
    super.color,
    required super.startDate,
    required super.endDate,
    required super.latitude,
    required super.longitude,
    required super.locationName,
    super.isActive = true,
  });

  /// Maps the backend `EventSerializer` shape (title / event_type / date_ad /
  /// short_description / gallery …) — see backend/apps/events/serializers.py.
  factory CulturalEventModel.fromJson(Map<String, dynamic> json) {
    final start = DateTime.parse(json['date_ad'] as String);
    final endRaw = json['end_date_ad'] as String?;
    return CulturalEventModel(
      id: json['id'].toString(),
      siteId: json['district']?.toString(),
      title: (json['title'] ?? '') as String,
      titleNepali: (json['title_np'] ?? '') as String,
      eventType: (json['event_type'] ?? 'General') as String,
      description: (json['description'] ?? '') as String,
      descriptionNepali: (json['description_np'] ?? '') as String,
      shortDescription: (json['short_description'] ?? '') as String,
      imageUrl: (json['image_url'] ?? '') as String,
      gallery: (json['gallery'] as List?)?.whereType<String>().toList() ?? const [],
      color: (json['color'] ?? '') as String,
      startDate: start,
      endDate: (endRaw != null && endRaw.isNotEmpty) ? DateTime.parse(endRaw) : start,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      locationName: (json['district_name'] ?? '') as String,
      isActive: (json['is_published'] ?? true) as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'district': siteId,
      'title': title,
      'event_type': eventType,
      'short_description': shortDescription,
      'description': description,
      'image_url': imageUrl,
      'gallery': gallery,
      'color': color,
      'date_ad': startDate.toIso8601String().split('T')[0],
      'end_date_ad': endDate.toIso8601String().split('T')[0],
      'latitude': latitude,
      'longitude': longitude,
      'district_name': locationName,
      'is_published': isActive,
    };
  }
}







