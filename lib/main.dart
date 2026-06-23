import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';

import 'app.dart';
import 'core/database/database_helper.dart';
import 'core/network/api_client.dart';
import 'core/services/notification_service.dart';

import 'data/repositories/heritage_repository_impl.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'data/repositories/event_repository_impl.dart';

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
  
  final dbHelper = DatabaseHelper();
  final tokenStorage = SecureTokenStorage();
  final dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 60),
    receiveTimeout: const Duration(seconds: 60),
  ));
  final apiClient = ApiClient(dio: dio, tokenStorage: tokenStorage);
  await ApiClient.initCache(dio);

  if (!kIsWeb) {
    try {
      final notificationService = NotificationService();
      await notificationService.initialize(apiClient: apiClient);
    } catch (e) {
      debugPrint('--- Notification Service FAILED: $e ---');
    }
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

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AutoSyncProvider()),
        ChangeNotifierProxyProvider<AutoSyncProvider, HeritageProvider>(
          create: (_) => HeritageProvider(repository: heritageRepository),
          update: (_, autoSync, previous) => HeritageProvider(
            repository: heritageRepository,
            autoSyncProvider: autoSync,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(repository: authRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => EventProvider(repository: eventRepository)..loadEvents(),
        ),
        ChangeNotifierProvider(
          create: (_) => GuideProvider(apiClient: apiClient),
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
          create: (context) => ProfileProvider(dbHelper, apiClient, null),
          update: (context, authProvider, previous) => ProfileProvider(dbHelper, apiClient, authProvider.user?.uid),
        ),
      ],
      child: const SampadaApp(),
    ),
  );
}