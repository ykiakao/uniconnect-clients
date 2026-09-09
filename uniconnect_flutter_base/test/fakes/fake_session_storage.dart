import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uniconnect/features/auth/services/api_auth_service.dart';
import 'package:uniconnect/features/auth/services/session_storage.dart';

class FakeSessionStorage extends SessionStorage {
  FakeSessionStorage({
    this.saveCompleter,
    this.readCompleter,
    this.saveError,
    this.readError,
  }) : super(const FlutterSecureStorage());

  StoredAuthSession? _session;
  final Completer<void>? saveCompleter;
  final Completer<StoredAuthSession?>? readCompleter;
  final Object? saveError;
  final Object? readError;
  bool hasLegacyPassword = false;
  int saveCount = 0;
  int clearCount = 0;
  int legacyClearCount = 0;

  @override
  Future<void> save(AuthSession session) async {
    saveCount++;
    if (saveCompleter != null) return saveCompleter!.future;
    if (saveError != null) throw saveError!;

    _session = StoredAuthSession(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      expiresAt: session.expiresAt,
    );
  }

  @override
  Future<StoredAuthSession?> read() async {
    if (readCompleter != null) return readCompleter!.future;
    if (readError != null) throw readError!;

    return _session;
  }

  @override
  Future<void> clear() async {
    clearCount++;
    _session = null;
    await clearLegacyCredentials();
  }

  @override
  Future<void> clearLegacyCredentials() async {
    legacyClearCount++;
    hasLegacyPassword = false;
  }
}
