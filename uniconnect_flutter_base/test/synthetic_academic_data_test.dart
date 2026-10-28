import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniconnect/core/network/api_client.dart';
import 'package:uniconnect/features/academic/demo/synthetic_academic_data.dart';
import 'package:uniconnect/features/academic/demo/synthetic_academic_providers.dart';
import 'package:uniconnect/features/academic/services/academic_api_service.dart';
import 'package:uniconnect/features/activities/models/academic_activity.dart';
import 'package:uniconnect/features/activities/providers/activity_provider.dart';
import 'package:uniconnect/features/auth/models/app_user.dart';
import 'package:uniconnect/features/auth/providers/auth_provider.dart';
import 'package:uniconnect/features/auth/services/api_auth_service.dart';
import 'package:uniconnect/features/grades/models/subject_grade.dart';
import 'package:uniconnect/features/grades/providers/grades_provider.dart';
import 'package:uniconnect/features/tenant/models/tenant_context.dart';

import 'demo_day_test.dart' show demoActivity;
import 'fakes/fake_auth_service.dart';
import 'fakes/fake_session_storage.dart';

const syntheticStudent = AppUser(
    id: 'synthetic-mode-test-user',
    name: 'Aluno Teste',
    email: 'test@example.invalid',
    role: UserRole.student,
    tenant: TenantContext(
        id: 'test-edukmais',
        name: 'EduKMais',
        slug: 'edukmais',
        plan: SubscriptionPlan.growth,
        status: SubscriptionStatus.trialing,
        activeUsers: 1));

class CountingAcademicApi extends AcademicApiService {
  CountingAcademicApi() : super(ApiClient());
  int activityCalls = 0;
  int gradeCalls = 0;
  @override
  Future<List<AcademicActivity>> listActivities(
      {required String accessToken, required String tenantSlug}) async {
    activityCalls++;
    return [demoActivity];
  }

  @override
  Future<List<SubjectGrade>> listStudentGrades(
      {required String accessToken,
      required String tenantSlug,
      required String studentId}) async {
    gradeCalls++;
    return const [
      SubjectGrade(
          subject: 'API normal',
          code: 'API001',
          teacher: 'API',
          p1: 7,
          p2: 7,
          work: 7,
          status: '')
    ];
  }
}

