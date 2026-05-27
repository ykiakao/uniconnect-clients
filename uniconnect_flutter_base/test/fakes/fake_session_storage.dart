import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uniconnect/features/auth/services/api_auth_service.dart';
import 'package:uniconnect/features/auth/services/session_storage.dart';

class FakeSessionStorage extends SessionStorage {
  FakeSessionStorage() : super(const FlutterSecureStorage());

  StoredAuthSession? _session;
  bool hasLegacyPassword = false;
  int saveCount = 0;
  int clearCount = 0;
  int legacyClearCount = 0;

  @override
  Future<void> save(AuthSession session) async {
    saveCount++;
    _session = StoredAuthSession(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      expiresAt: session.expiresAt,
    );
  }

  @override
  Future<StoredAuthSession?> read() async => _session;

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
