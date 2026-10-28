import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/models/app_user.dart';
import '../../auth/providers/auth_provider.dart';
import 'synthetic_academic_data.dart';

final syntheticDemoRequestedProvider = Provider<bool>((ref) =>
    const bool.fromEnvironment('DEMO_SYNTHETIC_DATA', defaultValue: false));

final syntheticDemoEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(syntheticDemoRequestedProvider)) return false;
  final user = ref.watch(currentUserProvider);
  return user?.role == UserRole.student && user?.tenant.slug == 'edukmais';
});

final syntheticAcademicDataProvider =
    FutureProvider<SyntheticAcademicData>((ref) async {
  final content = await rootBundle.loadString(SyntheticAcademicData.assetPath,
      cache: false);
  return SyntheticAcademicData.fromJson(
      jsonDecode(content) as Map<String, dynamic>);
});

void invalidateSyntheticAcademicData(WidgetRef ref) {
  if (ref.read(syntheticDemoEnabledProvider)) {
    ref.invalidate(syntheticAcademicDataProvider);
  }
}