Future<void> signIn(ProviderContainer container, AppUser user) async {
  final auth = container.read(authControllerProvider.notifier);
  await auth.restoreSession();
  await auth.login(
      email: user.email, password: 'test-only', rememberSession: false);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<Map<String, dynamic>> rawData() async =>
      jsonDecode(await rootBundle.loadString(SyntheticAcademicData.assetPath))
          as Map<String, dynamic>;

  test(
      'compile-time opt-in defaults off and uses the explicit flag when supplied',
      () {
    final container = ProviderContainer(
        overrides: [currentUserProvider.overrideWithValue(null)]);
    addTearDown(container.dispose);
    expect(container.read(syntheticDemoRequestedProvider),
        const bool.fromEnvironment('DEMO_SYNTHETIC_DATA', defaultValue: false));
    expect(container.read(syntheticDemoEnabledProvider), isFalse);
  });

  test(
      'bundled JSON equals phase 1 and maps all relationships without changing deadlines',
      () async {
    final asset = await rootBundle.loadString(SyntheticAcademicData.assetPath);
    expect(
        asset,
        File('../docs/demo-day/synthetic-academic-data.json')
            .readAsStringSync());
    final data = SyntheticAcademicData.fromJson(
        jsonDecode(asset) as Map<String, dynamic>);
    expect(data.activities, hasLength(10));
    expect(data.grades, hasLength(6));
    expect(data.currentSubjects, hasLength(5));
    expect(data.currentPeriodLabel, '2026.2');
    expect(data.grades.where((g) => g.isHistorical), hasLength(1));
    expect(data.grades.where((g) => g.activityId == null), hasLength(2));
    expect(
        data.grades.every((g) =>
            g.disciplineName?.isNotEmpty == true &&
            g.periodLabel != null &&
            g.feedback != null),
        isTrue);
    final ids = data.activities.map((a) => a.id).toSet();
    expect(
        data.grades
            .where((g) => g.activityId != null)
            .every((g) => ids.contains(g.activityId)),
        isTrue);
    expect(
        data.activities
            .where((a) => a.dueDate?.isBefore(data.referenceTime) ?? false),
        hasLength(4));
    expect(
        data.activities
            .where((a) => a.dueDate?.isAfter(data.referenceTime) ?? false),
        hasLength(4));
    expect(data.activities.where((a) => a.dueDate == null), hasLength(2));
    expect(
        data.activities.where((a) =>
            a.dueDate != null &&
            a.dueDate!.isAfter(data.referenceTime) &&
            a.dueDate!.difference(data.referenceTime) <=
                const Duration(hours: 24)),
        hasLength(2));
    final next = data.activities.singleWhere((a) => a.id.endsWith('005'));
    expect(next.dueDate, DateTime.parse('2026-10-28T22:00:00-05:00'));
    expect(next.displayDueDate!.day, 28);
    expect(next.displayDueDate!.hour, 22);
    expect(next.dueLabel, 'Vence em 3 h');
    final grades = data.grades.where((g) => !g.isHistorical).toList();
    expect(grades.map((g) => g.p1).reduce((a, b) => a + b) / grades.length,
        closeTo(8.2, .001));
    expect(data.activities.last.dueDate, isNull);
  });

  test(
      'real compile-time flag selects exactly one source for an eligible login',
      () async {
    final api = CountingAcademicApi();
    final container = ProviderContainer(overrides: [
      apiAuthServiceProvider.overrideWithValue(FakeAuthService(
          loginResult: const AuthSession(
              accessToken: 'test-token',
              refreshToken: 'test-refresh',
              expiresAt: null,
              user: syntheticStudent))),
      sessionStorageProvider.overrideWithValue(FakeSessionStorage()),
      academicApiServiceProvider.overrideWithValue(api),
    ]);
    addTearDown(container.dispose);
    await signIn(container, syntheticStudent);
    const enabled =
        bool.fromEnvironment('DEMO_SYNTHETIC_DATA', defaultValue: false);
    expect(container.read(syntheticDemoEnabledProvider), enabled);
    expect(await container.read(activitiesProvider.future),
        hasLength(enabled ? 10 : 1));
    expect(await container.read(subjectGradesProvider.future),
        hasLength(enabled ? 6 : 1));
    expect(api.activityCalls + api.gradeCalls, enabled ? 0 : 2);
  });

  for (final kind in [
    'metadata',
    'activity link',
    'grade link',
    'invalid grade'
  ]) {
    test('malformed synthetic $kind is rejected', () async {
      final raw = await rawData();
      switch (kind) {
        case 'metadata':
          raw['metadata']['synthetic'] = false;
        case 'activity link':
          raw['activities'][0]['subjectId'] = 'missing';
        case 'grade link':
          raw['evaluations'][0]['activityId'] = raw['activities'][5]['id'];
        case 'invalid grade':
          raw['evaluations'][0]['grade'] = 11;
      }
      expect(() => SyntheticAcademicData.fromJson(raw), throwsFormatException);
    });
  }

  test(
      'source switch is exclusive and returns to API without synthetic records',
      () async {
    final selection = StateProvider((ref) => true);
    final api = CountingAcademicApi();
    final container = ProviderContainer(overrides: [
      syntheticDemoRequestedProvider
          .overrideWith((ref) => ref.watch(selection)),
      apiAuthServiceProvider.overrideWithValue(FakeAuthService(
          loginResult: const AuthSession(
              accessToken: 'test-token',
              refreshToken: 'test-refresh',
              expiresAt: null,
              user: syntheticStudent))),
      sessionStorageProvider.overrideWithValue(FakeSessionStorage()),
      academicApiServiceProvider.overrideWithValue(api),
    ]);
    addTearDown(container.dispose);
    await signIn(container, syntheticStudent);
    final identity = container.read(currentUserProvider);
    expect(await container.read(activitiesProvider.future), hasLength(10));
    expect(await container.read(subjectGradesProvider.future), hasLength(6));
    expect(api.activityCalls, 0);
    expect(api.gradeCalls, 0);
    container.read(selection.notifier).state = false;
    final normal = await container.read(activitiesProvider.future);
    expect(normal.single.id, demoActivity.id);
    expect((await container.read(subjectGradesProvider.future)).single.subject,
        'API normal');
    expect(api.activityCalls, 1);
    expect(api.gradeCalls, 1);
    expect(container.read(currentUserProvider), same(identity));
    expect(normal.single.demoReferenceTime, isNull);
  });

  test('asset errors never fall back to API', () async {
    final api = CountingAcademicApi();
    final container = ProviderContainer(retry: (_, __) => null, overrides: [
      syntheticDemoRequestedProvider.overrideWithValue(true),
      syntheticAcademicDataProvider.overrideWith(
          (ref) async => throw const FormatException('Test invalid asset')),
      apiAuthServiceProvider.overrideWithValue(FakeAuthService(
          loginResult: const AuthSession(
              accessToken: 'test-token',
              refreshToken: 'test-refresh',
              expiresAt: null,
              user: syntheticStudent))),
      sessionStorageProvider.overrideWithValue(FakeSessionStorage()),
      academicApiServiceProvider.overrideWithValue(api),
    ]);
    addTearDown(container.dispose);
    await signIn(container, syntheticStudent);
    await expectLater(
        container.read(activitiesProvider.future), throwsFormatException);
    await expectLater(
        container.read(subjectGradesProvider.future), throwsFormatException);
    expect(api.activityCalls + api.gradeCalls, 0);
  });

  test('normal source never loads the synthetic asset', () async {
    final api = CountingAcademicApi();
    final container = ProviderContainer(overrides: [
      syntheticDemoRequestedProvider.overrideWithValue(false),
      syntheticAcademicDataProvider.overrideWith(
          (ref) => throw StateError('Normal mode must not load demo')),
      apiAuthServiceProvider.overrideWithValue(FakeAuthService()),
      sessionStorageProvider.overrideWithValue(FakeSessionStorage()),
      academicApiServiceProvider.overrideWithValue(api),
    ]);
    addTearDown(container.dispose);
    await signIn(container, fakeStudent);
    expect(await container.read(activitiesProvider.future), hasLength(1));
    expect(await container.read(subjectGradesProvider.future), hasLength(1));
    expect(api.activityCalls + api.gradeCalls, 2);
  });

  test('synthetic mode excludes teachers and other tenants', () {
    for (final user in [
      fakeStudent,
      AppUser(
          id: 'teacher-test',
          name: 'Docente',
          email: 'teacher@example.invalid',
          role: UserRole.teacher,
          tenant: syntheticStudent.tenant)
    ]) {
      final container = ProviderContainer(overrides: [
        syntheticDemoRequestedProvider.overrideWithValue(true),
        currentUserProvider.overrideWithValue(user)
      ]);
      expect(container.read(syntheticDemoEnabledProvider), isFalse);
      container.dispose();
    }
  });
}
