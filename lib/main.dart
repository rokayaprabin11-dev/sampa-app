import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';

import 'app.dart';
import 'core/constants/app_strings.dart';
import 'core/database/database_helper.dart';
import 'core/network/api_client.dart';
import 'core/services/notification_service.dart';
import 'core/services/nearby_service.dart';

import 'data/repositories/heritage_repository_impl.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'data/repositories/event_repository_impl.dart';
import 'data/repositories/payment_repository.dart';

import 'data/datasources/local/heritage_local_datasource.dart';
import 'data/datasources/remote/heritage_remote_datasource.dart';
import 'data/datasources/remote/auth_remote_datasource.dart';
import 'data/datasources/remote/event_remote_datasource.dart';
import 'data/datasources/local/event_local_datasource.dart';
import 'data/datasources/local/secure_token_storage.dart';

import 'providers/heritage_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/event_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/guide_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/text_size_provider.dart';
import 'providers/auto_sync_provider.dart';
import 'providers/notification_prefs_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/payment_provider.dart';
import 'providers/guide_payment_provider.dart';

import 'injection.dart' as di;

void main() async {
  debugPrint('--- APP STARTING ---');
  WidgetsFlutterBinding.ensureInitialized();

  // Cap Flutter image cache: 80MB disk, 40MB memory, 200 images max
  PaintingBinding.instance.imageCache.maximumSizeBytes = 40 * 1024 * 1024;
  PaintingBinding.instance.imageCache.maximumSize = 200;
  
  try {
    await di.init();
  } catch (e) {
    debugPrint('--- DI Initialization FAILED: $e ---');
  }
  
  try {
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyC4CPOxQh-UokNJEniQ0NHX0KgKYf7Vz04",
          appId: "1:813832542964:web:0f41334816c5678854c5ca",
          messagingSenderId: "813832542964",
          projectId: "sampada-e7e99",
          authDomain: "sampada-e7e99.firebaseapp.com",
          storageBucket: "sampada-e7e99.firebasestorage.app",
        ),
      );
    } else {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyC4CPOxQh-UokNJEniQ0NHX0KgKYf7Vz04",
          appId: "1:813832542964:android:29ffb9d4a15e89154c5ca1",
          messagingSenderId: "813832542964",
          projectId: "sampada-e7e99",
          storageBucket: "sampada-e7e99.firebasestorage.app",
        ),
      );
    }
  } catch (e) {
    debugPrint('--- Firebase initialization FAILED: $e ---');
  }

  await FirebasePerformance.instance.setPerformanceCollectionEnabled(true);

  FirebaseAuth? firebaseAuth;
  try {
    firebaseAuth = FirebaseAuth.instance;
  } catch (e) {
    debugPrint('--- FirebaseAuth.instance FAILED: $e ---');
  }
  
  final navigatorKey = GlobalKey<NavigatorState>();

  final dbHelper = DatabaseHelper();
  final tokenStorage = SecureTokenStorage();
  final dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 60),
    receiveTimeout: const Duration(seconds: 60),
  ));
  final apiClient = ApiClient(
    dio: dio,
    tokenStorage: tokenStorage,
    onSessionExpired: () {
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        AppStrings.loginPath,
        (_) => false,
      );
    },
  );
  await ApiClient.initCache(dio);

  // Client half of the nearby-notification system: registers native geofences
  // for the nearest heritage sites and posts validated fixes on entry. Held so
  // the "Nearby Site Alerts" switch can start/stop the same instance.
  NearbyService? nearbyService;

  if (!kIsWeb) {
    try {
      final notificationService = NotificationService();
      await notificationService.initialize(
        apiClient: apiClient,
        dbHelper: dbHelper,
        navigatorKey: navigatorKey,
      );
    } catch (e) {
      debugPrint('--- Notification Service FAILED: $e ---');
    }

    nearbyService = NearbyService(apiClient: apiClient);
  }

  final heritageLocalDataSource = HeritageLocalDataSourceImpl(dbHelper: dbHelper);
  unawaited(heritageLocalDataSource.evictStaleCache());
  final heritageRemoteDataSource = HeritageRemoteDataSourceImpl(apiClient: apiClient);
  final heritageRepository = HeritageRepositoryImpl(
    remoteDataSource: heritageRemoteDataSource,
    localDataSource: heritageLocalDataSource,
  );
  
  final authRemoteDataSource = AuthRemoteDataSourceImpl(apiClient: apiClient);
  final authRepository = AuthRepositoryImpl(
    firebaseAuth: firebaseAuth,
    remoteDataSource: authRemoteDataSource,
    tokenStorage: tokenStorage,
  );

  final eventRemoteDataSource = EventRemoteDataSourceImpl(apiClient: apiClient);
  final eventLocalDataSource = EventLocalDataSourceImpl(dbHelper: dbHelper);
  final eventRepository = EventRepositoryImpl(
    remoteDataSource: eventRemoteDataSource,
    localDataSource: eventLocalDataSource,
  );

  // Both payment providers read the same endpoints from opposite sides — the
  // tourist submits, the guide confirms — so they share one repository.
  final paymentRepository = PaymentRepository(apiClient: apiClient);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AutoSyncProvider()),
        ChangeNotifierProvider(
          create: (_) => NotificationPrefsProvider(
            notificationService: NotificationService(),
            nearbyService: nearbyService,
          )..applyOnStartup(),
        ),
        ChangeNotifierProxyProvider<AutoSyncProvider, HeritageProvider>(
          create: (_) => HeritageProvider(repository: heritageRepository),
          update: (_, autoSync, previous) {
            previous!.autoSyncProvider = autoSync;
            return previous;
          },
        ),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(repository: authRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => EventProvider(repository: eventRepository)..loadEvents(),
        ),
        ChangeNotifierProxyProvider<AuthProvider, GuideProvider>(
          create: (_) => GuideProvider(apiClient: apiClient),
          update: (_, authProvider, previous) {
            previous!.updateUserId(authProvider.user?.uid);
            return previous;
          },
        ),
        ChangeNotifierProvider(
          create: (_) => LocaleProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => TextSizeProvider(),
        ),
        ChangeNotifierProxyProvider<AuthProvider, ProfileProvider>(
          create: (_) => ProfileProvider(dbHelper, apiClient, null),
          update: (_, authProvider, previous) {
            previous!.updateUserId(authProvider.user?.uid);
            return previous;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, NotificationProvider>(
          create: (_) => NotificationProvider(apiClient: apiClient, dbHelper: dbHelper),
          update: (_, authProvider, previous) {
            previous!.updateUserId(authProvider.user?.uid);
            return previous;
          },
        ),
        // Payment history is private; both providers clear on a user switch.
        ChangeNotifierProxyProvider<AuthProvider, PaymentProvider>(
          create: (_) => PaymentProvider(repository: paymentRepository),
          update: (_, authProvider, previous) {
            previous!.updateUserId(authProvider.user?.uid);
            return previous;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, GuidePaymentProvider>(
          create: (_) => GuidePaymentProvider(repository: paymentRepository),
          update: (_, authProvider, previous) {
            previous!.updateUserId(authProvider.user?.uid);
            return previous;
          },
        ),
      ],
      child: SampadaApp(navigatorKey: navigatorKey),
    ),
  );
}