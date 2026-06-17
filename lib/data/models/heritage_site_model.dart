import 'package:sampada/data/models/heritage_site.dart';
import 'site_image_model.dart';

class HeritageSiteModel extends HeritageSite {
  const HeritageSiteModel({
    required super.id,
    required super.name,
    required super.nameNepali,
    required super.description,
    required super.descriptionNepali,
    required super.location,
    required super.latitude,
    required super.longitude,
    super.imageUrl,
    super.isUnesco,
    super.rating,
    super.reviewsCount,
    super.avgVisitHours,
    required super.category,
    required super.district,
    required super.districtId,
    super.isFeatured,
    super.gallery,
    super.createdAt,
    this.provinceName,
  });

  final String? provinceName;

  factory HeritageSiteModel.fromJson(Map<String, dynamic> json) {
    return HeritageSiteModel(
      id: json['id'].toString(),
      name: json['name_en'] ?? json['name'] ?? 'Unknown Site',
      nameNepali: json['name_ne'] ?? json['name_nepali'] ?? '',
      description: json['description_en'] ?? json['description'] ?? '',
      descriptionNepali: json['description_ne'] ?? json['description_nepali'] ?? '',
      location: json['district_name'] ?? json['location_name'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      imageUrl: json['cover_image_url'] ?? json['image_url'],
      isUnesco: json['is_unesco'] ?? false,
      rating: (json['avg_rating'] as num?)?.toDouble() ?? (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewsCount: json['review_count'] ?? 0,
      avgVisitHours: (json['avg_visit_hours'] as num?)?.toDouble() ?? 1.0,
      category: json['category_name'] ?? json['category'] ?? 'heritage',
      district: json['district_name'] ?? json['district'] ?? '',
      districtId: json['district_name'] ?? '', // Using tag as ID in simplified mode
      isFeatured: json['is_featured'] ?? false,
      gallery: (json['gallery'] as List?)?.map((i) => SiteImageModel.fromJson(i)).toList() ?? [],
      provinceName: json['province_name'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }

  /// Serialises to the local_heritage_sites SQLite column names.
  Map<String, dynamic> toJson() {
    return {
      'id':               id,
      'name_en':          name,
      'name_ne':          nameNepali,
      'category':         category,
      'short_desc_en':    '',              // populated by ContentTranslator if available
      'short_desc_ne':    '',
      'description_en':   description,
      'description_ne':   descriptionNepali,
      'latitude':         latitude,
      'longitude':        longitude,
      'district':         district,
      'province':         provinceName ?? '',
      'is_unesco':        isUnesco ? 1 : 0,
      'cover_image_url':  imageUrl ?? '',
      'rating_avg':       rating,
      'review_count':     reviewsCount,
      'is_bookmarked':    0,
      'is_featured':      isFeatured ? 1 : 0,
      'geofence_radius_m': 500,
      'cached_at':        DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'is_dirty':         0,
    };
  }

  /// Deserialises from a local_heritage_sites SQLite row.
  factory HeritageSiteModel.fromMap(Map<String, dynamic> map) {
    return HeritageSiteModel(
      id:                map['id'].toString(),
      name:              map['name_en'] ?? map['name'] ?? '',
      nameNepali:        map['name_ne'] ?? map['name_nepali'] ?? '',
      description:       map['description_en'] ?? map['description'] ?? '',
      descriptionNepali: map['description_ne'] ?? map['description_nepali'] ?? '',
      location:          map['district'] ?? map['location'] ?? '',
      latitude:          (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude:         (map['longitude'] as num?)?.toDouble() ?? 0.0,
      imageUrl:          map['cover_image_url'] ?? map['image_url'],
      isUnesco:          (map['is_unesco'] as int? ?? 0) == 1,
      rating:            (map['rating_avg'] ?? map['rating'] as num?)?.toDouble() ?? 0.0,
      reviewsCount:      map['review_count'] as int? ?? 0,
      avgVisitHours:     (map['avg_visit_hours'] as num?)?.toDouble() ?? 1.0,
      category:          map['category'] ?? 'heritage',
      district:          map['district'] ?? '',
      districtId:        map['district'] ?? map['district_id'] ?? '',
      isFeatured:        (map['is_featured'] as int? ?? 0) == 1,
      provinceName:      map['province'] ?? map['province_name'],
      gallery:           const [],
      createdAt:         map['cached_at'] != null
                           ? DateTime.fromMillisecondsSinceEpoch(
                               (map['cached_at'] as int) * 1000)
                           : null,
    );
  }
}







