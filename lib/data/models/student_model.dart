class StudentModel {
  final String id;
  final String rollNumber;
  final String name;
  final String username;
  final String? email;
  final String? deviceId;

  StudentModel({
    required this.id,
    required this.rollNumber,
    required this.name,
    required this.username,
    this.email,
    this.deviceId,
  });

  factory StudentModel.fromJson(Map<String, dynamic> json) {
    return StudentModel(
      id: json['id'] as String,
      rollNumber: json['roll_number'] as String,
      name: json['name'] as String,
      username: json['username'] as String,
      email: json['email'] as String?,
      deviceId: json['device_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'roll_number': rollNumber,
      'name': name,
      'username': username,
      'email': email,
      'device_id': deviceId,
    };
  }
}
