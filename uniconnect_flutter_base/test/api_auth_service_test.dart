import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uniconnect/core/network/api_client.dart';
import 'package:uniconnect/core/tenant/tenant_config.dart';
import 'package:uniconnect/features/auth/models/app_user.dart';
import 'package:uniconnect/features/auth/services/api_auth_service.dart';

void main() {
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
