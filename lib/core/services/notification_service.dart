import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../database/database_helper.dart';
import '../../data/datasources/local/notification_local_datasource.dart';
import '../../core/constants/app_strings.dart';
import '../../presentation/screens/guides/chat_screen.dart';
import '../../presentation/screens/payments/guide_confirm_payment_screen.dart';
import '../../presentation/screens/payments/payment_receipt_screen.dart';
import '../../presentation/screens/payments/payment_screen.dart';
import '../../providers/guide_provider.dart';
import '../../core/constants/prefs_keys.dart';

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
    // NOTE: we do NOT request OS notification permission here. This runs at
    // startup, and asking on Android 13+ threw the system permission dialog
    // straight onto the splash screen before the user had seen anything. The
    // prompt is deferred to [ensurePermissionPrompt], called in-context from the
    // first Home screen. Everything below — listeners, token, device
    // registration — works without display permission (it governs data delivery
    // and topic reach; permission only gates whether a notification is shown),
    // so setup proceeds unconditionally rather than aborting when undecided.

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
          // Honour the user's push switch on every launch: a device that opted
          // out must not silently re-subscribe to the broadcast topics.
          await setPushEnabled(await isPushEnabled());
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

  /// Shows the OS notification-permission dialog once, at an in-context moment
  /// (first Home entry) rather than on the splash. Guarded by a persisted flag,
  /// so we ask at most once; after that the user manages it from system
  /// settings. Skips the prompt entirely if the user has already turned the
  /// in-app push switch off — no point asking the OS for something they opted
  /// out of. Safe to call on every Home build.
  Future<void> ensurePermissionPrompt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(PrefsKeys.notifPermissionAsked) ?? false) return;
      if (!await isPushEnabled()) return;
      await _fcm.requestPermission(alert: true, badge: true, sound: true);
      await prefs.setBool(PrefsKeys.notifPermissionAsked, true);
    } catch (e) {
      debugPrint('NotificationService: permission prompt failed: $e');
    }
  }

  // ── Push master switch ────────────────────────────────────────────────────

  /// The persisted "Push Notifications" setting. Defaults to on for a fresh
  /// install, matching the settings screen.
  Future<bool> isPushEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(PrefsKeys.pushNotificationsEnabled) ?? true;
    } catch (e) {
      debugPrint('NotificationService: could not read push pref, assuming on: $e');
      return true;
    }
  }

  /// Applies the push switch to FCM: on → subscribe to the broadcast topics,
  /// off → unsubscribe, which is what actually stops server-sent pushes (the
  /// backend broadcasts to the `all_users` / `lang_*` topics).
  Future<void> setPushEnabled(bool enabled, {String? language}) async {
    try {
      if (enabled) {
        await subscribeToTopics(language: language);
      } else {
        await unsubscribeFromTopics(language: language);
        debugPrint('NotificationService: push disabled — unsubscribed from topics');
      }
    } catch (e) {
      debugPrint('NotificationService: applying push pref failed: $e');
    }
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
    // booking_id rides along so a chat push can open the thread it belongs to,
    // not just the app.
    final bookingId = msg.data['booking_id'] ?? '';
    // Payment pushes are `type: booking` with an action — a guide being told
    // money arrived and a tourist being told it was confirmed are the same type
    // but belong on completely different screens, and only the action separates
    // them.
    final action = msg.data['action'] ?? '';
    final paymentId = msg.data['payment_id'] ?? '';
    return '$type:$eventId:$siteSlug:$bookingId:$action:$paymentId';
  }

  /// Whether the signed-in user is an approved guide. Read off the navigator's
  /// context because this service lives outside the widget tree; false when the
  /// tree isn't up yet, which is the right default (a tourist screen).
  bool _isApprovedGuide() {
    final context = _navigatorKey?.currentContext;
    if (context == null) return false;
    try {
      return Provider.of<GuideProvider>(context, listen: false)
              .myProfile?['status'] ==
          'approved';
    } catch (_) {
      return false; // provider not in scope — treat as a tourist
    }
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
      // A chat push means someone replied — open that conversation, not a list.
      // The name isn't in the payload, so ChatScreen resolves it from the
      // channel's participants.
      case 'chat':
        final bookingId = int.tryParse(parts.length > 3 ? parts[3] : '');
        if (bookingId != null) {
          _navigatorKey?.currentState?.push(
            MaterialPageRoute(builder: (_) => ChatScreen(bookingId: bookingId)),
          );
        } else {
          _navigatorKey?.currentState?.pushNamed(AppStrings.messagesPath);
        }
        break;
      // Booking pushes go to both sides of a booking — the tourist ("your guide
      // accepted") and the guide ("new request", "tourist cancelled") — so send
      // each to the screen that actually holds their side of it. A guide has no
      // My Bookings screen; their requests, tours and history live in the guide
      // profile.
      case 'booking':
        final action = parts.length > 4 ? parts[4] : '';
        final paymentId = int.tryParse(parts.length > 5 ? parts[5] : '');
        final bookingId = int.tryParse(parts.length > 3 ? parts[3] : '');

        // A payment push is about one payment, and dropping the user on a list
        // to hunt for it wastes the only thing the notification knew.
        if (paymentId != null) {
          switch (action) {
            case 'payment_submitted':
              _navigatorKey?.currentState?.push(MaterialPageRoute(
                builder: (_) => GuideConfirmPaymentScreen(paymentId: paymentId),
              ));
              return;
            case 'payment_confirmed':
              _navigatorKey?.currentState?.push(MaterialPageRoute(
                builder: (_) => PaymentReceiptScreen(paymentId: paymentId),
              ));
              return;
            case 'payment_rejected':
              // The tourist has to fix and resubmit, which is the payment screen
              // for that booking — not the receipt they never got.
              if (bookingId != null) {
                _navigatorKey?.currentState?.push(MaterialPageRoute(
                  builder: (_) => PaymentScreen(bookingId: bookingId),
                ));
                return;
              }
          }
        }

        _navigatorKey?.currentState?.pushNamed(
          _isApprovedGuide() ? AppStrings.guideProfilePath : AppStrings.myBookingsPath,
        );
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
    // Still subject to the push switch — logging in must not re-subscribe a
    // user who turned push off.
    await setPushEnabled(await isPushEnabled(), language: preferredLanguage);
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
