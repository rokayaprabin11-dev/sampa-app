import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../database/database_helper.dart';
import '../../data/datasources/local/notification_local_datasource.dart';
import '../../core/constants/app_strings.dart';

// Top-level background handler — runs in separate isolate, no DB access
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM background: ${message.messageId}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localPlugin =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  ApiClient? _apiClient;
  NotificationLocalDataSource? _local;
  GlobalKey<NavigatorState>? _navigatorKey;

  Future<void> initialize({
    ApiClient? apiClient,
    DatabaseHelper? dbHelper,
    GlobalKey<NavigatorState>? navigatorKey,
  }) async {
    _apiClient = apiClient;
    _navigatorKey = navigatorKey;
    if (dbHelper != null) {
      _local = NotificationLocalDataSource(dbHelper: dbHelper);
    }

    // Local notifications init
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localPlugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (response) {
        _handleTap(response.payload);
      },
    );

    await _setupFcm();
  }

  Future<void> _setupFcm() async {
    final settings = await _fcm.requestPermission(
      alert: true, badge: true, sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    final token = await _fcm.getToken();
    if (token != null && _apiClient != null) {
      final hasAuth = await _apiClient!.tokenStorage.getAccessToken() != null;
      if (hasAuth) await _syncToken(token);
    }

    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    // Foreground message → show local notification + save to DB
    FirebaseMessaging.onMessage.listen((msg) async {
      final n = msg.notification;
      if (n != null) {
        await _saveToLocal(msg);
        await showLocalNotification(
          title: n.title ?? '',
          body: n.body ?? '',
          payload: _encodePayload(msg),
        );
      }
    });

    // Background tap (app was in background)
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      _navigateFromMessage(msg);
    });

    // Terminated tap (app was closed)
    final initial = await _fcm.getInitialMessage();
    if (initial != null) _navigateFromMessage(initial);
  }

  Future<void> _saveToLocal(RemoteMessage msg) async {
    final local = _local;
    if (local == null) return;
    try {
      await local.save(LocalNotification(
        id: msg.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: msg.notification?.title ?? '',
        body: msg.notification?.body ?? '',
        type: msg.data['type'] as String? ?? 'system',
        data: Map<String, dynamic>.from(msg.data),
        isRead: false,
        receivedAt: msg.sentTime ?? DateTime.now(),
      ));
    } catch (e) {
      debugPrint('NotificationService: failed to save locally: $e');
    }
  }

  String _encodePayload(RemoteMessage msg) {
    final type = msg.data['type'] as String? ?? '';
    final id = msg.data['event_id'] ?? msg.data['site_id'] ?? '';
    return '$type:$id';
  }

  void _handleTap(String? payload) {
    if (payload == null || payload.isEmpty) return;
    final parts = payload.split(':');
    final type = parts.isNotEmpty ? parts[0] : '';
    _navigatorKey?.currentState?.pushNamed(
      type == 'event' || type == 'event_reminder'
          ? AppStrings.eventsPath
          : type == 'geofence'
              ? AppStrings.homePath
              : AppStrings.notificationsPath,
    );
  }

  void _navigateFromMessage(RemoteMessage msg) {
    _handleTap(_encodePayload(msg));
  }

  Future<void> syncAfterLogin() async {
    if (_apiClient == null) return;
    final token = await _fcm.getToken();
    if (token != null) await _syncToken(token);
  }

  Future<void> _syncToken(String token) async {
    try {
      final type = Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'web');
      final deviceId = await _getDeviceId();
      final pkg = await PackageInfo.fromPlatform();
      await _apiClient?.post(ApiEndpoints.fcmToken, data: {
        'token': token,
        'device_type': type,
        'device_id': deviceId,
        'app_version': '${pkg.version}+${pkg.buildNumber}',
        'last_seen': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('NotificationService: token sync failed: $e');
    }
  }

  Future<String> _getDeviceId() async {
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) return (await info.androidInfo).id;
      if (Platform.isIOS) return (await info.iosInfo).identifierForVendor ?? 'unknown';
    } catch (_) {}
    return 'unknown';
  }

  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const channel = AndroidNotificationDetails(
      'sampada_notifications',
      'Sampada Notifications',
      channelDescription: 'Heritage & event notifications',
      importance: Importance.max,
      priority: Priority.high,
    );
    await _localPlugin.show(
      id: DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(android: channel),
      payload: payload,
    );
  }
}
