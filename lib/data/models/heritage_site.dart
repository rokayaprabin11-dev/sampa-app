import 'package:equatable/equatable.dart';
import 'package:sampada/data/models/site_image_model.dart';

class HeritageSite extends Equatable {
  final String id;
  final String slug;
  final String name;
  final String nameNepali;
  final String description;
  final String descriptionNepali;
  final String location;
  final double latitude;
  final double longitude;
  final String? imageUrl;
  final bool isUnesco;
  final double rating;
  final int reviewsCount;
  final double avgVisitHours;
  final String category;
  final String district;
  final String districtId;
  final bool isFeatured;
  final List<SiteImageModel> gallery;
  final DateTime? createdAt;
  final String? reason;

  const HeritageSite({
    required this.id,
    this.slug = '',
    required this.name,
    required this.nameNepali,
    required this.description,
    required this.descriptionNepali,
    required this.location,
    required this.latitude,
    required this.longitude,
    this.imageUrl,
    this.isUnesco = false,
    this.rating = 0.0,
    this.reviewsCount = 0,
    this.avgVisitHours = 1.0,
    required this.category,
    required this.district,
    required this.districtId,
    this.isFeatured = false,
    this.gallery = const [],
    this.createdAt,
    this.reason,
  });

  /// Locale-aware content: Nepali when the UI language is Nepali and the field
  /// is filled, otherwise English — so a partly-translated record still reads.
  String localizedName(bool np) =>
      np && nameNepali.trim().isNotEmpty ? nameNepali : name;
  String localizedDescription(bool np) =>
      np && descriptionNepali.trim().isNotEmpty ? descriptionNepali : description;

  @override
  List<Object?> get props => [
        id,
        slug,
        name,
        nameNepali,
        description,
        descriptionNepali,
        location,
        latitude,
        longitude,
        imageUrl,
        isUnesco,
        rating,
        reviewsCount,
        avgVisitHours,
        category,
        district,
        districtId,
        isFeatured,
        gallery,
        createdAt,
        reason,
      ];
}







