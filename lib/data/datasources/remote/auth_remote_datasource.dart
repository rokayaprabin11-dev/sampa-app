import 'package:sampada/core/network/api_client.dart';
import 'package:sampada/core/network/api_constants.dart';

abstract class AuthRemoteDataSource {
  Future<Map<String, dynamic>> syncUser(String idToken);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final ApiClient apiClient;

  AuthRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<Map<String, dynamic>> syncUser(String idToken) async {
    // Pass the Firebase ID token in the body for the backend to verify
    final data = await apiClient.post(
      ApiEndpoints.sync,
      data: {'firebase_token': idToken},
    );

    if (data is Map<String, dynamic>) {
      return data;
    } else {
      throw Exception('Unexpected response format from auth sync');
    }
  }
}







