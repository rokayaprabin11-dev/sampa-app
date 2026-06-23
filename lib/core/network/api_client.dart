import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cache_interceptor_db_store/dio_cache_interceptor_db_store.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sampada/data/datasources/local/secure_token_storage.dart';
import 'network_exceptions.dart';
import 'api_endpoints.dart';

// TTLs for cacheable endpoints
const _ttlSiteList    = Duration(hours: 6);
const _ttlSiteDetail  = Duration(hours: 12);
const _ttlCategories  = Duration(days: 7);
const _ttlDistricts   = Duration(days: 7);

// Paths that should never be cached (auth, user-specific, mutations)
bool _shouldSkipCache(String path) {
  const skip = ['/auth/', '/users/', '/bookmarks/', '/visits/', '/upload-'];
  return skip.any((s) => path.contains(s));
}

Duration? _ttlFor(String path) {
  if (path.contains('/categories/'))          return _ttlCategories;
  if (path.contains('/districts/'))           return _ttlDistricts;
  if (RegExp(r'/sites/[^/]+/$').hasMatch(path)) return _ttlSiteDetail;
  if (path.contains('/sites/') || path.contains('/search/') || path.contains('/featured/') || path.contains('/nearby/'))
    return _ttlSiteList;
  return null;
}

class ApiClient {
  final Dio dio;
  final SecureTokenStorage tokenStorage;
  static CacheStore? _cacheStore;

  ApiClient({required this.dio, required this.tokenStorage}) {
    _addPerformanceInterceptor();
    _addAuthInterceptor();
  }

  static Future<void> initCache(Dio dio) async {
    final dir = await getApplicationDocumentsDirectory();
    _cacheStore = DbCacheStore(databasePath: p.join(dir.path, 'sampada_cache.db'));
    dio.interceptors.add(DioCacheInterceptor(options: CacheOptions(
      store: _cacheStore!,
      policy: CachePolicy.noCache,
    )));
  }

  static Future<void> clearCache() async {
    await _cacheStore?.clean();
  }

  void _addPerformanceInterceptor() {
    final perf = FirebasePerformance.instance;
    final metrics = <RequestOptions, HttpMetric>{};

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final url = options.uri.toString();
        final method = HttpMethod.values.firstWhere(
          (m) => m.name == options.method.toUpperCase(),
          orElse: () => HttpMethod.Get,
        );
        final metric = perf.newHttpMetric(url, method);
        await metric.start();
        metrics[options] = metric;
        handler.next(options);
      },
      onResponse: (response, handler) async {
        final metric = metrics.remove(response.requestOptions);
        if (metric != null) {
          metric
            ..responsePayloadSize = response.data.toString().length
            ..httpResponseCode = response.statusCode;
          await metric.stop();
        }
        handler.next(response);
      },
      onError: (e, handler) async {
        final metric = metrics.remove(e.requestOptions);
        if (metric != null) {
          metric.httpResponseCode = e.response?.statusCode;
          await metric.stop();
        }
        handler.next(e);
      },
    ));
  }

  void _addAuthInterceptor() {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final accessToken = await tokenStorage.getAccessToken();
          if (accessToken != null) {
            options.headers['Authorization'] = 'Bearer $accessToken';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401) {
            final refreshToken = await tokenStorage.getRefreshToken();
            if (refreshToken != null) {
              try {
                final response = await dio.post(
                  '${ApiEndpoints.baseUrl}${ApiEndpoints.tokenRefresh}',
                  data: {'refresh': refreshToken},
                );
                
                final newAccess = response.data['access'];
                final newRefresh = response.data['refresh'];
                
                await tokenStorage.saveTokens(
                  accessToken: newAccess,
                  refreshToken: newRefresh,
                );

                e.requestOptions.headers['Authorization'] = 'Bearer $newAccess';
                final responseRetry = await dio.fetch(e.requestOptions);
                return handler.resolve(responseRetry);
              } catch (refreshError) {
                await tokenStorage.clearTokens();
              }
            }
          }
          return handler.next(e);
        },
      ),
    );
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      final fullPath = path.startsWith('http') ? path : '${ApiEndpoints.baseUrl}$path';
      Options? options;
      final ttl = _ttlFor(path);
      final store = _cacheStore;
      if (!kDebugMode && ttl != null && store != null && !_shouldSkipCache(path)) {
        options = CacheOptions(
          store: store,
          policy: CachePolicy.refreshForceCache,
          maxStale: ttl,
          hitCacheOnErrorExcept: [401, 403],
        ).toOptions();
      }
      final response = await dio.get(fullPath, queryParameters: queryParameters, options: options);
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  Future<dynamic> post(String path, {dynamic data}) async {
    try {
      final response = await dio.post(
        path.startsWith('http') ? path : '${ApiEndpoints.baseUrl}$path',
        data: data,
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  Future<dynamic> patch(String path, {dynamic data}) async {
    try {
      final response = await dio.patch(
        path.startsWith('http') ? path : '${ApiEndpoints.baseUrl}$path',
        data: data,
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  Future<dynamic> delete(String path, {dynamic data}) async {
    try {
      final response = await dio.delete(
        path.startsWith('http') ? path : '${ApiEndpoints.baseUrl}$path',
        data: data,
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  Future<dynamic> upload(String path, FormData formData) async {
    try {
      final response = await dio.post(
        path.startsWith('http') ? path : '${ApiEndpoints.baseUrl}$path',
        data: formData,
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  ServerException _handleDioError(DioException e) {
    String message = 'An unexpected error occurred';
    int? statusCode = e.response?.statusCode;

    if (e.type == DioExceptionType.connectionTimeout) {
      message = 'Connection timeout';
    } else if (e.type == DioExceptionType.receiveTimeout) {
      message = 'Server not responding';
    } else if (e.response != null) {
      final data = e.response?.data;
      if (data is Map && data.containsKey('message')) {
        message = data['message'];
      } else if (data is Map && data.containsKey('detail')) {
        message = data['detail'];
      } else {
        message = 'Server error: ${e.response?.statusMessage ?? e.message}';
      }
    } else {
      message = e.message ?? message;
    }

    return ServerException(message: message, statusCode: statusCode);
  }
}



