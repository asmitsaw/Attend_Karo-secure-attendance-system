import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/constants/app_constants.dart';

class FacultyService {
  final Dio _dio = Dio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  FacultyService() {
    _dio.options.baseUrl = ApiEndpoints.baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
  }

  Future<Options> _authOptions() async {
    final token = await _storage.read(key: AppConstants.keyAuthToken);
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  /// Get classes for faculty
  Future<List<Map<String, dynamic>>> getClasses() async {
    try {
      final response = await _dio.get(
        ApiEndpoints.getFacultyClasses,
        options: await _authOptions(),
      );
      return List<Map<String, dynamic>>.from(response.data['classes'] ?? []);
    } catch (e) {
      return [];
    }
  }

  /// Get students for a specific class with attendance stats
  Future<List<Map<String, dynamic>>> getClassStudents(String classId) async {
    try {
      final response = await _dio.get(
        '${ApiEndpoints.getClassStudents}/$classId/students',
        options: await _authOptions(),
      );
      return List<Map<String, dynamic>>.from(response.data['students'] ?? []);
    } catch (e) {
      return [];
    }
  }

  /// Schedule a lecture
  Future<Map<String, dynamic>> scheduleLecture({
    required String classId,
    required String title,
    required String lectureDate,
    required String startTime,
    required String endTime,
    String? room,
    String? notes,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.scheduleLecture,
        data: {
          'classId': classId,
          'title': title,
          'lectureDate': lectureDate,
          'startTime': startTime,
          'endTime': endTime,
          if (room != null) 'room': room,
          if (notes != null) 'notes': notes,
        },
        options: await _authOptions(),
      );
      return {'success': true, 'lecture': response.data['lecture']};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Network error',
      };
    } catch (e) {
      return {'success': false, 'message': 'Unknown error: $e'};
    }
  }

  /// Get scheduled lectures
  Future<List<Map<String, dynamic>>> getScheduledLectures({
    String? date,
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.getFacultyLectures,
        queryParameters: date != null ? {'date': date} : null,
        options: await _authOptions(),
      );
      return List<Map<String, dynamic>>.from(response.data['lectures'] ?? []);
    } catch (e) {
      return [];
    }
  }

  /// Get live sessions
  Future<List<Map<String, dynamic>>> getLiveSessions() async {
    try {
      final response = await _dio.get(
        ApiEndpoints.getFacultyLiveSessions,
        options: await _authOptions(),
      );
      return List<Map<String, dynamic>>.from(response.data['sessions'] ?? []);
    } catch (e) {
      return [];
    }
  }

  /// Get session history
  Future<List<Map<String, dynamic>>> getSessionHistory() async {
    try {
      final response = await _dio.get(
        ApiEndpoints.getFacultySessionHistory,
        options: await _authOptions(),
      );
      return List<Map<String, dynamic>>.from(response.data['sessions'] ?? []);
    } catch (e) {
      return [];
    }
  }

  /// Delete a scheduled lecture
  Future<Map<String, dynamic>> deleteLecture(String lectureId) async {
    try {
      final response = await _dio.delete(
        ApiEndpoints.deleteLecture(lectureId),
        options: await _authOptions(),
      );
      return {'success': true, 'message': response.data['message']};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Network error',
      };
    } catch (e) {
      return {'success': false, 'message': 'Unknown error: $e'};
    }
  }

  /// Get student attendance detail for a specific class
  Future<Map<String, dynamic>?> getStudentAttendanceDetail(
    String classId,
    String studentId,
  ) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.getStudentAttendanceDetail(classId, studentId),
        options: await _authOptions(),
      );
      return response.data;
    } catch (e) {
      return null;
    }
  }

  /// Get analytics
  Future<Map<String, dynamic>> getAnalytics() async {
    try {
      final response = await _dio.get(
        ApiEndpoints.getAnalytics,
        options: await _authOptions(),
      );
      return response.data;
    } catch (e) {
      return {};
    }
  }
}
