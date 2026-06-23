class SiteImageModel {
  final String id;
  final String siteId;
  final String imageUrl;
  final String caption;
  final int order;

  SiteImageModel({
    required this.id,
    required this.siteId,
    required this.imageUrl,
    this.caption = '',
    this.order = 0,
  });

  factory SiteImageModel.fromJson(Map<String, dynamic> json) {
    return SiteImageModel(
      id: json['id'].toString(),
      siteId: json['site_id']?.toString() ?? '',
      imageUrl: json['image_url'] ?? '',
      caption: json['caption_en'] ?? json['title_en'] ?? json['caption'] ?? '',
      order: json['sort_order'] ?? json['order'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'site_id': siteId,
      'image_url': imageUrl,
      'caption': caption,
      'order': order,
    };
  }
}







