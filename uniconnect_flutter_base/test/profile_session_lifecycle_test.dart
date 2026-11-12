import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uniconnect/core/network/api_client.dart';
import 'package:uniconnect/core/tenant/tenant_config.dart';
import 'package:uniconnect/core/theme/app_theme.dart';
import 'package:uniconnect/features/academic/demo/synthetic_academic_providers.dart';
import 'package:uniconnect/features/auth/providers/auth_provider.dart';
import 'package:uniconnect/features/auth/services/api_auth_service.dart';
import 'package:uniconnect/features/profile/presentation/profile_page.dart';

import 'fakes/fake_session_storage.dart';

Map<String, dynamic> _tenant(int phase) => {
      'id': 'profile-test-tenant',
      'slug': kDemoTenantSlug,
      'name': 'Instituição fase $phase',
      'plan': 'growth',
      'status': 'active',
      'activeUsers': 2,
    };

Map<String, dynamic> _user(String role, int phase) => {
      'id': 'profile-test-user',
      'name': 'Nome fase $phase',
      'email': 'profile@example.invalid',
      'role': role,
      'tenantSlug': kDemoTenantSlug,
      'course': 'Curso fase $phase',
      if (role == 'aluno') ...{
        'registration': 'PROFILE-$phase',
        'semester': phase
      },
    };

Future<void> _mount(WidgetTester tester, AuthController controller) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authControllerProvider.overrideWith((ref) => controller),
      syntheticDemoRequestedProvider.overrideWithValue(false),
    ],
    child: MaterialApp(theme: AppTheme.lightTheme, home: const ProfilePage()),
  ));
  await tester.pumpAndSettle();
}

void _expectProfile(String role, int phase) {
  expect(find.text('Nome fase $phase'), findsOneWidget);
  expect(find.text('profile@example.invalid'), findsOneWidget);
  expect(find.text('Instituição fase $phase'), findsOneWidget);
  expect(find.text('Curso fase $phase'), findsOneWidget);
  if (role == 'aluno') {
    expect(find.text('PROFILE-$phase'), findsOneWidget);
    expect(find.text('$phase'), findsOneWidget);
  } else {
    expect(find.text('Matrícula'), findsNothing);
    expect(find.text('Semestre'), findsNothing);
  }
}

void main() {
  for (final role in ['aluno', 'professor']) {
    testWidgets('$role profile follows login, restored /me and refresh data',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 1000);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var phase = 1;
      final requests = <String>[];
      final service = ApiAuthService(ApiClient(
        baseUrl: 'https://profile.example.invalid/api/v1',
        httpClient: MockClient((request) async {
          requests.add(request.url.path);
          expect(request.headers['x-tenant-slug'], kDemoTenantSlug);
          final user = _user(role, phase);
          final tenant = _tenant(phase);
          if (request.url.path.endsWith('/auth/me')) {
            expect(request.method, 'GET');
            expect(request.headers['authorization'], 'Bearer profile-access-1');
            return http.Response(jsonEncode({...user, 'tenant': tenant}), 200);
          }
          expect(request.method, 'POST');
          expect(request.url.path,
              isIn(['/api/v1/auth/login', '/api/v1/auth/refresh']));
          return http.Response(
              jsonEncode({
                'user': user,
                'tenant': tenant,
                'accessToken': 'profile-access-$phase',
                'refreshToken': 'profile-refresh-$phase',
                'expiresAt': 4102444800,
              }),
              200);
        }),
      ));
      final storage = FakeSessionStorage();
      final login = AuthController(service, storage);
      await login.login(
          email: 'profile@example.invalid',
          password: 'fixture-only',
          rememberSession: true);
      await _mount(tester, login);
      _expectProfile(role, 1);

      await tester.pumpWidget(const SizedBox.shrink());
      phase = 2;
      final restored = AuthController(service, storage);
      await restored.restoreSession();
      await _mount(tester, restored);
      _expectProfile(role, 2);
      expect(find.text('Nome fase 1'), findsNothing);

      phase = 3;
      expect(
          await restored.refreshAccessToken(
              'profile-access-1', kDemoTenantSlug),
          'profile-access-3');
      await tester.pumpAndSettle();
      _expectProfile(role, 3);
      expect(find.text('Curso fase 2'), findsNothing);
      expect(requests,
          ['/api/v1/auth/login', '/api/v1/auth/me', '/api/v1/auth/refresh']);
      expect(tester.takeException(), isNull);
    });
  }
}
