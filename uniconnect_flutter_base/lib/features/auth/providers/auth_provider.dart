import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      : super(const AuthState.initial());

  final ApiAuthService _authService;
  final SessionStorage _sessionStorage;
  String? _accessToken;

  String? get accessToken => _accessToken;

  Future<void> restoreSession() async {
    final storedSession = await _sessionStorage.read();

    if (storedSession == null) {
      state = const AuthState(user: null, isRestoring: false);
      return;
    }

    try {
      final user = await _authService.me(storedSession.accessToken);
      _accessToken = storedSession.accessToken;
      state = AuthState(user: user, isRestoring: false);
    } catch (_) {
      await _sessionStorage.clear();
      _accessToken = null;
      state = const AuthState(user: null, isRestoring: false);
    }
  }

  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    final session = await _authService.login(
      email: email,
      password: password,
    );
    await _sessionStorage.save(session);
    _accessToken = session.accessToken;
    state = AuthState(user: session.user, isRestoring: false);
    return session.user;
  }

  Future<AppUser> loginWithGoogleMock() {
    return login(email: 'aluno@uni.com', password: '123456');
  }

  Future<void> logout() async {
    await _sessionStorage.clear();
    _accessToken = null;
    state = const AuthState(user: null, isRestoring: false);
  }
}
