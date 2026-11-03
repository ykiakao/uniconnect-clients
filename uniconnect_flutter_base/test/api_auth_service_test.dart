import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uniconnect/core/network/api_client.dart';
import 'package:uniconnect/core/tenant/tenant_config.dart';
import 'package:uniconnect/features/auth/models/app_user.dart';
import 'package:uniconnect/features/auth/services/api_auth_service.dart';

void main() {
  test('refresh uses JSON proof and logout uses the rotated bearer', () async {
    final requests = <http.Request>[];
    final service = ApiAuthService(ApiClient(
      baseUrl: 'https://api.example.invalid',
      httpClient: MockClient((request) async {
        requests.add(request);
        return request.url.path == '/auth/refresh'
            ? http.Response(
                jsonEncode(_session('professor', 'other-tenant')), 200)
            : http.Response('', 204);
      }),
    ));

    final refreshed =
        await service.refresh('old-refresh', tenantSlug: 'other-tenant');
    await service.logout(refreshed.accessToken, tenantSlug: 'other-tenant');

    expect(requests.first.method, 'POST');
    expect(requests.first.url.path, '/auth/refresh');
    expect(requests.first.url.hasQuery, isFalse);
    expect(requests.first.headers['authorization'], isNull);
    expect(
        requests.first.headers['content-type'], contains('application/json'));
    expect(requests.first.headers['x-tenant-slug'], 'other-tenant');
    expect(jsonDecode(requests.first.body), {'refreshToken': 'old-refresh'});
    expect(refreshed.refreshToken, 'new-refresh');
    expect(refreshed.user.role, UserRole.teacher);
    expect(requests.last.method, 'POST');
    expect(requests.last.url.path, '/auth/logout');
    expect(requests.last.headers['authorization'], 'Bearer new-access');
    expect(requests.last.headers['x-tenant-slug'], 'other-tenant');
  });

  for (final role in ['gestor', 'admin', 'owner', 'coordinator', 'unknown']) {
    test('login rejects unsupported API role $role', () async {
      final service = ApiAuthService(ApiClient(
        baseUrl: 'https://api.example.invalid',
        httpClient: MockClient((_) async =>
            http.Response(jsonEncode(_session(role, kDemoTenantSlug)), 200)),
      ));
      await expectLater(
        service.login(email: 'fixture@example.invalid', password: 'test-only'),
        throwsA(isA<UnsupportedUserRole>().having(
          (error) => error.administrative,
          'administrative',
          role != 'unknown',
        )),
      );
    });
  }

  test('protected request retries once and preserves tenant and payload',
      () async {
    final requests = <http.Request>[];
    var refreshes = 0;
    final client = ApiClient(
      baseUrl: 'https://api.example.invalid',
      refreshAccessToken: (token, tenant) async {
        expect(token, 'old-access');
        expect(tenant, 'tenant-fixture');
        refreshes++;
        return 'new-access';
      },
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
            '{"error":{"code":"INVALID_SESSION","message":"Invalid"}}', 401);
      }),
    );

    await expectLater(
        client.post('/protected', {'value': 'fixture'},
            accessToken: 'old-access', tenantSlug: 'tenant-fixture'),
        throwsA(isA<ApiException>()
            .having((error) => error.code, 'code', 'INVALID_SESSION')));
    expect(refreshes, 1);
    expect(requests.map((request) => request.headers['authorization']),
        ['Bearer old-access', 'Bearer new-access']);
    for (final request in requests) {
      expect(request.method, 'POST');
      expect(request.headers['x-tenant-slug'], 'tenant-fixture');
      expect(jsonDecode(request.body), {'value': 'fixture'});
    }
  });

  test('does not refresh an auth endpoint, access denial, or transient failure',
      () async {
    var status = 401;
    final client = ApiClient(
      baseUrl: 'https://api.example.invalid',
      refreshAccessToken: (_, __) async =>
          throw StateError('Unexpected refresh'),
      httpClient: MockClient((_) async =>
          http.Response('{"error":{"code":"INVALID_SESSION"}}', status)),
    );
    await expectLater(client.get('/auth/me', accessToken: 'access'),
        throwsA(isA<ApiException>()));
    for (final failure in [403, 503]) {
      status = failure;
      await expectLater(client.get('/protected', accessToken: 'access'),
          throwsA(isA<ApiException>()));
    }
  });

  test('login sends demo tenant slug header', () async {
    http.Request? capturedRequest;
    final service = ApiAuthService(
      ApiClient(
        baseUrl: 'http://localhost:3333/api/v1',
        httpClient: MockClient((request) async {
          capturedRequest = request;

          return http.Response(
            jsonEncode({
              'accessToken': 'access-token',
              'refreshToken': 'refresh-token',
              'expiresAt': '2026-05-28T15:00:00Z',
              'user': {
                'id': 'user-id',
                'name': 'Aluno Teste',
                'email': 'aluno@uni.com',
                'role': 'aluno',
                'tenantSlug': kDemoTenantSlug,
              },
            }),
            200,
            headers: {'Content-Type': 'application/json'},
          );
        }),
      ),
    );

    final session = await service.login(
      email: 'aluno@uni.com',
      password: 'test-only-password',
    );

    expect(capturedRequest?.headers['x-tenant-slug'], kDemoTenantSlug);
    expect(session.user.role, UserRole.student);
    expect(session.user.tenant.slug, kDemoTenantSlug);
    expect(session.accessToken, 'access-token');
    expect(session.refreshToken, 'refresh-token');
    expect(session.expiresAt, isNotNull);
  });
}

Map<String, dynamic> _session(String role, String tenantSlug) => {
      'accessToken': 'new-access',
      'refreshToken': 'new-refresh',
      'expiresAt': '2033-05-18T03:33:20.000Z',
      'user': {
        'id': 'member-fixture',
        'name': 'Fixture',
        'email': 'fixture@example.invalid',
        'role': role,
        'tenantSlug': tenantSlug,
      },
    };
