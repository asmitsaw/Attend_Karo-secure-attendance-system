class ApiEndpoints {
  // Base URL - Use 10.0.2.2 for Android emulator to connect to localhost
  static const String baseUrl = 'http://10.0.2.2:5000/api';

  // Authentication
  static const String login = '$baseUrl/auth/login';
  static const String logout = '$baseUrl/auth/logout';

  // Faculty Endpoints
  static const String createClass = '$baseUrl/faculty/class/create';
  static const String uploadStudents = '$baseUrl/faculty/class/students';
  static const String startSession = '$baseUrl/faculty/session/start';
  static const String endSession = '$baseUrl/faculty/session/end';
  static const String getLiveCount = '$baseUrl/faculty/session/live-count';
  static const String getAnalytics = '$baseUrl/faculty/analytics';

  // Student Endpoints
  static const String getEnrolledClasses = '$baseUrl/student/classes';
  static const String markAttendance = '$baseUrl/student/attendance/mark';
  static const String getAttendanceHistory =
      '$baseUrl/student/attendance/history';

  // Common
  static const String getProfile = '$baseUrl/user/profile';
}
