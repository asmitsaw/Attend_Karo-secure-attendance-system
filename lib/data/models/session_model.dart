class AttendanceSession {
  final String id;
  final String classId;
  final DateTime startTime;
  final DateTime? endTime;
  final double latitude;
  final double longitude;
  final int radius; // in meters
  final bool isActive;
  final String? qrData;

  AttendanceSession({
    required this.id,
    required this.classId,
    required this.startTime,
    this.endTime,
    required this.latitude,
    required this.longitude,
    required this.radius,
    required this.isActive,
    this.qrData,
  });

  factory AttendanceSession.fromJson(Map<String, dynamic> json) {
    return AttendanceSession(
      id: json['id'] as String,
      classId: json['class_id'] as String,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: json['end_time'] != null
          ? DateTime.parse(json['end_time'] as String)
          : null,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      radius: json['radius'] as int,
      isActive: json['is_active'] as bool,
      qrData: json['qr_data'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'class_id': classId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
      'is_active': isActive,
      'qr_data': qrData,
    };
  }
}
