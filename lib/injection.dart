import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import 'core/database/database_helper.dart';
import 'core/network/api_client.dart';
import 'core/network/api_endpoints.dart';
import 'core/services/content_translator.dart';
import 'core/services/translation_service.dart';
import 'data/datasources/local/secure_token_storage.dart';
import 'data/repositories/i_location_repository.dart';
import 'data/repositories/location_repository_impl.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // --- Network ---------------------------------------------------------------
  final dio = Dio(BaseOptions(
    baseUrl: ApiEndpoints.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Content-Type': 'application/json'},
  ));

  sl.registerLazySingleton<Dio>(() => dio);
  sl.registerLazySingleton<SecureTokenStorage>(() => SecureTokenStorage());
  sl.registerLazySingleton<ApiClient>(
    () => ApiClient(dio: sl(), tokenStorage: sl()),
  );

  // --- Services --------------------------------------------------------------
  sl.registerLazySingleton<TranslationService>(
    () => TranslationService(apiClient: sl()),
  );

  sl.registerLazySingleton<DatabaseHelper>(() => DatabaseHelper());

  sl.registerLazySingleton<ContentTranslator>(
    () => ContentTranslator(
      translationService: sl(),
      dbHelper: sl<DatabaseHelper>(),
    ),
  );

  // --- Repositories ----------------------------------------------------------
  sl.registerLazySingleton<ILocationRepository>(() => LocationRepositoryImpl());
}
