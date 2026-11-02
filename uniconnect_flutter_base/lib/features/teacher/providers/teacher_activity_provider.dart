import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../auth/models/app_user.dart';
import '../../auth/providers/auth_provider.dart';
import '../services/teacher_activity_service.dart';

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
  return ref.watch(teacherActivityServiceProvider).offerings();
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
