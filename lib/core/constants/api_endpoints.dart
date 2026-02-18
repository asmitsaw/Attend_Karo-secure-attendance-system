class ApiEndpoints {
  // 1. For Production: Replace defaultValue with your Cloud URL (e.g., https://my-app.onrender.com/api)
  // 2. For Testing: Run with: flutter run --dart-define=API_URL=http://YOUR_IP:5000/api
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://attend-karo-backend.onrender.com/api',
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
  static const String getDeviceRequests = '$baseUrl/admin/device-requests';
  static const String getSystemStats = '$baseUrl/admin/system-stats';
  static String approveDeviceRequest(String requestId) =>
      '$baseUrl/admin/device-requests/$requestId';

  // Faculty Endpoints
  static const String getFacultyBatches = '$baseUrl/faculty/batches';
  static const String getFacultyClasses = '$baseUrl/faculty/classes';
  static const String createClass = '$baseUrl/faculty/class/create';
  static const String uploadStudents = '$baseUrl/faculty/class/students';
  static const String startSession = '$baseUrl/faculty/session/start';
  static const String endSession = '$baseUrl/faculty/session/end';
  static const String getLiveCount = '$baseUrl/faculty/session/live-count';
  static const String getAnalytics = '$baseUrl/faculty/analytics';
  static const String getClassStudents =
      '$baseUrl/faculty/class'; // append /:classId/students
  static const String scheduleLecture = '$baseUrl/faculty/lectures/schedule';
  static const String getFacultyLectures = '$baseUrl/faculty/lectures';
  static const String getFacultyLiveSessions = '$baseUrl/faculty/sessions/live';
  static const String getFacultySessionHistory =
      '$baseUrl/faculty/sessions/history';
  static String deleteLecture(String lectureId) =>
      '$baseUrl/faculty/lectures/$lectureId';
  static String getStudentAttendanceDetail(String classId, String studentId) =>
      '$baseUrl/faculty/class/$classId/student/$studentId/attendance';

  // Student Endpoints
  static const String getEnrolledClasses = '$baseUrl/student/classes';
  static const String markAttendance = '$baseUrl/student/attendance/mark';
  static const String getAttendanceHistory =
      '$baseUrl/student/attendance/history';
  static const String getAttendanceReport =
      '$baseUrl/student/attendance/report';
  static const String getStudentSchedule = '$baseUrl/student/schedule';
  static const String getStudentLiveSessions = '$baseUrl/student/sessions/live';
  static const String getStudentProfile = '$baseUrl/student/profile';
  static const String requestDeviceChange =
      '$baseUrl/student/device/change-request';

  // Common
  static const String getProfile = '$baseUrl/user/profile';
}
