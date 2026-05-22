import '../models/app_user.dart';

class MockAuthService {
  AppUser login(String email) {
    final normalizedEmail = email.trim().toLowerCase();

    if (normalizedEmail == 'professor@uni.com') {
      return const AppUser(
        name: 'Marina Costa',
        email: 'professor@uni.com',
        role: UserRole.teacher,
        course: 'Engenharia de Software',
      );
    }

    return const AppUser(
      name: 'Lucas Oliveira',
      email: 'aluno@uni.com',
      role: UserRole.student,
      course: 'Engenharia de Software',
      registration: '2024021845',
      semester: 4,
    );
  }
}
