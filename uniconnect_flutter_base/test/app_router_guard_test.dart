import 'package:flutter_test/flutter_test.dart';
import 'package:uniconnect/core/constants/app_routes.dart';
import 'package:uniconnect/core/router/app_router.dart';
import 'package:uniconnect/features/auth/models/app_user.dart';

void main() {
  test('all registered routes enforce the navigation roles', () {
    const studentOnly = [
      AppRoutes.studentDashboard,
      AppRoutes.activities,
      '/atividades/activity-1',
      AppRoutes.chat,
      AppRoutes.grades,
      AppRoutes.academic,
    ];
    const teacherOnly = [
      AppRoutes.teacherDashboard,
      AppRoutes.teacherActivities,
      AppRoutes.teacherChat,
      AppRoutes.teacherCreateActivity,
      AppRoutes.teacherGrades,
    ];
    for (final path in [...studentOnly, ...teacherOnly, AppRoutes.profile]) {
      expect(
        computeRedirect(
          isRestoring: false,
          isAuthenticated: false,
          userRole: null,
          location: path,
        ),
        AppRoutes.login,
        reason: path,
      );
      for (final role in UserRole.values) {
        final otherRole = role == UserRole.teacher
            ? studentOnly.contains(path)
            : teacherOnly.contains(path);
        expect(
          computeRedirect(
            isRestoring: false,
            isAuthenticated: true,
            userRole: role,
            location: path,
          ),
          otherRole
              ? role == UserRole.teacher
                  ? AppRoutes.teacherDashboard
                  : AppRoutes.studentDashboard
              : null,
          reason: '${role.name} at $path',
        );
      }
    }
  });

  test('authenticated routing requires an explicit supported role', () {
    expect(
        computeRedirect(
          isRestoring: false,
          isAuthenticated: true,
          userRole: null,
          location: AppRoutes.studentDashboard,
        ),
        AppRoutes.login);
  });
  test('professor cannot enter concrete student activity detail routes', () {
    expect(
      computeRedirect(
        isRestoring: false,
        isAuthenticated: true,
        userRole: UserRole.teacher,
        location: '/atividades/activity-1',
      ),
      AppRoutes.teacherDashboard,
    );
  });
  test('sessao em restauracao redireciona para a tela neutra', () {
    final redirect = computeRedirect(
      isRestoring: true,
      isAuthenticated: false,
      userRole: null,
      location: AppRoutes.studentDashboard,
    );

    expect(redirect, AppRoutes.authLoading);
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

  test('professor em rota de aluno vai para dashboard professor', () {
    final redirect = computeRedirect(
      isRestoring: false,
      isAuthenticated: true,
      userRole: UserRole.teacher,
      location: AppRoutes.studentDashboard,
    );

    expect(redirect, AppRoutes.teacherDashboard);
  });

  test('recovery is public and the notice form is only for teachers', () {
    expect(
        computeRedirect(
          isRestoring: false,
          isAuthenticated: false,
          userRole: null,
          location: AppRoutes.forgotPassword,
        ),
        isNull);
    expect(
        computeRedirect(
          isRestoring: false,
          isAuthenticated: true,
          userRole: UserRole.student,
          location: AppRoutes.noticeNew,
        ),
        AppRoutes.studentDashboard);
    for (final role in UserRole.values) {
      for (final path in [
        AppRoutes.notices,
        '/avisos/notice-1',
        AppRoutes.notifications,
      ]) {
        expect(
            computeRedirect(
              isRestoring: false,
              isAuthenticated: true,
              userRole: role,
              location: path,
            ),
            isNull,
            reason: '$role $path');
      }
    }
  });
}
