// TODO(tech-debt): migrar para NotifierProvider quando estável.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/api_client.dart';
import '../../../core/notifications/push_auth_listener.dart';
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
  final pushCoordinator = ref.watch(pushRegistrationCoordinatorProvider);
  return AuthController(
    ref.watch(apiAuthServiceProvider),
    ref.watch(sessionStorageProvider),
    beforeRemoteLogout: pushCoordinator.beforeRemoteLogout,
  )..restoreSession();
});

final currentUserProvider = Provider<AppUser?>((ref) {
  return ref.watch(authControllerProvider).user;
});

enum SessionRenewal { idle, pending, failed }

class AuthController extends StateNotifier<AuthState> {
  AuthController(
    this._authService,
    this._sessionStorage, {
    this.storageTimeout = const Duration(seconds: 4),
    this.beforeRemoteLogout,
  }) : super(const AuthState.restoring());

  final ApiAuthService _authService;
  final SessionStorage _sessionStorage;
  final Duration storageTimeout;
  final Future<void> Function(String accessToken, String tenantSlug)?
      beforeRemoteLogout;
  final _renewal = ValueNotifier(SessionRenewal.idle);
  ValueListenable<SessionRenewal> get renewal => _renewal;

  AuthSession? _session;
  String? _previousAccessToken;
  bool _rememberSession = false;
  bool _allowRestore = true;
  int _generation = 0;
  int _logoutGeneration = 0;
  Future<void>? _restoring;
  Future<void>? _loggingOut;
  Future<AuthSession>? _refreshing;
  Future<void> _storageWrites = Future<void>.value();

  String? get accessToken => state.accessToken;

  /// Identifies a sign-in lifecycle across access token renewals.
  int get sessionGeneration => _generation;
  int get logoutGeneration => _logoutGeneration;

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

  Future<void> retryRenewal() async {
    final session = _session;
    if (session == null || _renewal.value != SessionRenewal.failed) return;
    await refreshAccessToken(session.accessToken, session.user.tenant.slug);
  }

  Future<String?> refreshAccessToken(
      String rejectedToken, String? tenantSlug) async {
    final session = _session;
    if (session == null || tenantSlug != session.user.tenant.slug) return null;
    if (rejectedToken != session.accessToken) {
      return rejectedToken == _previousAccessToken ? session.accessToken : null;
    }

    final generation = _generation;
    _renewal.value = SessionRenewal.pending;
    try {
      final renewed = await _rotate(
        refreshToken: session.refreshToken,
        tenantSlug: session.user.tenant.slug,
        generation: generation,
        remember: _rememberSession,
        userId: session.user.id,
      );
      if (!_isCurrent(generation)) return null;
      _renewal.value = SessionRenewal.idle;
      return renewed.accessToken;
    } catch (error) {
      if (!_isCurrent(generation)) return null;
      if (_isInvalidSession(error) || error is UnsupportedUserRole) {
        await _endSession(
            message: error is UnsupportedUserRole ? error.message : null);
      } else {
        _renewal.value = SessionRenewal.failed;
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
    _logoutGeneration++;
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
        try {
          final cleanup = beforeRemoteLogout;
          if (cleanup != null) {
            await cleanup(target.accessToken, target.user.tenant.slug)
                .timeout(const Duration(seconds: 3));
          }
        } catch (_) {
          // Falha no FCM nao deve impedir o logout.
        }
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
    _renewal.value = SessionRenewal.idle;
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

  @override
  void dispose() {
    _renewal.dispose();
    super.dispose();
  }

  String _friendlyAuthError(Object error) {
    if (error is UnsupportedUserRole) return error.message;
    if (error is ApiException && error.statusCode == 401) {
      return 'E-mail ou senha incorretos';
    }
    return 'Não foi possível entrar. Tente novamente.';
  }
}
