import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/app_user.dart';
import 'api_auth_service.dart';

const sessionStorageUnavailableMessage =
    'Não foi possível substituir ou limpar a sessão salva. Tente novamente.';

class StoredAuthSession {
  const StoredAuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    this.tenantSlug,
    this.userId,
  });

  final String accessToken;
  final String refreshToken;
  final int? expiresAt;
  final String? tenantSlug;
  final String? userId;
}

class SessionStorage {
  const SessionStorage(this._storage);

  static const _sessionKey = 'auth.session';
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
    await _storage.write(
        key: _sessionKey,
        value: jsonEncode({
          'accessToken': session.accessToken,
          'refreshToken': session.refreshToken,
          'expiresAt': session.expiresAt,
          'tenantSlug': session.user.tenant.slug,
          'userId': session.user.id,
        }));
    await _clearLegacySession();
  }

  Future<StoredAuthSession?> read() async {
    await clearLegacyCredentials();

    final encoded = await _storage.read(key: _sessionKey);
    if (encoded != null) {
      if (encoded.isEmpty) return null;
      try {
        final record = jsonDecode(encoded);
        if (record is! Map<String, dynamic>) return null;
        final access = record['accessToken'];
        final refresh = record['refreshToken'];
        final tenant = record['tenantSlug'];
        final userId = record['userId'];
        if (access is! String ||
            access.trim().isEmpty ||
            refresh is! String ||
            refresh.trim().isEmpty ||
            tenant is! String ||
            tenant.trim().isEmpty ||
            userId is! String ||
            userId.trim().isEmpty) {
          return null;
        }
        final expiry = record['expiresAt'];
        return StoredAuthSession(
            accessToken: access,
            refreshToken: refresh,
            expiresAt: expiry is int ? expiry : null,
            tenantSlug: tenant,
            userId: userId);
      } on FormatException {
        return null;
      }
    }

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

  Future<void> clear() async {
    // An empty record blocks legacy fallback even if deletion is interrupted.
    try {
      await _storage.write(key: _sessionKey, value: '');
    } catch (_) {
      // Some storage failures affect writes but still allow deleting the keys.
    }
    await _clearLegacySession();
    await _storage.delete(key: _sessionKey);
    await clearLegacyCredentials();
  }

  Future<void> _clearLegacySession() {
    return Future.wait([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
      _storage.delete(key: _expiresAtKey),
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
    this.canRetryRestore = false,
  });

  const AuthState.restoring() : this(status: AuthStatus.restoring);

  const AuthState.unauthenticated(
      {String? message, bool canRetryRestore = false})
      : this(
            status: AuthStatus.unauthenticated,
            errorMessage: message,
            canRetryRestore: canRetryRestore);

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
  final bool canRetryRestore;

  bool get isRestoring => status == AuthStatus.restoring;
  bool get isAuthenticated =>
      status == AuthStatus.authenticated && user != null;
  UserRole? get role => user?.role;
  String? get tenantSlug => user?.tenant.slug;
}
