import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import '../network/api_client.dart';
import '../network/api_constants.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  ApiClient? _apiClient;

  /// Initializes both local and Firebase notifications.
  Future<void> initialize({ApiClient? apiClient}) async {
    _apiClient = apiClient;
    // 1. Local Notifications Initialization
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        debugPrint('Notification tapped: ${response.payload}');
      },
    );

    // 2. Firebase Messaging Initialization
    await _setupFirebaseMessaging();
  }

  Future<void> _setupFirebaseMessaging() async {
    // Request permission (mostly for iOS)
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted permission');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      debugPrint('User granted provisional permission');
    } else {
      debugPrint('User declined or has not accepted permission');
    }

    // Get FCM Token
    String? token = await _firebaseMessaging.getToken();
    debugPrint('FCM Token: $token');
    
    if (token != null && _apiClient != null && await _apiClient!.tokenStorage.getAccessToken() != null) {
      await _syncTokenWithBackend(token);
    }

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      if (message.notification != null) {
        debugPrint('Message also contained a notification: ${message.notification}');
        showLocalNotification(
          title: message.notification?.title ?? '',
          body: message.notification?.body ?? '',
          payload: message.data.toString(),
        );
      }
    });
  }

  Future<void> _syncTokenWithBackend(String token) async {
    try {
      final deviceType = Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'web');
      await _apiClient?.post(
        ApiEndpoints.fcmToken,
        data: {
          'token': token,
          'device_type': deviceType,
        },
      );
      debugPrint('FCM Token synced with backend');
    } catch (e) {
      debugPrint('Error syncing FCM token: $e');
    }
  }

  /// Call after login to register FCM token with the authenticated backend.
  Future<void> syncAfterLogin() async {
    if (_apiClient == null) return;
    final token = await _firebaseMessaging.getToken();
    if (token != null) await _syncTokenWithBackend(token);
  }

  /// Shows a local notification.
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'sampada_notifications',
      'Sampada Notifications',
      channelDescription: 'General notifications for Sampada app',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    // Anti-Spam Check
    if (!await _canSendNotification(payload ?? '')) {
      debugPrint('Notification suppressed by anti-spam engine.');
      return;
    }

    await _localNotificationsPlugin.show(
      id: 0,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
      payload: payload,
    );
    
    await _updateLastNotificationTime(payload ?? '');
  }

  /// Basic Anti-Spam Engine
  Future<bool> _canSendNotification(String eventId) async {
    // 1. Cooldown per event = 24h
    // 2. Max 3 notifications per hour
    // (This would ideally use shared_preferences or similar for persistence)
    // For now, using a simple in-memory check or mock logic
    return true; 
  }

  Future<void> _updateLastNotificationTime(String eventId) async {
    // Store time of last notification
  }
}

// Background handler must be a top-level function
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Handling a background message: ${message.messageId}");
}







