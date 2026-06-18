import 'package:sampada/core/network/api_client.dart';
import 'package:sampada/core/network/api_constants.dart';

abstract class AuthRemoteDataSource {
  Future<Map<String, dynamic>> syncUser(String idToken);
  Future<void> logout(String? refreshToken);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final ApiClient apiClient;

  AuthRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<Map<String, dynamic>> syncUser(String idToken) async {
    final data = await apiClient.post(
      ApiEndpoints.sync,
      data: {'firebase_token': idToken},
    );
    if (data is Map<String, dynamic>) {
      return data;
    }
    throw Exception('Unexpected response format from auth sync');
  }

  @override
  Future<void> logout(String? refreshToken) async {
    try {
      await apiClient.post(
        ApiEndpoints.logout,
        data: refreshToken != null ? {'refresh': refreshToken} : {},
      );
    } catch (_) {
      // Best-effort — local cleanup happens regardless
    }
  }
}







