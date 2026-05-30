import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../academic/services/academic_api_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/academic_activity.dart';

final academicApiServiceProvider = Provider<AcademicApiService>((ref) {
  return AcademicApiService(ref.watch(apiClientProvider));
});

final activitiesProvider = FutureProvider<List<AcademicActivity>>((ref) async {
  final authState = ref.watch(authControllerProvider);
  final accessToken = authState.accessToken;
  final user = authState.user;

  if (accessToken == null || user == null) return const [];

  return ref.watch(academicApiServiceProvider).listActivities(
        accessToken: accessToken,
        tenantSlug: user.tenant.slug,
      );
});

final activityByIdProvider =
    FutureProvider.family<AcademicActivity?, String>((ref, id) async {
  for (final activity in await ref.watch(activitiesProvider.future)) {
    if (activity.id == id) return activity;
  }
  return null;
});
