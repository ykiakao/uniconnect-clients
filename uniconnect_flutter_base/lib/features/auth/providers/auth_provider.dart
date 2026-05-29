// TODO(tech-debt): migrar para NotifierProvider quando estável.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/api_client.dart';
import '../models/app_user.dart';
import '../services/api_auth_service.dart';
import '../services/session_storage.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
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
  AuthController(this._authService, this._sessionStorage)
      : super(const AuthState.restoring());

  final ApiAuthService _authService;
  final SessionStorage _sessionStorage;

  String? get accessToken => state.accessToken;

  Future<void> restoreSession() async {
    state = const AuthState.restoring();
    await _sessionStorage.clearLegacyCredentials();

    final storedSession = await _sessionStorage.read();

    if (storedSession == null) {
      state = const AuthState.unauthenticated();
      return;
    }

    try {
      final user = await _authService.me(storedSession.accessToken);
      state = AuthState.authenticated(
        user,
        accessToken: storedSession.accessToken,
      );
    } catch (_) {
      // TODO(backend): implementar refresh token quando /auth/refresh
      // estiver definido. Limpar sessão por enquanto.
      await _sessionStorage.clear();
      state = const AuthState.unauthenticated();
    }
  }

  Future<AppUser> login({
    required String email,
    required String password,
    required bool rememberSession,
  }) async {
    late final AuthSession session;

    try {
      session = await _authService.login(
        email: email,
        password: password,
      );
    } catch (error) {
      state = AuthState.error(_friendlyAuthError(error));
      rethrow;
    }

    if (rememberSession) {
      await _sessionStorage.save(session);
    } else {
      await _sessionStorage.clear();
    }

    state = AuthState.authenticated(
      session.user,
      accessToken: session.accessToken,
    );
    return session.user;
  }

  Future<void> logout() async {
    await _sessionStorage.clear();
    state = const AuthState.unauthenticated();
  }

  String _friendlyAuthError(Object error) {
    if (error is ApiException && error.statusCode == 401) {
      return 'E-mail ou senha incorretos';
    }

    return 'Não foi possível entrar. Tente novamente.';
  }
}
