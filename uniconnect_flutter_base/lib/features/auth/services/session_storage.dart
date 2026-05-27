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
    ]);
  }
}

class AuthState {
  const AuthState({
    required this.user,
    required this.isRestoring,
  });

  const AuthState.initial() : this(user: null, isRestoring: true);

  final AppUser? user;
  final bool isRestoring;
}
