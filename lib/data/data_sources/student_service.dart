import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/constants/app_constants.dart';

class StudentService {
  final Dio _dio = Dio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  StudentService() {
    _dio.options.baseUrl = ApiEndpoints.baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
  }

  Future<Map<String, dynamic>> markAttendance({
    required String sessionId,
    required String qrData,
    required String deviceId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final token = await _storage.read(key: AppConstants.keyAuthToken);

      final response = await _dio.post(
        ApiEndpoints.markAttendance,
        data: {
          'session_id': sessionId,
          'qr_data': qrData,
          'device_id': deviceId,
          'latitude': latitude,
          'longitude': longitude,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      return {'success': true, 'message': response.data['message']};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Network Error: ${e.message}',
      };
    } catch (e) {
      return {'success': false, 'message': 'Unknown Error: $e'};
    }
  }
}
