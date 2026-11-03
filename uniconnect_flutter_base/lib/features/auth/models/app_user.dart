import '../../tenant/models/tenant_context.dart';

enum UserRole { student, teacher }

class UnsupportedUserRole implements Exception {
  const UnsupportedUserRole({required this.administrative});

  final bool administrative;

  String get message => administrative
      ? 'Use o painel web para acessar sua conta administrativa.'
      : 'Este perfil não é compatível com o aplicativo.';
}

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.tenant,
    this.course,
    this.registration,
    this.semester,
  });

  final String id;
  final String name;
  final String email;
  final UserRole role;
  final TenantContext tenant;
  final String? course;
  final String? registration;
  final int? semester;

  factory AppUser.fromJson(
    Map<String, dynamic> json, {
    required TenantContext tenant,
  }) {
    return AppUser(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      role: UserRoleX.fromApi(json['role'] as String),
      tenant: tenant,
      course: json['course'] as String?,
      registration: json['registration'] as String?,
      semester: json['semester'] as int?,
    );
  }

  String get roleLabel {
    return switch (role) {
      UserRole.student => 'Aluno',
      UserRole.teacher => 'Professor',
    };
  }
}

extension UserRoleX on UserRole {
  static UserRole fromApi(String value) {
    return switch (value) {
      'aluno' || 'student' => UserRole.student,
      'teacher' || 'professor' => UserRole.teacher,
      'gestor' ||
      'admin' ||
      'coordinator' ||
      'owner' =>
        throw const UnsupportedUserRole(administrative: true),
      _ => throw const UnsupportedUserRole(administrative: false),
    };
  }
}
