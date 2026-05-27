import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uniconnect/features/auth/services/api_auth_service.dart';
import 'package:uniconnect/features/auth/services/session_storage.dart';

class FakeSessionStorage extends SessionStorage {
  FakeSessionStorage() : super(const FlutterSecureStorage());

  StoredAuthSession? _session;

  @override
  Future<void> save(AuthSession session) async {
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
    _session = null;
  }
}
