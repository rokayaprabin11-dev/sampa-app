class BookmarkModel {
  final String id;
  final String userId;
  final String siteId;
  final DateTime bookmarkedAt;

  BookmarkModel({
    required this.id,
    required this.userId,
    required this.siteId,
    required this.bookmarkedAt,
  });

  factory BookmarkModel.fromJson(Map<String, dynamic> json) {
    return BookmarkModel(
      id: json['id'].toString(),
      userId: json['user']?.toString() ?? '',
      siteId: json['site']?.toString() ?? '',
      bookmarkedAt: DateTime.parse(json['bookmarked_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'site_id': siteId,
      'bookmarked_at': bookmarkedAt.toIso8601String(),
    };
  }
}







