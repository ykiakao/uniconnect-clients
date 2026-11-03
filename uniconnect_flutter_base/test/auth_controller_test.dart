import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:uniconnect/core/network/api_client.dart';
import 'package:uniconnect/features/auth/providers/auth_provider.dart';
import 'package:uniconnect/features/auth/models/app_user.dart';
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
      password: 'test-only-password',
      rememberSession: false,
    );

    expect(controller.state.status, AuthStatus.authenticated);
    expect(controller.accessToken, 'access-token');
    expect(controller.state.accessToken, 'access-token');
    expect(controller.state.role, fakeStudent.role);
    expect(controller.state.tenantSlug, fakeStudent.tenant.slug);
    expect(storage.saveCount, 0);
    expect(await storage.read(), isNull);
  });

  test('login with API error exposes friendly error and saves nothing',
      () async {
    final storage = FakeSessionStorage();
    final controller = AuthController(
      FakeAuthService(
        loginError: const ApiException(
          'E-mail ou senha incorretos',
          statusCode: 401,
        ),
      ),
      storage,
    );

    await expectLater(
      controller.login(
        email: 'aluno.teste@uni.com',
        password: 'errada',
        rememberSession: true,
      ),
      throwsA(isA<ApiException>()),
    );

    expect(controller.state.status, AuthStatus.error);
    expect(controller.state.errorMessage, 'E-mail ou senha incorretos');
    expect(controller.accessToken, isNull);
    expect(storage.saveCount, 0);
    expect(await storage.read(), isNull);
  });

  test('remember me enabled saves persistent session', () async {
    final storage = FakeSessionStorage();
    final controller = AuthController(FakeAuthService(), storage);

    await controller.login(
      email: 'aluno.teste@uni.com',
      password: 'test-only-password',
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
    expect(controller.state.tenantSlug, fakeStudent.tenant.slug);
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
        meError: const ApiException('Sessão inválida.',
            statusCode: 401, code: 'INVALID_SESSION'),
        refreshError: const ApiException('Sessão inválida.',
            statusCode: 401, code: 'INVALID_SESSION'),
      ),
      storage,
    );

    await controller.restoreSession();

    expect(controller.state.status, AuthStatus.unauthenticated);
    expect(controller.accessToken, isNull);
    expect(storage.clearCount, 1);
    expect(await storage.read(), isNull);
  });

  test('restore preserves persisted credentials on a transport failure',
      () async {
    final storage = FakeSessionStorage();
    await storage.save(const AuthSession(
      accessToken: 'saved-token',
      refreshToken: 'saved-refresh',
      expiresAt: null,
      user: fakeStudent,
    ));
    final controller = AuthController(
      FakeAuthService(meError: const ApiException('transient')),
      storage,
    );

    await controller.restoreSession();

    expect(controller.state.isAuthenticated, isFalse);
    expect(storage.clearCount, 0);
    expect((await storage.read())?.refreshToken, 'saved-refresh');
  });

  test('restore session exits loading when persistent storage hangs', () async {
    final storage = FakeSessionStorage(
      readCompleter: Completer<StoredAuthSession?>(),
    );
    final controller = AuthController(
      FakeAuthService(),
      storage,
      storageTimeout: const Duration(milliseconds: 1),
    );

    await controller.restoreSession();

    expect(controller.state.status, AuthStatus.unauthenticated);
    expect(controller.accessToken, isNull);
  });

  test('remember me save failure keeps login authenticated in memory',
      () async {
    final storage = FakeSessionStorage(
      saveError: StateError('storage unavailable'),
    );
    final controller = AuthController(FakeAuthService(), storage);

    final user = await controller.login(
      email: 'aluno.teste@uni.com',
      password: 'test-only-password',
      rememberSession: true,
    );

    expect(user, fakeStudent);
    expect(controller.state.status, AuthStatus.authenticated);
    expect(controller.accessToken, 'access-token');
    expect(storage.saveCount, 1);
    expect(await storage.read(), isNull);
  });

  test('logout clears persisted session and memory token', () async {
    final storage = FakeSessionStorage();
    final service = FakeAuthService();
    final controller = AuthController(service, storage);

    await controller.login(
      email: 'aluno.teste@uni.com',
      password: 'test-only-password',
      rememberSession: true,
    );
    await controller.logout();

    expect(service.logoutCalls, [('access-token', fakeStudent.tenant.slug)]);
    expect(controller.state.status, AuthStatus.unauthenticated);
    expect(controller.accessToken, isNull);
    expect(await storage.read(), isNull);
  });

  test(
      'restore rotates expired credentials and persists the pair for the saved tenant',
      () async {
    final storage = FakeSessionStorage();
    await storage.save(_savedSession);
    final service = FakeAuthService(
      meError: const ApiException('expired',
          statusCode: 401, code: 'INVALID_SESSION'),
    );
    final controller = AuthController(service, storage);
    await Future.wait(
        [controller.restoreSession(), controller.restoreSession()]);

    expect(service.meCalls, 1);
    expect(service.meTenant, fakeStudent.tenant.slug);
    expect(service.refreshCalls, [('saved-refresh', fakeStudent.tenant.slug)]);
    expect(controller.state.accessToken, 'rotated-access');
    final stored = await storage.read();
    expect(stored?.accessToken, 'rotated-access');
    expect(stored?.refreshToken, 'rotated-refresh');
    expect(stored?.tenantSlug, fakeStudent.tenant.slug);
  });

  test(
      'transient failure during restore refresh keeps storage and allows retry',
      () async {
    final storage = FakeSessionStorage();
    await storage.save(_savedSession);
    final controller = AuthController(
        FakeAuthService(
          meError: const ApiException('expired',
              statusCode: 401, code: 'INVALID_SESSION'),
          refreshError: const ApiException('offline', statusCode: 503),
        ),
        storage);
    await controller.restoreSession();
    expect(controller.state.canRetryRestore, isTrue);
    expect(controller.state.accessToken, isNull);
    expect((await storage.read())?.refreshToken, 'saved-refresh');
  });

  test(
      'concurrent 401s share rotation and reuse the result for a late response',
      () async {
    final completer = Completer<AuthSession>();
    final service = FakeAuthService(refreshCompleter: completer);
    final storage = FakeSessionStorage();
    final controller = AuthController(service, storage);
    await controller.login(
        email: 'aluno@example.invalid',
        password: 'test-only',
        rememberSession: false);
    final tenant = fakeStudent.tenant.slug;
    final first = controller.refreshAccessToken('access-token', tenant);
    final second = controller.refreshAccessToken('access-token', tenant);
    completer.complete(_rotatedSession);
    expect(await Future.wait([first, second]),
        ['rotated-access', 'rotated-access']);
    expect(await controller.refreshAccessToken('access-token', tenant),
        'rotated-access');
    expect(
        await controller.refreshAccessToken('access-token', 'other'), isNull);
    expect(service.refreshCalls, [('refresh-token', tenant)]);
    expect(storage.saveCount, 0);
  });

  test(
      'transient failure during refresh keeps the active and persisted session',
      () async {
    final storage = FakeSessionStorage();
    final controller = AuthController(
        FakeAuthService(
          refreshError: const ApiException('offline'),
        ),
        storage);
    await controller.login(
        email: 'aluno@example.invalid',
        password: 'test-only',
        rememberSession: true);
    expect(
        await controller.refreshAccessToken(
            'access-token', fakeStudent.tenant.slug),
        isNull);
    expect(controller.state.isAuthenticated, isTrue);
    expect(controller.accessToken, 'access-token');
    expect((await storage.read())?.refreshToken, 'refresh-token');
  });

  test('logout immediately removes local access, even if revocation fails',
      () async {
    final pending = Completer<void>();
    final storage = FakeSessionStorage();
    final service = FakeAuthService(logoutCompleter: pending);
    final controller = AuthController(service, storage);
    await controller.login(
        email: 'aluno@example.invalid',
        password: 'test-only',
        rememberSession: true);
    final logout = controller.logout();
    expect(controller.accessToken, isNull);
    expect(controller.state.isAuthenticated, isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(service.logoutCalls, [('access-token', fakeStudent.tenant.slug)]);
    pending.completeError(const ApiException('private diagnostic'));
    await logout;
    expect(await storage.read(), isNull);
    expect(controller.state.errorMessage, contains('encerramento remoto'));
    expect(
        controller.state.errorMessage, isNot(contains('private diagnostic')));
  });

  test(
      'logout during rotation revokes the rotated token without restoring local access',
      () async {
    final rotation = Completer<AuthSession>();
    final storage = FakeSessionStorage();
    final service = FakeAuthService(refreshCompleter: rotation);
    final controller = AuthController(service, storage);
    await controller.login(
        email: 'aluno@example.invalid',
        password: 'test-only',
        rememberSession: true);
    final refresh =
        controller.refreshAccessToken('access-token', fakeStudent.tenant.slug);
    final logout = controller.logout();
    rotation.complete(_rotatedSession);
    expect(await refresh, isNull);
    await logout;
    expect(service.logoutCalls, [('rotated-access', fakeStudent.tenant.slug)]);
    expect(controller.accessToken, isNull);
    expect(storage.saveCount, 1);
    expect(await storage.read(), isNull);
  });

  test('unsupported administrative role cannot restore saved access', () async {
    final storage = FakeSessionStorage();
    await storage.save(_savedSession);
    final controller = AuthController(
        FakeAuthService(
          meError: const UnsupportedUserRole(administrative: true),
        ),
        storage);
    await controller.restoreSession();
    expect(controller.state.isAuthenticated, isFalse);
    expect(controller.state.errorMessage, contains('painel web'));
    expect(await storage.read(), isNull);
  });

  test('legacy saved password is removed during restore', () async {
    final storage = FakeSessionStorage()..hasLegacyPassword = true;
    final controller = AuthController(FakeAuthService(), storage);

    await controller.restoreSession();

    expect(storage.hasLegacyPassword, isFalse);
    expect(storage.legacyClearCount, greaterThan(0));
  });

  test('expired unbound legacy tokens require login and never trigger refresh',
      () async {
    final storage = FakeSessionStorage(
      readCompleter: Completer<StoredAuthSession?>()
        ..complete(
          const StoredAuthSession(
              accessToken: 'expired-B',
              refreshToken: 'refresh-A',
              expiresAt: null),
        ),
    );
    final service = FakeAuthService(
      meError: const ApiException('expired',
          statusCode: 401, code: 'INVALID_SESSION'),
    );
    final controller = AuthController(service, storage);
    await controller.restoreSession();
    expect(service.refreshCalls, isEmpty);
    expect(controller.state.isAuthenticated, isFalse);
    expect(storage.clearCount, 1);
  });

  test(
      'valid legacy access is verified before the record gains a member binding',
      () async {
    final storage = FakeSessionStorage(
      readCompleter: Completer<StoredAuthSession?>()
        ..complete(
          const StoredAuthSession(
              accessToken: 'legacy-access',
              refreshToken: 'legacy-refresh',
              expiresAt: null),
        ),
    );
    final service = FakeAuthService();
    final controller = AuthController(service, storage);
    await controller.restoreSession();
    expect(service.meCalls, 1);
    expect(storage.saveCount, 1);
    expect(controller.accessToken, 'legacy-access');
  });

  test('rotation with a different member cannot restore a saved session',
      () async {
    final storage = FakeSessionStorage();
    await storage.save(_savedSession);
    final controller = AuthController(
        FakeAuthService(
          meError: const ApiException('expired',
              statusCode: 401, code: 'INVALID_SESSION'),
          refreshResult: const AuthSession(
            accessToken: 'wrong-access',
            refreshToken: 'wrong-refresh',
            expiresAt: null,
            user: fakeTeacher,
          ),
        ),
        storage);
    await controller.restoreSession();
    expect(controller.state.isAuthenticated, isFalse);
    expect(await storage.read(), isNull);
    expect(storage.saveCount, 1);
  });

  test('login cannot activate if it would leave old saved credentials in place',
      () async {
    final storage =
        FakeSessionStorage(clearError: StateError('private storage error'));
    await storage.save(_savedSession);
    final controller = AuthController(FakeAuthService(), storage);
    await expectLater(
        controller.login(
            email: 'other@example.invalid',
            password: 'test-only',
            rememberSession: false),
        throwsA(isA<ApiException>().having(
          (error) => error.code,
          'code',
          'SESSION_STORAGE_UNAVAILABLE',
        )));
    expect(controller.accessToken, isNull);
    expect((await storage.read())?.accessToken, 'saved-token');
    expect(controller.state.errorMessage,
        isNot(contains('private storage error')));
  });

  test('logout reports failed disk cleanup and blocks restoration in this run',
      () async {
    final storage =
        FakeSessionStorage(clearError: StateError('private storage error'));
    final service = FakeAuthService();
    final controller = AuthController(service, storage);
    await controller.login(
        email: 'aluno@example.invalid',
        password: 'test-only',
        rememberSession: true);
    await controller.logout();
    expect(service.logoutCalls, hasLength(1));
    expect(controller.state.errorMessage, contains('limpeza da sessão salva'));
    expect(controller.accessToken, isNull);
    await controller.restoreSession();
    expect(service.meCalls, 0);
  });

  test('confirmed inactive membership ends a session during rotation',
      () async {
    final storage = FakeSessionStorage();
    final controller = AuthController(
        FakeAuthService(
          refreshError: const ApiException('inactive',
              statusCode: 403, code: 'USER_INACTIVE'),
        ),
        storage);
    await controller.login(
        email: 'aluno@example.invalid',
        password: 'test-only',
        rememberSession: true);
    expect(
        await controller.refreshAccessToken(
            'access-token', fakeStudent.tenant.slug),
        isNull);
    expect(controller.state.isAuthenticated, isFalse);
    expect(await storage.read(), isNull);
  });
}

const _savedSession = AuthSession(
  accessToken: 'saved-token',
  refreshToken: 'saved-refresh',
  expiresAt: null,
  user: fakeStudent,
);

const _rotatedSession = AuthSession(
  accessToken: 'rotated-access',
  refreshToken: 'rotated-refresh',
  expiresAt: null,
  user: fakeStudent,
);
