class VisitHistoryModel {
  final String id;
  final String userId;
  final String siteId;
  final DateTime visitedAt;

  VisitHistoryModel({
    required this.id,
    required this.userId,
    required this.siteId,
    required this.visitedAt,
  });

  factory VisitHistoryModel.fromJson(Map<String, dynamic> json) {
    return VisitHistoryModel(
      id: json['id'].toString(),
      userId: json['user']?.toString() ?? '',
      siteId: json['site']?.toString() ?? '',
      visitedAt: DateTime.parse(json['visited_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'site_id': siteId,
      'visited_at': visitedAt.toIso8601String(),
    };
  }
}







