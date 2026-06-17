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
    required super.startDate,
    required super.endDate,
    required super.latitude,
    required super.longitude,
    required super.locationName,
    super.isActive = true,
  });

  factory CulturalEventModel.fromJson(Map<String, dynamic> json) {
    return CulturalEventModel(
      id: json['id'].toString(),
      siteId: json['site']?.toString(),
      title: json['name'], // Updated: Backend uses 'name'
      titleNepali: json['name_nepali'] ?? '',
      eventType: json['category'] ?? 'General',
      description: json['description'] ?? '',
      descriptionNepali: json['description_nepali'] ?? '',
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      latitude: (json['location_override']?['coordinates']?[1] as num?)?.toDouble() ?? 
               (json['site_details']?['location']?['lat'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['location_override']?['coordinates']?[0] as num?)?.toDouble() ?? 
                (json['site_details']?['location']?['lon'] as num?)?.toDouble() ?? 0.0,
      locationName: json['site_name'] ?? json['address'] ?? '',
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'site_id': siteId,
      'title': title,
      'title_nepali': titleNepali,
      'event_type': eventType,
      'description': description,
      'description_nepali': descriptionNepali,
      'start_date': startDate.toIso8601String().split('T')[0],
      'end_date': endDate.toIso8601String().split('T')[0],
      'latitude': latitude,
      'longitude': longitude,
      'location_name': locationName,
      'is_active': isActive,
    };
  }
}







