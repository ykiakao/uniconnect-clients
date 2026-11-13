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

final academicTermDatesProvider =
    FutureProvider.autoDispose<List<AcademicTermDates>>(
        (ref) => ref.watch(academicRecordsServiceProvider).activeTermDates(),
        retry: (_, __) => null);

/// Published grade of each activity of the student, by activity id, from
/// the academic history. Empty while loading or when unavailable.
final publishedGradesProvider =
    Provider.autoDispose<Map<String, double>>((ref) {
  final history = ref.watch(academicHistoryProvider).asData?.value;
  if (history == null) return const {};
  return Map.unmodifiable({
    for (final period in history.periods)
      for (final subject in period.subjects)
        for (final assessment in subject.assessments)
          if (assessment.grade case final grade?) assessment.activityId: grade,
  });
});

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
