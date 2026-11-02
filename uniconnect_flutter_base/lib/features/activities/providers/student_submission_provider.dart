import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../academic/demo/synthetic_academic_providers.dart';
import '../../auth/models/app_user.dart';
import '../../auth/providers/auth_provider.dart';
import '../services/student_submission_service.dart';

final studentSubmissionServiceProvider =
    Provider<StudentSubmissionService>((ref) {
  final auth = ref.watch(authControllerProvider);
  if (ref.watch(syntheticDemoEnabledProvider)) {
    throw const ApiException('Envio indisponível no modo de dados sintéticos.');
  }
  final user = auth.user;
  if (user == null ||
      user.role != UserRole.student ||
      auth.accessToken == null) {
    throw const ApiException(
        'Entre com uma conta de aluno para consultar sua entrega.',
        statusCode: 401);
  }
  return StudentSubmissionService(ref.watch(apiClientProvider),
      accessToken: auth.accessToken!,
      tenantSlug: user.tenant.slug,
      studentId: user.id);
});

final ownSubmissionProvider = FutureProvider.autoDispose
    .family<StudentSubmission?, String>(
        (ref, id) => ref.watch(studentSubmissionServiceProvider).own(id),
        retry: (_, __) => null);

String submissionErrorText(Object error) {
  if (error is ApiException) {
    return switch (error.statusCode) {
      401 => 'Sessão inválida ou expirada. Entre novamente.',
      403 => 'Acesso negado. Confira seu vínculo com a instituição.',
      404 => 'Atividade indisponível ou acesso não autorizado.',
      409 =>
        'Conflito de versão ou regra da atividade. Atualize antes de reenviar. A atividade pode estar encerrada, fora do prazo ou em avaliação.',
      _ => error.message,
    };
  }
  return 'Não foi possível consultar ou enviar sua entrega. Tente atualizar.';
}
