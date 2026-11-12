import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/activities/presentation/activities_page.dart';
import '../../features/activities/presentation/activity_detail_page.dart';
import '../../features/auth/presentation/auth_loading_page.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/services/session_storage.dart';
import '../../shared/widgets/app_header.dart';
import '../../features/auth/models/app_user.dart';
import '../../features/auth/presentation/forgot_password_page.dart';
import '../../features/communication/presentation/conversation_page.dart';
import '../../features/communication/presentation/conversations_page.dart';
import '../../features/communication/presentation/notice_detail_page.dart';
import '../../features/communication/presentation/notice_form_page.dart';
import '../../features/communication/presentation/notices_page.dart';
import '../../features/communication/presentation/notifications_page.dart';
import '../../features/grades/presentation/grades_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/student/presentation/student_academic_page.dart';
import '../../features/student/presentation/student_dashboard_page.dart';
import '../../features/teacher/presentation/create_activity_page.dart';
import '../../features/teacher/presentation/teacher_activities_page.dart';
import '../../features/teacher/presentation/teacher_dashboard_page.dart';
import '../../features/teacher/presentation/teacher_grades_page.dart';
import '../../features/teacher/providers/teacher_offering_selection.dart';
import '../../features/teacher/widgets/teacher_offering_link.dart';
import '../constants/app_routes.dart';
import 'app_route_transition_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterRefreshNotifier(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: AppRoutes.authLoading,
    refreshListenable: notifier,
    redirect: (_, state) => notifier.redirect(state.uri),
    errorBuilder: (_, state) => Scaffold(
      appBar: AppHeader(
        title: 'Destino indisponível',
        fallbackRoute: _home(ref.read(authControllerProvider).role),
      ),
      body: const Center(child: Text('Não foi possível abrir esse endereço.')),
    ),
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
          child: const ChatEntryPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.conversation,
        pageBuilder: (_, state) => AppRouteTransitionPage.slideFromRight(
          key: state.pageKey,
          child: ConversationPage(conversationId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: AppRoutes.teacherConversation,
        pageBuilder: (_, state) => AppRouteTransitionPage.slideFromRight(
          key: state.pageKey,
          child: ConversationPage(conversationId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: AppRoutes.notices,
        pageBuilder: (_, state) => AppRouteTransitionPage.slideFromRight(
          key: state.pageKey,
          child: const NoticesPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.noticeNew,
        pageBuilder: (_, state) => AppRouteTransitionPage.slideFromBottom(
          key: state.pageKey,
          child: const NoticeFormPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.noticeDetails,
        pageBuilder: (_, state) => AppRouteTransitionPage.slideFromRight(
          key: state.pageKey,
          child: NoticeDetailPage(noticeId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        pageBuilder: (_, state) => AppRouteTransitionPage.slideFromRight(
          key: state.pageKey,
          child: const NotificationsPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        pageBuilder: (_, state) => AppRouteTransitionPage.fade(
          key: state.pageKey,
          child: const ForgotPasswordPage(),
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
        path: AppRoutes.academic,
        pageBuilder: (_, state) => AppRouteTransitionPage.slideFromRight(
          key: state.pageKey,
          child: const StudentAcademicPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.teacherActivities,
        onExit: (_, __) {
          if (!ref.read(authControllerProvider).isAuthenticated) return true;
          final guard = ref.read(teacherDraftGuardProvider);
          return (guard.confirmReviewExit ?? guard.confirmWorkExit)?.call() ??
              true;
        },
        pageBuilder: (_, state) => AppRouteTransitionPage.slideFromRight(
          key: state.pageKey,
          child: TeacherOfferingLink(
            classId: _linkedClassId(state.uri),
            child: const TeacherActivitiesPage(),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.teacherChat,
        pageBuilder: (_, state) => AppRouteTransitionPage.slideFromRight(
          key: state.pageKey,
          child: const ChatEntryPage(isTeacher: true),
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
          child: TeacherOfferingLink(
            classId: _linkedClassId(state.uri),
            child: const TeacherDashboardPage(),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.teacherCreateActivity,
        onExit: (_, __) {
          if (!ref.read(authControllerProvider).isAuthenticated) return true;
          return ref.read(teacherDraftGuardProvider).confirmExit?.call() ??
              true;
        },
        pageBuilder: (context, state) => AppRouteTransitionPage.slideFromBottom(
          key: state.pageKey,
          child: TeacherOfferingLink(
            classId: _linkedClassId(state.uri),
            child: const CreateActivityPage(),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.teacherGrades,
        onExit: (_, __) {
          if (!ref.read(authControllerProvider).isAuthenticated) return true;
          return ref.read(teacherDraftGuardProvider).canExitNotes?.call() ??
              true;
        },
        pageBuilder: (context, state) => AppRouteTransitionPage.slideFromBottom(
          key: state.pageKey,
          child: TeacherOfferingLink(
            classId: _linkedClassId(state.uri),
            child: TeacherGradesPage(
              openExams: state.uri.queryParameters['modo'] == 'provas',
            ),
          ),
        ),
      ),
    ],
  );
});

String? _linkedClassId(Uri uri) {
  final ids = uri.queryParametersAll['classId'];
  if (ids == null) return null;
  return ids.length == 1 ? ids.single : '';
}

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(this._ref)
      : _controller = _ref.read(authControllerProvider.notifier) {
    _controller.renewal.addListener(_onRenewalChanged);
    var logout = _controller.logoutGeneration;
    _subscription = _ref.listen<AuthState>(authControllerProvider, (_, __) {
      if (logout != _controller.logoutGeneration) {
        logout = _controller.logoutGeneration;
        _destination = null;
        _discardCurrentLocation = true;
      }
      notifyListeners();
    });
  }

  final Ref _ref;
  final AuthController _controller;
  late final ProviderSubscription<AuthState> _subscription;
  Uri? _destination;
  Uri? _lastAuthorized;
  bool _discardCurrentLocation = false;

  void _onRenewalChanged() {
    if (_ref.read(authControllerProvider).isAuthenticated) notifyListeners();
  }

  String? redirect(Uri uri) {
    final auth = _ref.read(authControllerProvider);
    final path = uri.path;
    final renewing = _controller.renewal.value != SessionRenewal.idle;
    final isProtected =
        !uri.hasScheme && !uri.hasAuthority && _isProtectedPath(path);
    final discard = _discardCurrentLocation;
    _discardCurrentLocation = false;
    if (auth.isRestoring || !auth.isAuthenticated) {
      if (!discard &&
          isProtected &&
          (_destination == null || uri != _lastAuthorized)) {
        _destination = uri;
      }
      _lastAuthorized = null;
      return computeRedirect(
        isRestoring: auth.isRestoring,
        isAuthenticated: false,
        userRole: null,
        location: path,
      );
    }

    if (renewing) {
      if (isProtected && uri != _lastAuthorized) _destination = uri;
      final current = _lastAuthorized ?? Uri(path: AppRoutes.authLoading);
      return uri == current ? null : current.toString();
    }

    if (_destination != null ||
        path == AppRoutes.login ||
        path == AppRoutes.authLoading) {
      final destination = _destination;
      _destination = null;
      if (destination != null) {
        if (!_allowedForRole(destination.path, auth.role!)) {
          final home = _home(auth.role);
          return path == home ? null : home;
        }
        if (destination != uri) return destination.toString();
      }
    }
    final redirect = computeRedirect(
      isRestoring: false,
      isAuthenticated: true,
      userRole: auth.role,
      location: path,
    );
    if (redirect == null && isProtected) _lastAuthorized = uri;
    return redirect;
  }

  @override
  void dispose() {
    _controller.renewal.removeListener(_onRenewalChanged);
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
  if (isRestoring) {
    return location == AppRoutes.authLoading ? null : AppRoutes.authLoading;
  }
  if (!isAuthenticated || userRole == null) {
    return location == AppRoutes.login || location == AppRoutes.forgotPassword
        ? null
        : AppRoutes.login;
  }
  if (location == AppRoutes.login ||
      location == AppRoutes.authLoading ||
      location == AppRoutes.forgotPassword ||
      (_isProtectedPath(location) && !_allowedForRole(location, userRole))) {
    return _home(userRole);
  }
  return null;
}

String _home(UserRole? role) => switch (role) {
      UserRole.teacher => AppRoutes.teacherDashboard,
      UserRole.student => AppRoutes.studentDashboard,
      null => AppRoutes.login,
    };

bool _isProtectedPath(String path) =>
    _allowedForRole(path, UserRole.student) ||
    _allowedForRole(path, UserRole.teacher);

bool _allowedForRole(String path, UserRole role) {
  if (_sharedRoutes.contains(path) || _noticeDetail.hasMatch(path)) {
    return true;
  }
  return switch (role) {
    UserRole.student => _studentRoutes.contains(path) ||
        _studentActivityDetail.hasMatch(path) ||
        _studentConversation.hasMatch(path),
    UserRole.teacher =>
      _teacherRoutes.contains(path) || _teacherConversation.hasMatch(path),
  };
}

final _studentActivityDetail = RegExp(r'^/atividades/[^/]+/?$');
final _studentConversation = RegExp(r'^/chat/[^/]+/?$');
final _teacherConversation = RegExp(r'^/professor/chat/[^/]+/?$');

/// Any notice except the `novo` form, which only teachers open.
final _noticeDetail = RegExp(r'^/avisos/(?!novo/?$)[^/]+/?$');

const _sharedRoutes = {
  AppRoutes.profile,
  AppRoutes.notices,
  AppRoutes.notifications,
};

const _studentRoutes = {
  AppRoutes.studentDashboard,
  AppRoutes.activities,
  AppRoutes.chat,
  AppRoutes.grades,
  AppRoutes.academic,
};

const _teacherRoutes = {
  AppRoutes.teacherDashboard,
  AppRoutes.teacherActivities,
  AppRoutes.teacherCreateActivity,
  AppRoutes.teacherGrades,
  AppRoutes.teacherChat,
  AppRoutes.noticeNew,
};
