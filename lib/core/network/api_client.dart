import 'package:dio/dio.dart';
import 'package:sampada/data/datasources/local/secure_token_storage.dart';
import 'network_exceptions.dart';
import 'api_endpoints.dart';

class ApiClient {
  final Dio dio;
  final SecureTokenStorage tokenStorage;

  ApiClient({required this.dio, required this.tokenStorage}) {
    _addAuthInterceptor();
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
      final response = await dio.get(
        path.startsWith('http') ? path : '${ApiEndpoints.baseUrl}$path',
        queryParameters: queryParameters,
      );
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



