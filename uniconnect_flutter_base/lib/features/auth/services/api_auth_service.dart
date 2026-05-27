import '../../../core/network/api_client.dart';
import '../../tenant/models/tenant_context.dart';
import '../models/app_user.dart';

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final int? expiresAt;
  final AppUser user;
}

class ApiAuthService {
  const ApiAuthService(this._apiClient);

  final ApiClient _apiClient;

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.post(
      '/auth/login',
      body: {
        'email': email,
        'password': password,
      },
    );

    final tenant = TenantContext.fromJson(
      response['tenant'] as Map<String, dynamic>,
    );
    final user = AppUser.fromJson(
      response['user'] as Map<String, dynamic>,
      tenant: tenant,
    );

    return AuthSession(
      accessToken: response['accessToken'] as String,
      refreshToken: response['refreshToken'] as String,
      expiresAt: response['expiresAt'] as int?,
      user: user,
    );
  }

  Future<AppUser> me(String accessToken) async {
    final response = await _apiClient.get('/auth/me', accessToken: accessToken);
    final tenant = TenantContext.fromJson(
      response['tenant'] as Map<String, dynamic>,
    );

    return AppUser.fromJson(
      response['user'] as Map<String, dynamic>,
      tenant: tenant,
    );
  }
}
