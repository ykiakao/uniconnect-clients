import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniconnect/features/auth/services/api_auth_service.dart';
import 'package:uniconnect/features/auth/services/session_storage.dart';

import 'fakes/fake_auth_service.dart';

void main() {
  const secure = FlutterSecureStorage();
  const storage = SessionStorage(secure);

  test(
      'reads legacy credentials and replaces them with one tenant-bound record',
      () async {
    FlutterSecureStorage.setMockInitialValues({
      'auth.accessToken': 'legacy-access',
      'auth.refreshToken': 'legacy-refresh',
      'auth.expiresAt': '4102444800',
      'auth.password': 'legacy-test-only',
    });
    final legacy = await storage.read();
    expect(legacy?.accessToken, 'legacy-access');
    expect(legacy?.refreshToken, 'legacy-refresh');
    expect(legacy?.tenantSlug, isNull);

    await storage.save(const AuthSession(
      accessToken: 'rotated-access',
      refreshToken: 'rotated-refresh',
      expiresAt: 4102444800000,
      user: fakeStudent,
    ));

    final values = await secure.readAll();
    expect(values.keys, ['auth.session']);
    expect(jsonDecode(values['auth.session']!), {
      'accessToken': 'rotated-access',
      'refreshToken': 'rotated-refresh',
      'expiresAt': 4102444800000,
      'tenantSlug': fakeStudent.tenant.slug,
      'userId': fakeStudent.id,
    });
    expect((await storage.read())?.tenantSlug, fakeStudent.tenant.slug);
    await storage.clear();
    expect(await storage.read(), isNull);
    expect(await secure.readAll(), isEmpty);
  });

  test('an incomplete clear never falls back to legacy tokens', () async {
    FlutterSecureStorage.setMockInitialValues({
      'auth.session': '',
      'auth.accessToken': 'legacy-access',
      'auth.refreshToken': 'legacy-refresh',
    });
    expect(await storage.read(), isNull);
  });
}
