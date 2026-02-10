class AttendanceRecord {
  final String id;
  final String sessionId;
  final String studentId;
  final String studentName;
  final DateTime markedAt;
  final String status; // 'PRESENT', 'ABSENT', 'LATE'
  final String? deviceId;
  final double? latitude;
  final double? longitude;

  AttendanceRecord({
    required this.id,
    required this.sessionId,
    required this.studentId,
    required this.studentName,
    required this.markedAt,
    required this.status,
    this.deviceId,
    this.latitude,
    this.longitude,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'] as String,
      sessionId: json['session_id'] as String,
      studentId: json['student_id'] as String,
      studentName: json['student_name'] as String,
      markedAt: DateTime.parse(json['marked_at'] as String),
      status: json['status'] as String,
      deviceId: json['device_id'] as String?,
      latitude: json['latitude'] != null
          ? (json['latitude'] as num).toDouble()
          : null,
      longitude: json['longitude'] != null
          ? (json['longitude'] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'session_id': sessionId,
      'student_id': studentId,
      'student_name': studentName,
      'marked_at': markedAt.toIso8601String(),
      'status': status,
      'device_id': deviceId,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}
