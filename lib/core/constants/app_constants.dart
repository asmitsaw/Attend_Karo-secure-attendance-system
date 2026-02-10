class AppConstants {
  // App Information
  static const String appName = 'Attend Karo';
  static const String appVersion = '1.0.0';

  // Geo-fencing
  static const double attendanceRadius = 30.0; // meters
  static const double locationAccuracyThreshold = 30.0; // meters

  // QR Code
  static const int qrValidityDuration = 10; // seconds
  static const int qrRefreshInterval = 10; // seconds

  // Session
  static const int minSessionDuration = 5; // minutes
  static const int maxSessionDuration = 10; // minutes

  // Storage Keys
  static const String keyAuthToken = 'auth_token';
  static const String keyUserId = 'user_id';
  static const String keyUserRole = 'user_role';
  static const String keyDeviceId = 'device_id';

  // User Roles
  static const String roleFaculty = 'FACULTY';
  static const String roleStudent = 'STUDENT';

  // Attendance Status
  static const String statusPresent = 'PRESENT';
  static const String statusAbsent = 'ABSENT';
  static const String statusLate = 'LATE';
}
