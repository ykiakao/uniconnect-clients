import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../activities/providers/activity_provider.dart';
import '../../academic/demo/synthetic_academic_providers.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/subject_grade.dart';

final subjectGradesProvider = FutureProvider<List<SubjectGrade>>((ref) async {
  final authState = ref.watch(authControllerProvider);
  final accessToken = authState.accessToken;
  final user = authState.user;

  if (accessToken == null || user == null) return const [];

  if (ref.watch(syntheticDemoEnabledProvider)) {
    return (await ref.watch(syntheticAcademicDataProvider.future)).grades;
  }

  return ref.watch(academicApiServiceProvider).listStudentGrades(
        accessToken: accessToken,
        tenantSlug: user.tenant.slug,
        studentId: user.id,
      );
});
