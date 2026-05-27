import 'dart:async';

import 'package:uniconnect/core/network/api_client.dart';
import 'package:uniconnect/features/auth/models/app_user.dart';
import 'package:uniconnect/features/auth/services/api_auth_service.dart';
import 'package:uniconnect/features/tenant/models/tenant_context.dart';

const fakeTenant = TenantContext(
  id: 'tenant-test',
  name: 'Instituicao Teste',
  slug: 'instituicao-teste',
  plan: SubscriptionPlan.growth,
  status: SubscriptionStatus.trialing,
  activeUsers: 12,
);

const fakeStudent = AppUser(
  id: 'student-test',
  name: 'Aluno Teste',
  email: 'aluno.teste@uni.com',
  role: UserRole.student,
  tenant: fakeTenant,
);

const fakeTeacher = AppUser(
  id: 'teacher-test',
  name: 'Professor Teste',
  email: 'professor.teste@uni.com',
  role: UserRole.teacher,
  tenant: fakeTenant,
);

class FakeAuthService extends ApiAuthService {
  FakeAuthService({
    this.loginResult,
    this.loginError,
    this.meResult = fakeStudent,
    this.meError,
    this.loginCompleter,
  }) : super(ApiClient());

  final AuthSession? loginResult;
  final Object? loginError;
  final AppUser meResult;
  final Object? meError;
  final Completer<AuthSession>? loginCompleter;
  int loginCalls = 0;
  int meCalls = 0;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    loginCalls++;

    if (loginCompleter != null) return loginCompleter!.future;
    if (loginError != null) throw loginError!;

    return loginResult ??
        const AuthSession(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
          expiresAt: 4102444800,
          user: fakeStudent,
        );
  }

  @override
  Future<AppUser> me(String accessToken) async {
    meCalls++;
    if (meError != null) throw meError!;
    return meResult;
  }
}
