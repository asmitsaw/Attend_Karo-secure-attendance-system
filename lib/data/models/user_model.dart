enum UserRole {
  faculty,
  student;

  String toJson() => name.toUpperCase();

  static UserRole fromJson(String json) {
    switch (json.toUpperCase()) {
      case 'FACULTY':
        return UserRole.faculty;
      case 'STUDENT':
        return UserRole.student;
      default:
        throw ArgumentError('Invalid role: $json');
    }
  }
}

class UserModel {
  final String id;
  final String username;
  final String name;
  final UserRole role;
  final String? department;
  final String? email;

  UserModel({
    required this.id,
    required this.username,
    required this.name,
    required this.role,
    this.department,
    this.email,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      username: json['username'] as String,
      name: json['name'] as String,
      role: UserRole.fromJson(json['role'] as String),
      department: json['department'] as String?,
      email: json['email'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'name': name,
      'role': role.toJson(),
      'department': department,
      'email': email,
    };
  }

  UserModel copyWith({
    String? id,
    String? username,
    String? name,
    UserRole? role,
    String? department,
    String? email,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      name: name ?? this.name,
      role: role ?? this.role,
      department: department ?? this.department,
      email: email ?? this.email,
    );
  }
}
