import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/app_user.dart';
import 'api_auth_service.dart';

class StoredAuthSession {
  const StoredAuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final int? expiresAt;
}

class SessionStorage {
  const SessionStorage(this._storage);

  static const _accessTokenKey = 'auth.accessToken';
  static const _refreshTokenKey = 'auth.refreshToken';
  static const _expiresAtKey = 'auth.expiresAt';
  static const _legacyPasswordKeys = [
    'auth.password',
    'auth.senha',
    'password',
    'senha',
    'login.password',
  ];

  final FlutterSecureStorage _storage;

  Future<void> save(AuthSession session) async {
    await Future.wait([
      _storage.write(key: _accessTokenKey, value: session.accessToken),
      _storage.write(key: _refreshTokenKey, value: session.refreshToken),
      _storage.write(
        key: _expiresAtKey,
        value: session.expiresAt?.toString(),
      ),
    ]);
  }

  Future<StoredAuthSession?> read() async {
    await clearLegacyCredentials();

    final accessToken = await _storage.read(key: _accessTokenKey);
    final refreshToken = await _storage.read(key: _refreshTokenKey);

    if (accessToken == null || refreshToken == null) return null;

    final expiresAt = await _storage.read(key: _expiresAtKey);

    return StoredAuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: int.tryParse(expiresAt ?? ''),
    );
  }

  Future<void> clear() {
    return Future.wait([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
      _storage.delete(key: _expiresAtKey),
      clearLegacyCredentials(),
    ]);
  }

  Future<void> clearLegacyCredentials() {
    return Future.wait([
      for (final key in _legacyPasswordKeys) _storage.delete(key: key),
    ]);
  }
}

enum AuthStatus {
  restoring,
  unauthenticated,
  authenticated,
  error,
}

class AuthState {
  const AuthState({
    required this.status,
    this.user,
    this.accessToken,
    this.errorMessage,
  });

  const AuthState.restoring() : this(status: AuthStatus.restoring);

  const AuthState.unauthenticated() : this(status: AuthStatus.unauthenticated);

  const AuthState.authenticated(AppUser user, {required String accessToken})
      : this(
          status: AuthStatus.authenticated,
          user: user,
          accessToken: accessToken,
        );

  const AuthState.error(String message)
      : this(status: AuthStatus.error, errorMessage: message);

  final AuthStatus status;
  final AppUser? user;
  final String? accessToken;
  final String? errorMessage;

  bool get isRestoring => status == AuthStatus.restoring;
  bool get isAuthenticated =>
      status == AuthStatus.authenticated && user != null;
  UserRole? get role => user?.role;
  String? get tenantSlug => user?.tenant.slug;
}
