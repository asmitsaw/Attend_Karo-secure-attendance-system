import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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

  Future<Options> _authOptions() async {
    final token = await _storage.read(key: AppConstants.keyAuthToken);
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<Map<String, dynamic>> markAttendance({
    required String sessionId,
    required String qrData,
    required String deviceId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.markAttendance,
        data: {
          'session_id': sessionId,
          'qr_data': qrData,
          'device_id': deviceId,
          'latitude': latitude,
          'longitude': longitude,
        },
        options: await _authOptions(),
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

  /// Get scheduled lectures for student's enrolled classes
  Future<List<Map<String, dynamic>>> getSchedule() async {
    try {
      final response = await _dio.get(
        ApiEndpoints.getStudentSchedule,
        options: await _authOptions(),
      );
      debugPrint('Schedule response: ${response.data}');
      return List<Map<String, dynamic>>.from(response.data['lectures'] ?? []);
    } catch (e) {
      debugPrint('getSchedule error: $e');
      return [];
    }
  }

  /// Get live sessions for student's enrolled classes
  Future<List<Map<String, dynamic>>> getLiveSessions() async {
    try {
      final response = await _dio.get(
        ApiEndpoints.getStudentLiveSessions,
        options: await _authOptions(),
      );
      return List<Map<String, dynamic>>.from(response.data['sessions'] ?? []);
    } catch (e) {
      return [];
    }
  }

  /// Get attendance history
  Future<List<Map<String, dynamic>>> getAttendanceHistory() async {
    try {
      final response = await _dio.get(
        ApiEndpoints.getAttendanceHistory,
        options: await _authOptions(),
      );
      return List<Map<String, dynamic>>.from(response.data['records'] ?? []);
    } catch (e) {
      return [];
    }
  }

  /// Get enrolled classes
  Future<List<Map<String, dynamic>>> getEnrolledClasses() async {
    try {
      final response = await _dio.get(
        ApiEndpoints.getEnrolledClasses,
        options: await _authOptions(),
      );
      return List<Map<String, dynamic>>.from(response.data['classes'] ?? []);
    } catch (e) {
      return [];
    }
  }

  /// Get attendance report (class-wise + overall)
  Future<Map<String, dynamic>> getAttendanceReport() async {
    try {
      final response = await _dio.get(
        ApiEndpoints.getAttendanceReport,
        options: await _authOptions(),
      );
      return response.data;
    } catch (e) {
      return {
        'classes': [],
        'overall': {
          'total_sessions': 0,
          'present': 0,
          'absent': 0,
          'late': 0,
          'percentage': 0,
        },
      };
    }
  }

  /// Get student profile
  Future<Map<String, dynamic>?> getProfile() async {
    try {
      final response = await _dio.get(
        ApiEndpoints.getStudentProfile,
        options: await _authOptions(),
      );
      return response.data['profile'];
    } catch (e) {
      return null;
    }
  }

  /// Request device change
  Future<Map<String, dynamic>> requestDeviceChange(String reason) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.requestDeviceChange,
        data: {'reason': reason},
        options: await _authOptions(),
      );
      return {'success': true, 'message': response.data['message']};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Network Error',
      };
    } catch (e) {
      return {'success': false, 'message': 'Unknown Error: $e'};
    }
  }
}
