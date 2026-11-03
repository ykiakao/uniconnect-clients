// TODO(tech-debt): migrar para NotifierProvider quando estável.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/api_client.dart';
import '../../../core/tenant/tenant_config.dart';
import '../models/app_user.dart';
import '../services/api_auth_service.dart';
import '../services/session_storage.dart';

final Provider<ApiClient> apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    refreshAccessToken: (token, tenant) => ref
        .read(authControllerProvider.notifier)
        .refreshAccessToken(token, tenant),
  );
});

final apiAuthServiceProvider = Provider<ApiAuthService>((ref) {
  return ApiAuthService(ref.watch(apiClientProvider));
});

final sessionStorageProvider = Provider<SessionStorage>((ref) {
  const storage = FlutterSecureStorage();
  return const SessionStorage(storage);
});

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(
    ref.watch(apiAuthServiceProvider),
    ref.watch(sessionStorageProvider),
  )..restoreSession();
});

final currentUserProvider = Provider<AppUser?>((ref) {
  return ref.watch(authControllerProvider).user;
});

class AuthController extends StateNotifier<AuthState> {
  AuthController(
    this._authService,
    this._sessionStorage, {
    this.storageTimeout = const Duration(seconds: 4),
  }) : super(const AuthState.restoring());

  final ApiAuthService _authService;
  final SessionStorage _sessionStorage;
  final Duration storageTimeout;

  AuthSession? _session;
  String? _previousAccessToken;
  bool _rememberSession = false;
  bool _allowRestore = true;
  int _generation = 0;
  Future<void>? _restoring;
  Future<void>? _loggingOut;
  Future<AuthSession>? _refreshing;
  Future<void> _storageWrites = Future<void>.value();

  String? get accessToken => state.accessToken;

  bool _isCurrent(int generation) => mounted && generation == _generation;

  Future<void> restoreSession() {
    if (!_allowRestore || _session != null) return Future<void>.value();
    return _restoring ??= _restore().whenComplete(() => _restoring = null);
  }

  Future<void> _restore() async {
    final generation = _generation;
    state = const AuthState.restoring();
    try {
      await _sessionStorage.clearLegacyCredentials().timeout(storageTimeout);
      final stored = await _sessionStorage.read().timeout(storageTimeout);
      if (!_isCurrent(generation)) return;
      if (stored == null) {
        state = const AuthState.unauthenticated();
        return;
      }

      final tenantSlug = stored.tenantSlug ?? getActiveTenantSlug();
      try {
        final user =
            await _authService.me(stored.accessToken, tenantSlug: tenantSlug);
        if (!_isCurrent(generation)) return;
        if (stored.userId != null && user.id != stored.userId) {
          await _endSession();
          return;
        }
        final session = AuthSession(
          accessToken: stored.accessToken,
          refreshToken: stored.refreshToken,
          expiresAt: stored.expiresAt,
          user: user,
        );
        if (stored.userId == null) {
          await _saveSessionSafely(session, generation);
        }
        if (!_isCurrent(generation)) return;
        _rememberSession = true;
        _activate(session);
      } on ApiException catch (error) {
        if (!_isCurrent(generation)) return;
        if (error.statusCode != 401 || error.code != 'INVALID_SESSION') rethrow;
        final userId = stored.userId;
        if (userId == null) {
          // Legacy tokens were written separately and have no verified binding.
          await _endSession(
              message: 'Sessão antiga expirada. Entre novamente.');
          return;
        }
        await _rotate(
          refreshToken: stored.refreshToken,
          tenantSlug: tenantSlug,
          generation: generation,
          remember: true,
          userId: userId,
        );
      }
    } catch (error) {
      if (!_isCurrent(generation)) return;
      if (_isInvalidSession(error) || error is UnsupportedUserRole) {
        await _endSession(
            message: error is UnsupportedUserRole ? error.message : null);
      } else {
        state = const AuthState.unauthenticated(
          message: 'Não foi possível restaurar a sessão. Tente novamente.',
          canRetryRestore: true,
        );
      }
    }
  }

  Future<AppUser> login({
    required String email,
    required String password,
    required bool rememberSession,
  }) async {
    if (_loggingOut != null) await _loggingOut;
    final generation = ++_generation;
    _refreshing = null;
    _previousAccessToken = null;
    late final AuthSession session;

    try {
      session = await _authService.login(email: email, password: password);
    } catch (error) {
      if (_isCurrent(generation)) {
        state = AuthState.error(_friendlyAuthError(error));
      }
      rethrow;
    }

    if (!_isCurrent(generation)) {
      throw const ApiException('Login interrompido.');
    }
    final storageSafe = rememberSession
        ? await _saveSessionSafely(session, generation)
        : await _clearStoredSessionSafely();
    if (!_isCurrent(generation)) {
      throw const ApiException('Login interrompido.');
    }
    if (!storageSafe) {
      const error = ApiException(
        sessionStorageUnavailableMessage,
        code: 'SESSION_STORAGE_UNAVAILABLE',
      );
      state = AuthState.error(error.message);
      throw error;
    }
    _rememberSession = rememberSession;
    _activate(session);
    return session.user;
  }

