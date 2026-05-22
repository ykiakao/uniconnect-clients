import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/activities/presentation/activities_page.dart';
import '../../features/activities/presentation/activity_detail_page.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/chat/presentation/chat_page.dart';
import '../../features/grades/presentation/grades_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/student/presentation/student_dashboard_page.dart';
import '../../features/teacher/presentation/create_activity_page.dart';
import '../../features/teacher/presentation/teacher_dashboard_page.dart';
import '../../features/teacher/presentation/teacher_grades_page.dart';
import '../constants/app_routes.dart';
import 'app_route_transition_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
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
