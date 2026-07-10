import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../database/database_helper.dart';
import '../../data/datasources/local/notification_local_datasource.dart';
import '../../core/constants/app_strings.dart';

// Top-level background handler — separate isolate, no DB/ApiClient access
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

    // ── Register message listeners FIRST ──────────────────────────────────
    // These need no FCM token, so a token-registration failure (common on
    // MIUI/Xiaomi without a healthy Google Play Services) can never abort the
    // rest of setup.
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    FirebaseMessaging.onMessage.listen((msg) async {
      final n = msg.notification;
      if (n != null) {
        await _saveToLocal(msg);
        // Image can arrive as data['image_url'] (our senders) or on the
        // platform notification block (notification.image) — accept both.
        final image = (msg.data['image_url'] as String?) ??
            n.android?.imageUrl ??
            n.apple?.imageUrl;
        await _showRich(
          title: n.title ?? '',
          body: n.body ?? '',
          imageUrl: image,
          payload: _encodePayload(msg),
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen(_navigateFromMessage);

    // Re-register whenever FCM (re)issues a token. This is the recovery path:
    // if the initial getToken() fails and FCM later succeeds (Play Services
    // updates, network returns), this fires and registers the device.
    _fcm.onTokenRefresh.listen(registerDevice);

    try {
      final initial = await _fcm.getInitialMessage();
      if (initial != null) _navigateFromMessage(initial);
    } catch (_) {}

    // ── Acquire token + register device, non-blocking with retry ──────────
    // Runs unawaited so a slow/failing FCM registration never delays startup.
    unawaited(_acquireTokenAndRegister());
  }

  /// Attempt FCM token acquisition a few times with backoff, then register the
  /// device (guest or logged-in) and subscribe to the all_users topic. If the
  /// token never arrives (MIUI IOException: "FCM Registration failed!"), the
  /// onTokenRefresh listener will register the device later when FCM recovers.
  Future<void> _acquireTokenAndRegister() async {
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final token = await _fcm.getToken();
        if (token != null) {
          await registerDevice(token);
          await subscribeToTopics();
          return;
        }
      } catch (e) {
        debugPrint('NotificationService: getToken failed '
            '(attempt ${attempt + 1}/3): $e');
      }
      await Future.delayed(Duration(seconds: 3 * (attempt + 1)));
    }
    debugPrint('NotificationService: FCM token unavailable after retries — '
        'onTokenRefresh will register the device if FCM recovers.');
  }

  // ── FCM Topic subscriptions ───────────────────────────────────────────────

  /// Call after login with the user's preferred language (e.g. 'ne' or 'en').
  Future<void> subscribeToTopics({String? language}) async {
    await _fcm.subscribeToTopic('all_users');
    final lang = language?.isNotEmpty == true ? language! : _deviceLanguage();
    await _fcm.subscribeToTopic('lang_$lang');
    debugPrint('NotificationService: subscribed to all_users + lang_$lang');
  }

  /// Call on logout.
  Future<void> unsubscribeFromTopics({String? language}) async {
    await _fcm.unsubscribeFromTopic('all_users');
    final lang = language?.isNotEmpty == true ? language! : _deviceLanguage();
    await _fcm.unsubscribeFromTopic('lang_$lang');
  }

  String _deviceLanguage() {
    try {
      final locale = Platform.localeName; // e.g. 'ne_NP'
      return locale.startsWith('ne') ? 'ne' : 'en';
    } catch (_) {
      return 'en';
    }
  }

  // ── Rich notification display ─────────────────────────────────────────────

  Future<void> _showRich({
    required String title,
    required String body,
    String? imageUrl,
    String? payload,
  }) async {
    AndroidNotificationDetails androidDetails;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      final localPath = await _downloadImage(imageUrl);
      if (localPath != null) {
        androidDetails = AndroidNotificationDetails(
          'sampada_notifications',
          'Sampada Notifications',
          channelDescription: 'Heritage & event notifications',
          importance: Importance.max,
          priority: Priority.high,
          styleInformation: BigPictureStyleInformation(
            FilePathAndroidBitmap(localPath),
            largeIcon: FilePathAndroidBitmap(localPath),
            contentTitle: title,
            summaryText: body,
          ),
        );
      } else {
        androidDetails = _defaultAndroidDetails();
      }
    } else {
      androidDetails = _defaultAndroidDetails();
    }

    await _localPlugin.show(
      id: DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: androidDetails),
      payload: payload,
    );
  }

  AndroidNotificationDetails _defaultAndroidDetails() =>
      const AndroidNotificationDetails(
        'sampada_notifications',
        'Sampada Notifications',
        channelDescription: 'Heritage & event notifications',
        importance: Importance.max,
        priority: Priority.high,
      );

  Future<String?> _downloadImage(String url) async {
    try {
      final dir = await getTemporaryDirectory();
      final ext = url.endsWith('.png') ? 'png' : 'jpg';
      final path = '${dir.path}/notif_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await Dio().download(url, path,
          options: Options(receiveTimeout: const Duration(seconds: 5)));
      return path;
    } catch (_) {
      return null;
    }
  }

  // ── Deep linking ─────────────────────────────────────────────────────────

  String _encodePayload(RemoteMessage msg) {
    final type = msg.data['type'] as String? ?? '';
    final eventId = msg.data['event_id'] ?? '';
    final siteSlug = msg.data['site_slug'] ?? msg.data['site_id'] ?? '';
    return '$type:$eventId:$siteSlug';
  }

  void _handleTap(String? payload) {
    if (payload == null || payload.isEmpty) return;
    final parts = payload.split(':');
    final type = parts.isNotEmpty ? parts[0] : '';
    switch (type) {
      case 'event':
      case 'event_reminder':
        _navigatorKey?.currentState?.pushNamed(AppStrings.eventsPath);
        break;
      case 'geofence':
      case 'heritage':
      case 'heritage.update':
        final slug = parts.length > 2 ? parts[2] : '';
        if (slug.isNotEmpty) {
          _navigatorKey?.currentState?.pushNamed(
            AppStrings.heritageDetailsPath,
            arguments: {'slug': slug},
          );
        } else {
          _navigatorKey?.currentState?.pushNamed(AppStrings.notificationsPath);
        }
        break;
      default:
        _navigatorKey?.currentState?.pushNamed(AppStrings.notificationsPath);
    }
  }

  void _navigateFromMessage(RemoteMessage msg) =>
      _handleTap(_encodePayload(msg));

  // ── Token sync ────────────────────────────────────────────────────────────

  /// Upsert this device on the backend. Works for guests (no auth header →
  /// backend records is_guest=true) and logged-in users (auth header → device
  /// linked to the user). Called on every launch and on token refresh.
  Future<void> registerDevice(String token) async {
    if (_apiClient == null) return;
    try {
      final platform = Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'web');
      final deviceId = await _getDeviceId();
      final pkg = await PackageInfo.fromPlatform();
      await _apiClient!.post(ApiEndpoints.deviceRegister, data: {
        'device_id': deviceId,
        'fcm_token': token,
        'platform': platform,
        'language': _deviceLanguage(),
        'app_version': '${pkg.version}+${pkg.buildNumber}',
      });
    } catch (e) {
      debugPrint('NotificationService: device register failed: $e');
    }
  }

  /// Called after login — re-registers the device (now authenticated, so the
  /// backend links it to the user) and subscribes to language topics.
  Future<void> syncAfterLogin({String? preferredLanguage}) async {
    if (_apiClient == null) return;
    final token = await _fcm.getToken();
    if (token != null) await registerDevice(token);
    await subscribeToTopics(language: preferredLanguage);
  }

  /// Called on logout — unlinks the device on the backend so it reverts to a
  /// guest device (still receives general broadcasts via all_users) and drops
  /// the personalized language topic.
  Future<void> signOut({String? preferredLanguage}) async {
    try {
      final deviceId = await _getDeviceId();
      await _apiClient?.post(ApiEndpoints.deviceUnregister, data: {'device_id': deviceId});
    } catch (e) {
      debugPrint('NotificationService: device unregister failed: $e');
    }
    // Keep all_users subscribed; only drop the language topic.
    final lang = preferredLanguage?.isNotEmpty == true ? preferredLanguage! : _deviceLanguage();
    try {
      await _fcm.unsubscribeFromTopic('lang_$lang');
    } catch (_) {}
  }

  Future<String> _getDeviceId() async {
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) return (await info.androidInfo).id;
      if (Platform.isIOS) return (await info.iosInfo).identifierForVendor ?? 'unknown';
    } catch (_) {}
    return 'unknown';
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

  // Kept for external callers that still use the old show API
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
    String? imageUrl,
  }) async {
    await _showRich(title: title, body: body, imageUrl: imageUrl, payload: payload);
  }
}