  Future<String?> refreshAccessToken(
      String rejectedToken, String? tenantSlug) async {
    final session = _session;
    if (session == null || tenantSlug != session.user.tenant.slug) return null;
    if (rejectedToken != session.accessToken) {
      return rejectedToken == _previousAccessToken ? session.accessToken : null;
    }

    final generation = _generation;
    try {
      final renewed = await _rotate(
        refreshToken: session.refreshToken,
        tenantSlug: session.user.tenant.slug,
        generation: generation,
        remember: _rememberSession,
        userId: session.user.id,
      );
      return _isCurrent(generation) ? renewed.accessToken : null;
    } catch (error) {
      if (_isCurrent(generation) &&
          (_isInvalidSession(error) || error is UnsupportedUserRole)) {
        await _endSession(
            message: error is UnsupportedUserRole ? error.message : null);
      }
      return null;
    }
  }

  Future<AuthSession> _rotate({
    required String refreshToken,
    required String tenantSlug,
    required int generation,
    required bool remember,
    required String userId,
  }) {
    if (_refreshing != null) return _refreshing!;
    late final Future<AuthSession> operation;
    operation = _renew(
      refreshToken,
      tenantSlug,
      generation,
      remember,
      userId,
    ).whenComplete(() {
      if (identical(_refreshing, operation)) _refreshing = null;
    });
    return _refreshing = operation;
  }

  Future<AuthSession> _renew(
    String refreshToken,
    String tenantSlug,
    int generation,
    bool remember,
    String userId,
  ) async {
    final renewed =
        await _authService.refresh(refreshToken, tenantSlug: tenantSlug);
    if (renewed.user.tenant.slug != tenantSlug || renewed.user.id != userId) {
      throw const ApiException('Sessão inválida.',
          statusCode: 401, code: 'INVALID_SESSION');
    }
    if (renewed.refreshToken == refreshToken) {
      throw const FormatException('Resposta de sessão sem rotação.');
    }
    if (_isCurrent(generation) && remember) {
      await _saveSessionSafely(renewed, generation);
    }
    if (_isCurrent(generation)) {
      _rememberSession = remember;
      _previousAccessToken = _session?.accessToken;
      _activate(renewed);
    }
    return renewed;
  }

  void _activate(AuthSession session) {
    _session = session;
    state =
        AuthState.authenticated(session.user, accessToken: session.accessToken);
  }

  Future<void> logout() =>
      _loggingOut ??= _logout().whenComplete(() => _loggingOut = null);

  Future<void> _logout() async {
    final session = _session;
    final pending = _refreshing;
    final localCleanup = _endSession();
    final generation = _generation;
    var remoteFailed = false;
    try {
      AuthSession? renewed;
      try {
        renewed = await pending;
      } catch (_) {
        // Use the last known session if rotation failed.
      }
      final target = renewed ?? session;
      if (target != null) {
        await _authService.logout(target.accessToken,
            tenantSlug: target.user.tenant.slug);
      }
    } catch (_) {
      remoteFailed = true;
    }
    final cleared = await localCleanup;
    if (_isCurrent(generation) && (!cleared || remoteFailed)) {
      state = AuthState.unauthenticated(
        message: !cleared
            ? 'O acesso foi encerrado. Não foi possível confirmar a limpeza da sessão salva.'
            : 'Você saiu deste dispositivo. Não foi possível confirmar o encerramento remoto.',
      );
    }
  }

  Future<bool> _endSession({String? message}) {
    ++_generation;
    _allowRestore = false;
    _session = null;
    _previousAccessToken = null;
    _refreshing = null;
    _rememberSession = false;
    state = AuthState.unauthenticated(message: message);
    return _clearStoredSessionSafely();
  }

  bool _isInvalidSession(Object error) =>
      error is ApiException &&
      ((error.statusCode == 401 && error.code == 'INVALID_SESSION') ||
          (error.statusCode == 403 &&
              (error.code == 'USER_NOT_LINKED_TO_TENANT' ||
                  error.code == 'USER_INACTIVE')));

  Future<void> _writeStorage(Future<void> Function() write) {
    // Keep mutations ordered even if a caller stops waiting after a timeout.
    final operation = _storageWrites.then((_) => write());
    _storageWrites =
        operation.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return operation.timeout(storageTimeout);
  }

  Future<bool> _saveSessionSafely(AuthSession session, int generation) async {
    try {
      await _writeStorage(() => _sessionStorage.save(session));
      return true;
    } catch (_) {
      return _isCurrent(generation) && await _clearStoredSessionSafely();
    }
  }

  Future<bool> _clearStoredSessionSafely() async {
    try {
      await _writeStorage(_sessionStorage.clear);
      return true;
    } catch (_) {
      return false;
    }
  }

  String _friendlyAuthError(Object error) {
    if (error is UnsupportedUserRole) return error.message;
    if (error is ApiException && error.statusCode == 401) {
      return 'E-mail ou senha incorretos';
    }
    return 'Não foi possível entrar. Tente novamente.';
  }
}
