import '../../tenant/models/tenant_context.dart';

enum UserRole { student, teacher }

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

  String get roleLabel {
    return switch (role) {
      UserRole.student => 'Aluno',
      UserRole.teacher => 'Professor',
    };
  }
}
