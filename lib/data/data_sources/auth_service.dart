import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/constants/app_constants.dart';
import '../models/user_model.dart';

class AuthService {
  final Dio _dio = Dio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  AuthService() {
    _dio.options.baseUrl = ApiEndpoints.baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
  }

  /// Login with username and password
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.login,
        data: {'username': username, 'password': password},
      );

      if (response.statusCode == 200) {
        final data = response.data;

        // Save token and user info
        await _storage.write(
          key: AppConstants.keyAuthToken,
          value: data['token'] as String,
        );
        await _storage.write(
          key: AppConstants.keyUserId,
          value: data['user']['id'] as String,
        );
        await _storage.write(
          key: AppConstants.keyUserRole,
          value: data['user']['role'] as String,
        );

        return {
          'success': true,
          'user': UserModel.fromJson(data['user']),
          'token': data['token'],
        };
      } else {
        return {'success': false, 'message': 'Login failed'};
      }
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Network error occurred',
      };
    } catch (e) {
      return {'success': false, 'message': 'An unexpected error occurred'};
    }
  }

  /// Logout
  Future<void> logout() async {
    await _storage.delete(key: AppConstants.keyAuthToken);
    await _storage.delete(key: AppConstants.keyUserId);
    await _storage.delete(key: AppConstants.keyUserRole);
  }

  /// Get stored auth token
  Future<String?> getToken() async {
    return await _storage.read(key: AppConstants.keyAuthToken);
  }

  /// Get stored user ID
  Future<String?> getUserId() async {
    return await _storage.read(key: AppConstants.keyUserId);
  }

  /// Get stored user role
  Future<String?> getUserRole() async {
    return await _storage.read(key: AppConstants.keyUserRole);
  }

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    String? token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Get user role enum
  Future<UserRole?> getUserRoleEnum() async {
    String? role = await getUserRole();
    if (role == null) return null;

    try {
      return UserRole.fromJson(role);
    } catch (e) {
      return null;
    }
  }
}
