enum UserRole { student, teacher }

class AppUser {
  const AppUser({
    required this.name,
    required this.email,
    required this.role,
    this.course,
    this.registration,
    this.semester,
  });

  final String name;
  final String email;
  final UserRole role;
  final String? course;
  final String? registration;
  final int? semester;
}
