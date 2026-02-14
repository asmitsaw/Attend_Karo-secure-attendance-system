class ApiEndpoints {
  // 1. For Production: Replace defaultValue with your Cloud URL (e.g., https://my-app.onrender.com/api)
  // 2. For Testing: Run with: flutter run --dart-define=API_URL=http://YOUR_IP:5000/api
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://192.168.1.101:5000/api',
  );

  // Authentication
  static const String login = '$baseUrl/auth/login';
  static const String logout = '$baseUrl/auth/logout';

  // Admin Endpoints
  static const String uploadStudentBatch = '$baseUrl/admin/students/upload';
  static const String getBatches = '$baseUrl/admin/batches';
  static const String updateBatch = '$baseUrl/admin/batch'; // append /:id
  static const String downloadCredentials =
      '$baseUrl/admin/batch'; // append /:id/credentials
  static const String regenerateCredentials =
      '$baseUrl/admin/batch'; // append /:id/regenerate

  // Faculty Endpoints
  static const String getFacultyBatches = '$baseUrl/faculty/batches';
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
