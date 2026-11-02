import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../auth/models/app_user.dart';
import '../../auth/providers/auth_provider.dart';
import '../services/teacher_review_service.dart';
import 'teacher_activity_provider.dart';

final teacherReviewServiceProvider = Provider<TeacherReviewService>((ref) {
  final auth = ref.watch(authControllerProvider);
  if (auth.user?.role != UserRole.teacher || auth.accessToken == null) {
    throw const ApiException('Entre com uma conta de professor.',
        statusCode: 401);
  }
  return TeacherReviewService(ref.watch(apiClientProvider),
      accessToken: auth.accessToken!, tenantSlug: auth.user!.tenant.slug);
});

final teacherSubmissionsProvider = FutureProvider.autoDispose
    .family<List<TeacherSubmission>, ({String classId, String activityId})>(
        (ref, key) async {
  final service = ref.watch(teacherReviewServiceProvider);
  final activities =
      await ref.watch(teacherActivitiesProvider(key.classId).future);
  if (!activities.any((a) => a.id == key.activityId)) {
    throw const ApiException('Atividade não autorizada.');
  }
  return service.list(key.activityId);
}, retry: (_, __) => null);

String teacherReviewError(Object error) {
  if (error is ApiException) {
    return switch (error.statusCode) {
      401 => 'Sessão inválida ou expirada. Entre novamente.',
      403 ||
      404 =>
        'Entrega indisponível ou acesso negado. Confira seu vínculo docente.',
      409 =>
        'Conflito de versão, revisão ou estado. Atualize a entrega antes de tentar novamente.',
      _ => error.message,
    };
  }
  return 'Não foi possível consultar ou salvar a avaliação. Tente atualizar.';
}
