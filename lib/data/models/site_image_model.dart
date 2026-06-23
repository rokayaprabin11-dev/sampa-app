class SiteImageModel {
  final String id;
  final String siteId;
  final String imageUrl;
  final String name;       // title_en from backend
  final String description; // description_en from backend
  final String caption;    // caption_en or legacy caption
  final int order;

  SiteImageModel({
    required this.id,
    required this.siteId,
    required this.imageUrl,
    this.name = '',
    this.description = '',
    this.caption = '',
    this.order = 0,
  });

  factory SiteImageModel.fromJson(Map<String, dynamic> json) {
    final title = json['title_en'] ?? json['title'] ?? '';
    return SiteImageModel(
      id: json['id'].toString(),
      siteId: json['site_id']?.toString() ?? '',
      imageUrl: json['image_url'] ?? '',
      name: title,
      description: json['description_en'] ?? json['description'] ?? '',
      caption: json['caption_en'] ?? json['caption'] ?? title,
      order: json['sort_order'] ?? json['order'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'site_id': siteId,
      'image_url': imageUrl,
      'title_en': name,
      'description_en': description,
      'caption': caption,
      'order': order,
    };
  }
}
