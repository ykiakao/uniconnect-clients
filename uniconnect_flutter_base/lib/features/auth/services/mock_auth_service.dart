import '../models/app_user.dart';
import '../../tenant/models/tenant_context.dart';

class MockAuthService {
  static const _demoTenant = TenantContext(
    id: 'tenant_universidade_norte',
    name: 'Universidade Norte',
    slug: 'universidade-norte',
    plan: SubscriptionPlan.growth,
    status: SubscriptionStatus.trialing,
    activeUsers: 384,
  );

  AppUser login(String email) {
    final normalizedEmail = email.trim().toLowerCase();

    if (normalizedEmail == 'professor@uni.com') {
      return const AppUser(
        id: 'user_teacher_marina',
        name: 'Marina Costa',
        email: 'professor@uni.com',
        role: UserRole.teacher,
        tenant: _demoTenant,
        course: 'Engenharia de Software',
      );
    }

    return const AppUser(
      id: 'user_student_lucas',
      name: 'Lucas Oliveira',
      email: 'aluno@uni.com',
      role: UserRole.student,
      tenant: _demoTenant,
      course: 'Engenharia de Software',
      registration: '2024021845',
      semester: 4,
    );
  }
}
