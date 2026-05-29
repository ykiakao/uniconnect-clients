import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/activities/presentation/activities_page.dart';
import '../../features/activities/presentation/activity_detail_page.dart';
import '../../features/auth/presentation/auth_loading_page.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/services/session_storage.dart';
import '../../features/auth/models/app_user.dart';
import '../../features/chat/presentation/chat_page.dart';
import '../../features/grades/presentation/grades_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/student/presentation/student_dashboard_page.dart';
import '../../features/teacher/presentation/create_activity_page.dart';
import '../../features/teacher/presentation/teacher_dashboard_page.dart';
import '../../features/teacher/presentation/teacher_grades_page.dart';
import '../constants/app_routes.dart';
import 'app_route_transition_page.dart';

// === Mapeamento de rotas ===
// Rotas atuais:
// - /loading: tela temporaria durante restore de sessao.
// - /login: login institucional.
// - /aluno: dashboard do aluno.
// - /atividades: lista de atividades do aluno.
// - /atividades/:id: detalhe de atividade.
// - /chat: chat academico.
// - /notas: notas do aluno.
// - /perfil: perfil do usuario.
// - /professor: dashboard do professor.
// - /professor/criar-atividade: criacao de atividade.
// - /professor/notas: notas do professor.
//
// Redirect anterior:
// - restaurando sessao redirecionava para /loading;
// - nao autenticado redirecionava para /login;
// - autenticado em /login ou /loading ia para dashboard por role;
// - nao havia bloqueio de aluno em rotas /professor.
//
// Estados considerados:
// - AuthState.isRestoring
// - AuthState.user == null
// - UserRole.teacher vs demais perfis tratados como aluno
//
// Guard de perfil:
// - implementado em computeRedirect para bloquear /professor para aluno.

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterRefreshNotifier(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: AppRoutes.authLoading,
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      return computeRedirect(
        isRestoring: authState.isRestoring,
        isAuthenticated: authState.isAuthenticated,
        userRole: authState.user?.role,
        location: state.matchedLocation,
      );
    },
    routes: [
      GoRoute(
        path: AppRoutes.authLoading,
        pageBuilder: (context, state) => AppRouteTransitionPage.fade(
          key: state.pageKey,
          child: const AuthLoadingPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (context, state) => AppRouteTransitionPage.fade(
          key: state.pageKey,
          child: const LoginPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.studentDashboard,
        pageBuilder: (context, state) => AppRouteTransitionPage.slideFromRight(
          key: state.pageKey,
          child: const StudentDashboardPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.activities,
        pageBuilder: (context, state) => AppRouteTransitionPage.slideFromRight(
          key: state.pageKey,
          child: const ActivitiesPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.activityDetails,
        pageBuilder: (context, state) => AppRouteTransitionPage.slideFromBottom(
          key: state.pageKey,
          child: ActivityDetailPage(activityId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: AppRoutes.chat,
        pageBuilder: (context, state) => AppRouteTransitionPage.slideFromRight(
          key: state.pageKey,
          child: const ChatPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.grades,
        pageBuilder: (context, state) => AppRouteTransitionPage.slideFromRight(
          key: state.pageKey,
          child: const GradesPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.profile,
        pageBuilder: (context, state) => AppRouteTransitionPage.slideFromRight(
          key: state.pageKey,
          child: const ProfilePage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.teacherDashboard,
        pageBuilder: (context, state) => AppRouteTransitionPage.slideFromRight(
          key: state.pageKey,
          child: const TeacherDashboardPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.teacherCreateActivity,
        pageBuilder: (context, state) => AppRouteTransitionPage.slideFromBottom(
          key: state.pageKey,
          child: const CreateActivityPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.teacherGrades,
        pageBuilder: (context, state) => AppRouteTransitionPage.slideFromBottom(
          key: state.pageKey,
          child: const TeacherGradesPage(),
        ),
      ),
    ],
  );
});

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(this._ref) {
    _subscription = _ref.listen<AuthState>(
      authControllerProvider,
      (_, __) => notifyListeners(),
    );
  }

  final Ref _ref;
  late final ProviderSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}

String? computeRedirect({
  required bool isRestoring,
  required bool isAuthenticated,
  required UserRole? userRole,
  required String location,
}) {
  final isLogin = location == AppRoutes.login;

  if (isRestoring) return null;

  if (!isAuthenticated) {
    return isLogin ? null : AppRoutes.login;
  }

  final isLoading = location == AppRoutes.authLoading;
  final isTeacherRoute = location.startsWith(AppRoutes.teacherDashboard);
  final isStudentRoute = _studentOnlyRoutes.contains(location);

  // TODO(produto): adicionar guard para perfil gestor/admin quando definido.
  return switch (userRole) {
    UserRole.teacher when isLogin || isLoading || isStudentRoute =>
      AppRoutes.teacherDashboard,
    UserRole.student when isLogin || isLoading => AppRoutes.studentDashboard,
    UserRole.student when isTeacherRoute => AppRoutes.studentDashboard,
    _ => null,
  };
}

const _studentOnlyRoutes = {
  AppRoutes.studentDashboard,
  AppRoutes.activities,
  AppRoutes.chat,
  AppRoutes.grades,
};
