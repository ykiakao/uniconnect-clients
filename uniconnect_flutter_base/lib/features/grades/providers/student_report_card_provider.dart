import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../academic/demo/synthetic_academic_providers.dart';
import '../../activities/providers/activity_provider.dart';
import '../../auth/models/app_user.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/student_report_card.dart';

class StudentReportSession {
  const StudentReportSession._(this.user, this._token);

  final AppUser user;
  final String _token;
}

// An opaque identity separates family caches on login, logout and tenant changes.
final studentReportSessionProvider =
    Provider.autoDispose<StudentReportSession?>((ref) {
  final auth = ref.watch(authControllerProvider);
  final user = auth.user;
  final token = auth.accessToken;
  if (!auth.isAuthenticated ||
      user == null ||
      user.role != UserRole.student ||
      token == null ||
      ref.watch(syntheticDemoEnabledProvider)) {
    return null;
  }
  return StudentReportSession._(user, token);
});

final studentReportSelectionProvider =
    NotifierProvider<StudentReportSelection, String?>(
  StudentReportSelection.new,
);

class StudentReportSelection extends Notifier<String?> {
  @override
  String? build() {
    final controller = ref.watch(authControllerProvider.notifier);
    ref.watch(authControllerProvider.select((auth) {
      final user = auth.user;
      return (
        controller.sessionGeneration,
        auth.isAuthenticated,
        user?.id,
        user?.role,
        user?.tenant.id,
        user?.tenant.slug,
      );
    }));
    return null;
  }

  void select(String? classId) => state = classId;

  void reconcile(List<StudentReportOffering> offerings) {
    if (state != null && !offerings.any((offer) => offer.id == state)) {
      state = null;
    }
    if (state == null && offerings.length == 1) {
      state = offerings.single.id;
    }
  }
}

final studentReportOfferingsProvider = FutureProvider.autoDispose
    .family<List<StudentReportOffering>, StudentReportSession>((ref, session) {
  return ref.watch(academicApiServiceProvider).listStudentReportOfferings(
        accessToken: session._token,
        tenantSlug: session.user.tenant.slug,
        tenantId: session.user.tenant.id,
      );
}, retry: (_, __) => null);

final studentReportCardProvider = FutureProvider.autoDispose
    .family<StudentReportCard, (StudentReportSession, String)>((ref, scope) {
  final (session, classId) = scope;
  return ref.watch(academicApiServiceProvider).getStudentReportCard(
        accessToken: session._token,
        tenantSlug: session.user.tenant.slug,
        classId: classId,
        studentId: session.user.id,
      );
}, retry: (_, __) => null);
