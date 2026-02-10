class ClassModel {
  final String id;
  final String subject;
  final String department;
  final int semester;
  final String section;
  final String facultyId;
  final String? facultyName;
  final DateTime createdAt;

  ClassModel({
    required this.id,
    required this.subject,
    required this.department,
    required this.semester,
    required this.section,
    required this.facultyId,
    this.facultyName,
    required this.createdAt,
  });

  factory ClassModel.fromJson(Map<String, dynamic> json) {
    return ClassModel(
      id: json['id'] as String,
      subject: json['subject'] as String,
      department: json['department'] as String,
      semester: json['semester'] as int,
      section: json['section'] as String,
      facultyId: json['faculty_id'] as String,
      facultyName: json['faculty_name'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subject': subject,
      'department': department,
      'semester': semester,
      'section': section,
      'faculty_id': facultyId,
      'faculty_name': facultyName,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
