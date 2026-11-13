import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../academic/services/academic_api_service.dart';
import '../../academic/demo/synthetic_academic_providers.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/academic_activity.dart';
import '../../../core/network/api_client.dart';

final academicApiServiceProvider = Provider<AcademicApiService>((ref) {
  return AcademicApiService(ref.watch(apiClientProvider));
});

final activityClockProvider = Provider.autoDispose<DateTime>((ref) {
  final timer = Timer(const Duration(seconds: 1), ref.invalidateSelf);
  ref.onCancel(timer.cancel);
  ref.onResume(ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return DateTime.now();
});

final activitiesProvider = FutureProvider<List<AcademicActivity>>((ref) async {
  final authState = ref.watch(authControllerProvider);
  final accessToken = authState.accessToken;
  final user = authState.user;

  if (accessToken == null || user == null) {
    throw const ApiException('Sessão inválida. Entre novamente.',
        statusCode: 401);
  }

  if (ref.watch(syntheticDemoEnabledProvider)) {
    return (await ref.watch(syntheticAcademicDataProvider.future)).activities;
  }

  return ref.watch(academicApiServiceProvider).listActivities(
        accessToken: accessToken,
        tenantSlug: user.tenant.slug,
      );
}, retry: (_, __) => null);

final activityByIdProvider =
    FutureProvider.family<AcademicActivity?, String>((ref, id) async {
  if (ref.watch(syntheticDemoEnabledProvider)) {
    for (final activity in await ref.watch(activitiesProvider.future)) {
      if (activity.id == id) return activity;
    }
    return null;
  }
  final auth = ref.watch(authControllerProvider);
  if (auth.accessToken == null || auth.user == null) {
    throw const ApiException('Sessão inválida. Entre novamente.',
        statusCode: 401);
  }
  return ref.watch(academicApiServiceProvider).getActivity(
      accessToken: auth.accessToken!,
      tenantSlug: auth.user!.tenant.slug,
      id: id);
}, retry: (_, __) => null);
