import 'package:flutter/foundation.dart';
import 'package:sampada/core/network/api_client.dart';
import 'package:sampada/core/network/api_endpoints.dart';
import 'package:sampada/data/datasources/local/notification_local_datasource.dart';
import 'package:sampada/core/database/database_helper.dart';

class NotificationProvider extends ChangeNotifier {
  final ApiClient apiClient;
  final NotificationLocalDataSource _local;

  List<LocalNotification> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  String? _error;

  NotificationProvider({required this.apiClient, required DatabaseHelper dbHelper})
      : _local = NotificationLocalDataSource(dbHelper: dbHelper);

  List<LocalNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> load({bool remote = true}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (remote) {
        try {
          // apiClient.get() already returns the decoded body (List or Map),
          // not a Response — do NOT access .data on it.
          final data = await apiClient.get(ApiEndpoints.notifications);
          final items = (data is Map ? (data['results'] ?? []) : data) as List<dynamic>;
          for (final item in items) {
            final m = item as Map<String, dynamic>;
            await _local.save(LocalNotification(
              id: m['id'].toString(),
              title: m['title'] as String? ?? '',
              body: m['body'] as String? ?? '',
              type: m['type'] as String? ?? 'system',
              data: (m['data'] as Map<String, dynamic>?) ?? {},
              isRead: m['is_read'] as bool? ?? false,
              receivedAt: DateTime.tryParse(m['created_at'] as String? ?? '') ?? DateTime.now(),
            ));
          }
        } catch (_) {
          // offline or parse error — fall through to whatever is cached locally
        }
      }

      _notifications = await _local.getAll();
      _unreadCount = _notifications.where((n) => !n.isRead).length;
    } catch (e) {
      // Local store unavailable (e.g. table missing) — show empty, never hang.
      _error = e.toString();
      _notifications = [];
      _unreadCount = 0;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveLocal(LocalNotification n) async {
    await _local.save(n);
    _notifications = await _local.getAll();
    _unreadCount = _notifications.where((n) => !n.isRead).length;
    notifyListeners();
  }

  Future<void> markRead(String id) async {
    await _local.markRead(id);
    try {
      final numId = int.tryParse(id);
      if (numId != null) {
        await apiClient.patch(ApiEndpoints.markOneRead(numId), data: {});
      }
    } catch (_) {}
    _notifications = await _local.getAll();
    _unreadCount = _notifications.where((n) => !n.isRead).length;
    notifyListeners();
  }

  Future<void> markAllRead() async {
    await _local.markAllRead();
    try {
      await apiClient.patch(ApiEndpoints.readAll, data: {});
    } catch (_) {}
    _notifications = await _local.getAll();
    _unreadCount = 0;
    notifyListeners();
  }
}
