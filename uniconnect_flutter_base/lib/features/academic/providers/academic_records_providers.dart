import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../demo/synthetic_academic_providers.dart';
import '../models/academic_records.dart';
import '../services/academic_records_service.dart';

final academicRecordsServiceProvider = Provider<AcademicRecordsService>((ref) {
  if (ref.watch(syntheticDemoEnabledProvider)) {
    throw const ApiException('Indisponível no modo de demonstração.');
  }
  final auth = ref.watch(authControllerProvider);
  final user = auth.user;
  final token = auth.accessToken;
  if (user == null || token == null) {
    throw const ApiException('Sessão inválida. Entre novamente.',
        statusCode: 401);
  }
  return AcademicRecordsService(ref.watch(apiClientProvider),
      accessToken: token, tenantSlug: user.tenant.slug);
});

final academicPeriodsProvider =
    FutureProvider.autoDispose<List<AcademicPeriodRef>>(
        (ref) => ref.watch(academicRecordsServiceProvider).periods(),
        retry: (_, __) => null);

/// `null` asks the API for the active period.
final academicOverviewProvider = FutureProvider.autoDispose
    .family<AcademicOverviewRecord, String?>(
        (ref, periodId) => ref
            .watch(academicRecordsServiceProvider)
            .overview(periodId: periodId),
        retry: (_, __) => null);

final academicHistoryProvider =
    FutureProvider.autoDispose<AcademicHistoryRecord>(
        (ref) => ref.watch(academicRecordsServiceProvider).history(),
        retry: (_, __) => null);

String academicRecordsErrorText(Object error) {
  if (error is ApiException) {
    return switch (error.statusCode) {
      401 => 'Sessão inválida ou expirada. Entre novamente.',
      403 => 'Seu perfil não tem registros acadêmicos pessoais.',
      404 => 'Nenhum período letivo disponível para consulta.',
      _ => error.message,
    };
  }
  return 'Não foi possível carregar. Confira sua conexão e tente novamente.';
}
