class DistrictModel {
  final String id;
  final String name;
  final String province;
  final int sitesCount;
  final int unescoCount;

  DistrictModel({
    required this.id,
    required this.name,
    required this.province,
    required this.sitesCount,
    required this.unescoCount,
  });

  factory DistrictModel.fromJson(Map<String, dynamic> json) {
    return DistrictModel(
      id: json['id'].toString(),
      name: json['name'],
      province: json['province'] ?? '',
      sitesCount: json['heritage_site_count'] ?? 0,
      unescoCount: json['unesco_count'] ?? 0,
    );
  }
}







