import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniconnect/core/theme/app_theme.dart';
import 'package:uniconnect/features/academic/demo/synthetic_academic_providers.dart';
import 'package:uniconnect/features/auth/models/app_user.dart';
import 'package:uniconnect/features/auth/providers/auth_provider.dart';
import 'package:uniconnect/features/profile/presentation/profile_page.dart';
import 'package:uniconnect/features/tenant/models/tenant_context.dart';

const _tenant = TenantContext(
  id: 'profile-test-tenant',
  name: 'Instituição de teste',
  slug: 'profile-test',
  plan: SubscriptionPlan.starter,
  status: SubscriptionStatus.active,
  activeUsers: 2,
);

AppUser _user(UserRole role, {bool withStudentFields = true}) => AppUser(
      id: 'profile-test-user',
      name: 'Pessoa de teste',
      email: 'profile@example.invalid',
      role: role,
      tenant: _tenant,
      course: 'Curso de teste',
      registration: withStudentFields ? 'PROFILE-TEST-001' : null,
      semester: withStudentFields ? 4 : null,
    );

Future<void> _pumpProfile(WidgetTester tester, AppUser user, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentUserProvider.overrideWithValue(user),
      syntheticDemoRequestedProvider.overrideWithValue(false),
    ],
    child: MaterialApp(theme: AppTheme.lightTheme, home: const ProfilePage()),
  ));
  await tester.pumpAndSettle();
}

void _expectIdentity(UserRole role) {
  expect(find.text('Pessoa de teste'), findsOneWidget);
  expect(find.text('profile@example.invalid'), findsOneWidget);
  expect(find.text('Instituição de teste'), findsOneWidget);
  expect(find.text('Perfil'), findsNWidgets(2));
  expect(find.text(role == UserRole.teacher ? 'Professor' : 'Aluno'),
      findsOneWidget);
  expect(find.text('Curso'), findsOneWidget);
  expect(find.text('Curso de teste'), findsOneWidget);
}

void main() {
  for (final size in [const Size(390, 844), const Size(1280, 900)]) {
    testWidgets('teacher hides student-only fields at width ${size.width}',
        (tester) async {
      await _pumpProfile(tester, _user(UserRole.teacher), size);
      _expectIdentity(UserRole.teacher);
      expect(find.text('Matrícula'), findsNothing);
      expect(find.text('Semestre'), findsNothing);
      expect(find.text('PROFILE-TEST-001'), findsNothing);
      expect(find.text('4'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('student keeps academic fields at width ${size.width}',
        (tester) async {
      await _pumpProfile(tester, _user(UserRole.student), size);
      _expectIdentity(UserRole.student);
      expect(find.text('Matrícula'), findsOneWidget);
      expect(find.text('Semestre'), findsOneWidget);
      expect(find.text('PROFILE-TEST-001'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('teacher without student data has no missing-data placeholders',
      (tester) async {
    await _pumpProfile(
        tester,
        _user(UserRole.teacher, withStudentFields: false),
        const Size(390, 844));
    _expectIdentity(UserRole.teacher);
    expect(find.text('Matrícula'), findsNothing);
    expect(find.text('Semestre'), findsNothing);
    expect(find.text('Não informado'), findsNothing);
  });

  testWidgets('student without academic data keeps honest placeholders',
      (tester) async {
    await _pumpProfile(
        tester,
        _user(UserRole.student, withStudentFields: false),
        const Size(390, 844));
    _expectIdentity(UserRole.student);
    expect(find.text('Matrícula'), findsOneWidget);
    expect(find.text('Semestre'), findsOneWidget);
    expect(find.text('Não informado'), findsNWidgets(2));
  });
}
