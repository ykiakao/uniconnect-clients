import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../auth/models/app_user.dart';
import '../../auth/providers/auth_provider.dart';
import '../services/teacher_activity_service.dart';
import '../services/teacher_academic_service.dart';

final teacherNotesSessionProvider = Provider((ref) {
  final identity = ref.watch(currentUserProvider.select((user) => (
        user?.id,
        user?.role,
        user?.tenant.id,
        user?.tenant.slug,
      )));
  final controller = ref.watch(authControllerProvider.notifier);
  final generation = ref.watch(
      authControllerProvider.select((_) => controller.sessionGeneration));
  return (controller, generation, identity);
});

final teacherActivityServiceProvider = Provider<TeacherActivityService>((ref) {
  final auth = ref.watch(authControllerProvider);
  final user = auth.user;
  if (user == null ||
      user.role != UserRole.teacher ||
      auth.accessToken == null) {
    throw const ApiException(
        'Entre com uma conta de professor para continuar.');
  }
  return TeacherActivityService(ref.watch(apiClientProvider),
      accessToken: auth.accessToken!, tenantSlug: user.tenant.slug);
});

final teacherOfferingsProvider = FutureProvider<List<TeacherOffering>>((ref) {
  ref.watch(teacherNotesSessionProvider);
  return ref.watch(teacherActivityServiceProvider).offerings();
}, retry: (_, __) => null);

final teacherAcademicServiceProvider = Provider<TeacherAcademicService>((ref) {
  return TeacherAcademicService(ref.watch(teacherActivityServiceProvider));
});

final teacherActivitiesProvider = FutureProvider.autoDispose
    .family<List<TeacherActivity>, String>((ref, classId) async {
  final service = ref.watch(teacherActivityServiceProvider);
  final offerings = await ref.watch(teacherOfferingsProvider.future);
  if (!offerings.any((o) => o.id == classId)) {
    throw const ApiException('Oferta não autorizada para este professor.');
  }
  return service.activities(classId);
});

final teacherEnrollmentsProvider = FutureProvider.autoDispose
    .family<List<String>, String>((ref, classId) async {
  final service = ref.watch(teacherActivityServiceProvider);
  final tenantId = ref.watch(currentUserProvider)?.tenant.id;
  final offerings = await ref.watch(teacherOfferingsProvider.future);
  if (tenantId == null || !offerings.any((offer) => offer.id == classId)) {
    throw const ApiException(
        'Oferta não autorizada para consultar matrículas.');
  }
  return service.enrolledStudents(classId, tenantId);
}, retry: (_, __) => null);

final teacherActivityPreviewProvider = FutureProvider.autoDispose
    .family<({List<TeacherActivity> rows, int total}), String>(
        (ref, classId) async {
  final service = ref.watch(teacherActivityServiceProvider);
  final offerings = await ref.watch(teacherOfferingsProvider.future);
  if (!offerings.any((offer) => offer.id == classId)) {
    throw const ApiException('Oferta não autorizada para este professor.');
  }
  return service.activityPreview(classId);
}, retry: (_, __) => null);
