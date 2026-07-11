class DistrictModel {
  final String id;
  final String name;
  final String nameNp;
  final String slug;
  final String province;
  final String descriptionEn;
  final String coverImageUrl;
  final int sitesCount;
  final int unescoCount;
  final int eventCount;

  DistrictModel({
    required this.id,
    required this.name,
    this.nameNp = '',
    required this.slug,
    required this.province,
    required this.descriptionEn,
    required this.coverImageUrl,
    required this.sitesCount,
    required this.unescoCount,
    required this.eventCount,
  });

  factory DistrictModel.fromJson(Map<String, dynamic> json) {
    return DistrictModel(
      id: json['id'].toString(),
      name: json['name_en'] ?? json['name'] ?? '',
      nameNp: json['name_np'] ?? '',
      slug: json['slug'] ?? '',
      province: json['province'] ?? json['province_np'] ?? '',
      descriptionEn: json['description_en'] ?? '',
      coverImageUrl: json['cover_image_url'] ?? '',
      sitesCount: json['site_count'] ?? json['heritage_site_count'] ?? 0,
      unescoCount: json['unesco_count'] ?? 0,
      eventCount: json['event_count'] ?? 0,
    );
  }
}
