import 'package:flutter_test/flutter_test.dart';
import 'package:uniconnect/core/network/api_client.dart';
import 'package:uniconnect/features/auth/providers/auth_provider.dart';
import 'package:uniconnect/features/auth/services/api_auth_service.dart';
import 'package:uniconnect/features/auth/services/session_storage.dart';

import 'fakes/fake_auth_service.dart';
import 'fakes/fake_session_storage.dart';

void main() {
  test('remember me disabled keeps session only in memory', () async {
    final storage = FakeSessionStorage();
    final controller = AuthController(FakeAuthService(), storage);

    await controller.login(
      email: 'aluno.teste@uni.com',
      password: '123456',
      rememberSession: false,
    );

    expect(controller.state.status, AuthStatus.authenticated);
    expect(controller.accessToken, 'access-token');
    expect(storage.saveCount, 0);
    expect(await storage.read(), isNull);
  });

  test('remember me enabled saves persistent session', () async {
    final storage = FakeSessionStorage();
    final controller = AuthController(FakeAuthService(), storage);

    await controller.login(
      email: 'aluno.teste@uni.com',
      password: '123456',
      rememberSession: true,
    );

    expect(controller.state.status, AuthStatus.authenticated);
    expect(storage.saveCount, 1);
    expect(await storage.read(), isNotNull);
  });

  test('restore session validates token and authenticates user', () async {
    final storage = FakeSessionStorage();
    await storage.save(
      const AuthSession(
        accessToken: 'saved-token',
        refreshToken: 'saved-refresh',
        expiresAt: 4102444800,
        user: fakeStudent,
      ),
    );
    final authService = FakeAuthService();
    final controller = AuthController(authService, storage);

    await controller.restoreSession();

    expect(authService.meCalls, 1);
    expect(controller.state.status, AuthStatus.authenticated);
    expect(controller.accessToken, 'saved-token');
  });

  test('restore session clears invalid saved token', () async {
    final storage = FakeSessionStorage();
    await storage.save(
      const AuthSession(
        accessToken: 'invalid-token',
        refreshToken: 'saved-refresh',
        expiresAt: 4102444800,
        user: fakeStudent,
      ),
    );
    final controller = AuthController(
      FakeAuthService(
        meError: const ApiException('Sessão inválida.', statusCode: 401),
      ),
      storage,
    );

    await controller.restoreSession();

    expect(controller.state.status, AuthStatus.unauthenticated);
    expect(controller.accessToken, isNull);
    expect(await storage.read(), isNull);
  });

  test('logout clears persisted session and memory token', () async {
    final storage = FakeSessionStorage();
    final controller = AuthController(FakeAuthService(), storage);

    await controller.login(
      email: 'aluno.teste@uni.com',
      password: '123456',
      rememberSession: true,
    );
    await controller.logout();

    expect(controller.state.status, AuthStatus.unauthenticated);
    expect(controller.accessToken, isNull);
    expect(await storage.read(), isNull);
  });

  test('legacy saved password is removed during restore', () async {
    final storage = FakeSessionStorage()..hasLegacyPassword = true;
    final controller = AuthController(FakeAuthService(), storage);

    await controller.restoreSession();

    expect(storage.hasLegacyPassword, isFalse);
    expect(storage.legacyClearCount, greaterThan(0));
  });
}
