import 'package:flutter_test/flutter_test.dart';
import 'package:uniconnect/core/constants/app_routes.dart';
import 'package:uniconnect/core/router/app_router.dart';
import 'package:uniconnect/features/auth/models/app_user.dart';

void main() {
  test('sessao em restauracao nao redireciona', () {
    final redirect = computeRedirect(
      isRestoring: true,
      isAuthenticated: false,
      userRole: null,
      location: AppRoutes.studentDashboard,
    );

    expect(redirect, isNull);
  });

  test('nao autenticado em rota privada vai para login', () {
    final redirect = computeRedirect(
      isRestoring: false,
      isAuthenticated: false,
      userRole: null,
      location: AppRoutes.studentDashboard,
    );

    expect(redirect, AppRoutes.login);
  });

  test('nao autenticado em login nao redireciona', () {
    final redirect = computeRedirect(
      isRestoring: false,
      isAuthenticated: false,
      userRole: null,
      location: AppRoutes.login,
    );

    expect(redirect, isNull);
  });

  test('aluno tentando dashboard professor volta para dashboard aluno', () {
    final redirect = computeRedirect(
      isRestoring: false,
      isAuthenticated: true,
      userRole: UserRole.student,
      location: AppRoutes.teacherDashboard,
    );

    expect(redirect, AppRoutes.studentDashboard);
  });

  test('aluno tentando criar atividade de professor e bloqueado', () {
    final redirect = computeRedirect(
      isRestoring: false,
      isAuthenticated: true,
      userRole: UserRole.student,
      location: AppRoutes.teacherCreateActivity,
    );

    expect(redirect, AppRoutes.studentDashboard);
  });

  test('aluno em rota de aluno nao redireciona', () {
    final redirect = computeRedirect(
      isRestoring: false,
      isAuthenticated: true,
      userRole: UserRole.student,
      location: AppRoutes.studentDashboard,
    );

    expect(redirect, isNull);
  });

  test('professor autenticado em login vai para dashboard professor', () {
    final redirect = computeRedirect(
      isRestoring: false,
      isAuthenticated: true,
      userRole: UserRole.teacher,
      location: AppRoutes.login,
    );

    expect(redirect, AppRoutes.teacherDashboard);
  });

  test('professor em rota de professor nao redireciona', () {
    final redirect = computeRedirect(
      isRestoring: false,
      isAuthenticated: true,
      userRole: UserRole.teacher,
      location: AppRoutes.teacherDashboard,
    );

    expect(redirect, isNull);
  });
}
