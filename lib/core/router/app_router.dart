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

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.studentDashboard,
        builder: (context, state) => const StudentDashboardPage(),
      ),
      GoRoute(
        path: AppRoutes.activities,
        builder: (context, state) => const ActivitiesPage(),
      ),
      GoRoute(
        path: AppRoutes.activityDetails,
        builder: (context, state) {
          return ActivityDetailPage(activityId: state.pathParameters['id']!);
        },
      ),
      GoRoute(
        path: AppRoutes.chat,
        builder: (context, state) => const ChatPage(),
      ),
      GoRoute(
        path: AppRoutes.grades,
        builder: (context, state) => const GradesPage(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        path: AppRoutes.teacherDashboard,
        builder: (context, state) => const TeacherDashboardPage(),
      ),
      GoRoute(
        path: AppRoutes.teacherCreateActivity,
        builder: (context, state) => const CreateActivityPage(),
      ),
      GoRoute(
        path: AppRoutes.teacherGrades,
        builder: (context, state) => const TeacherGradesPage(),
      ),
    ],
  );
});
