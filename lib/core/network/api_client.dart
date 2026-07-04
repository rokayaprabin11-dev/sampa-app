import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sampada/data/datasources/local/secure_token_storage.dart';
import 'network_exceptions.dart';
import 'api_endpoints.dart';

// TTLs for cacheable endpoints
const _ttlSiteList    = Duration(hours: 6);
const _ttlSiteDetail  = Duration(hours: 12);
const _ttlCategories  = Duration(hours: 1);   // short — admin edits surface fast
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
  if (path.contains('/sites/') || path.contains('/search/') || path.contains('/featured/') || path.contains('/nearby/')) {
    return _ttlSiteList;
  }
  return null;
}

class ApiClient {
  final Dio dio;
  final SecureTokenStorage tokenStorage;
  static CacheStore? _cacheStore;

  Completer<String?>? _refreshCompleter;

  // Called by AuthProvider after forced logout so the UI navigates to login.
  void Function()? onSessionExpired;

  ApiClient({required this.dio, required this.tokenStorage, this.onSessionExpired}) {
    _addPerformanceInterceptor();
    _addAuthInterceptor();
  }

  // Returns true if the JWT is expired or expires within 2 minutes.
  static bool _isTokenExpiringSoon(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length != 3) return true;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map<String, dynamic>;
      final exp = payload['exp'] as int?;
      if (exp == null) return true;
      return DateTime.now().isAfter(
        DateTime.fromMillisecondsSinceEpoch(exp * 1000)
            .subtract(const Duration(minutes: 2)),
      );
    } catch (_) {
      return true;
    }
  }

  // Refresh the access token. Concurrent callers await the same in-flight
  // request instead of each independently hitting the refresh endpoint —
  // prevents the race where two calls both consume (and invalidate) the
  // same rotating refresh token before either can save the new one.
  Future<String?> _doRefresh() async {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    final completer = Completer<String?>();
    _refreshCompleter = completer;

    try {
      final refreshToken = await tokenStorage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        completer.complete(null);
        return null;
      }
      final response = await dio.post(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.tokenRefresh}',
        data: {'refresh': refreshToken},
      );
      final newAccess = response.data['access'] as String?;
      final newRefresh = response.data['refresh'] as String?;
      if (newAccess != null) {
        await tokenStorage.saveTokens(
          accessToken: newAccess,
          refreshToken: newRefresh ?? refreshToken,
        );
        completer.complete(newAccess);
        return newAccess;
      }
      completer.complete(null);
      return null;
    } catch (_) {
      completer.complete(null);
      return null;
    } finally {
      _refreshCompleter = null;
    }
  }

  Future<void> _handleSessionExpired(ErrorInterceptorHandler handler, DioException error) async {
    await tokenStorage.clearTokens();
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    onSessionExpired?.call();
    return handler.reject(error);
  }

  static void initCache(Dio dio) {
    _cacheStore = MemCacheStore(maxSize: 10 * 1024 * 1024); // 10 MB in-memory
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
          // CRITICAL: the refresh + sync endpoints must NOT enter the refresh
          // cycle. _doRefresh() issues a POST to the refresh endpoint; if that
          // POST re-enters this interceptor while the access token is expired,
          // it awaits the very _refreshCompleter that only completes once the
          // POST returns → hard deadlock → EVERY request hangs (whole-app
          // shimmer). Let auth handshake calls through untouched.
          final path = options.path;
          if (path.contains(ApiEndpoints.tokenRefresh) ||
              path.contains(ApiEndpoints.sync)) {
            return handler.next(options);
          }

          var accessToken = await tokenStorage.getAccessToken();
          if (accessToken == null || _isTokenExpiringSoon(accessToken)) {
            final refreshed = await _doRefresh();
            if (refreshed != null) accessToken = refreshed;
          }
          if (accessToken != null) {
            options.headers['Authorization'] = 'Bearer $accessToken';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401) {
            // Guest users (no refresh token) hitting a public-but-auth-preferred
            // endpoint should NOT trigger session expiry — they were never logged in.
            final refreshToken = await tokenStorage.getRefreshToken();
            if (refreshToken == null || refreshToken.isEmpty) {
              return handler.next(e);
            }
            final newAccess = await _doRefresh();
            if (newAccess != null) {
              e.requestOptions.headers['Authorization'] = 'Bearer $newAccess';
              try {
                final retried = await dio.fetch(e.requestOptions);
                return handler.resolve(retried);
              } catch (_) {
                return _handleSessionExpired(handler, e);
              }
            }
            return _handleSessionExpired(handler, e);
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



