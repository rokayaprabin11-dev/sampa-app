import 'dart:convert';
import 'package:sampada/core/database/database_helper.dart';
import 'package:sqflite/sqlite_api.dart';

class LocalNotification {
  final String id;
  final String title;
  final String body;
  final String type;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime receivedAt;

  const LocalNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.data,
    required this.isRead,
    required this.receivedAt,
  });

  LocalNotification copyWith({bool? isRead}) => LocalNotification(
        id: id,
        title: title,
        body: body,
        type: type,
        data: data,
        isRead: isRead ?? this.isRead,
        receivedAt: receivedAt,
      );

  factory LocalNotification.fromMap(Map<String, dynamic> m) => LocalNotification(
        id: m['id'] as String,
        title: m['title'] as String,
        body: m['body'] as String,
        type: m['type'] as String? ?? 'system',
        data: jsonDecode(m['data'] as String? ?? '{}') as Map<String, dynamic>,
        isRead: (m['is_read'] as int? ?? 0) == 1,
        receivedAt: DateTime.fromMillisecondsSinceEpoch(m['received_at'] as int),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'body': body,
        'type': type,
        'data': jsonEncode(data),
        'is_read': isRead ? 1 : 0,
        'received_at': receivedAt.millisecondsSinceEpoch,
      };
}

class NotificationLocalDataSource {
  final DatabaseHelper dbHelper;
  const NotificationLocalDataSource({required this.dbHelper});

  Future<List<LocalNotification>> getAll({int limit = 50}) async {
    final db = await dbHelper.database;
    final rows = await db.query(
      'local_notifications',
      orderBy: 'received_at DESC',
      limit: limit,
    );
    return rows.map(LocalNotification.fromMap).toList();
  }

  Future<int> getUnreadCount() async {
    final db = await dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM local_notifications WHERE is_read = 0',
    );
    return result.first['cnt'] as int? ?? 0;
  }

  Future<void> save(LocalNotification notification) async {
    final db = await dbHelper.database;
    await db.insert(
      'local_notifications',
      notification.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> markRead(String id) async {
    final db = await dbHelper.database;
    await db.update(
      'local_notifications',
      {'is_read': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markAllRead() async {
    final db = await dbHelper.database;
    await db.update('local_notifications', {'is_read': 1}, where: 'is_read = 0');
  }

  Future<void> deleteOlderThan(Duration age) async {
    final db = await dbHelper.database;
    final cutoff = DateTime.now().subtract(age).millisecondsSinceEpoch;
    await db.delete(
      'local_notifications',
      where: 'received_at < ?',
      whereArgs: [cutoff],
    );
  }
}
