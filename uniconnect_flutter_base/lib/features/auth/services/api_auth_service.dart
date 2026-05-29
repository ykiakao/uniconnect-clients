import '../../../core/network/api_client.dart';
import '../../../core/tenant/tenant_config.dart';
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
    final tenantSlug = getActiveTenantSlug();
    final response = await _apiClient.post(
      '/auth/login',
      {
        'email': email,
        'password': password,
      },
      tenantSlug: tenantSlug,
    );

    final userJson = response['user'] as Map<String, dynamic>;
    final tenant = _tenantFromResponse(response, userJson);
    final user = AppUser.fromJson(
      userJson,
      tenant: tenant,
    );

    return AuthSession(
      accessToken: response['accessToken'] as String,
      refreshToken: response['refreshToken'] as String,
      expiresAt: _parseExpiresAt(response['expiresAt']),
      user: user,
    );
  }

  Future<AppUser> me(String accessToken) async {
    final tenantSlug = getActiveTenantSlug();
    final response = await _apiClient.get(
      '/auth/me',
      accessToken: accessToken,
      tenantSlug: tenantSlug,
    );
    final tenant = _tenantFromResponse(response, response);

    return AppUser.fromJson(
      response['user'] is Map<String, dynamic>
          ? response['user'] as Map<String, dynamic>
          : response,
      tenant: tenant,
    );
  }

  TenantContext _tenantFromResponse(
    Map<String, dynamic> response,
    Map<String, dynamic> userJson,
  ) {
    final tenantJson = response['tenant'];
    if (tenantJson is Map<String, dynamic>) {
      return TenantContext.fromJson(tenantJson);
    }

    return TenantContext(
      id: '',
      name: 'Universidade Norte',
      slug: userJson['tenantSlug'] as String? ?? getActiveTenantSlug(),
      plan: SubscriptionPlan.growth,
      status: SubscriptionStatus.trialing,
      activeUsers: 0,
    );
  }

  int? _parseExpiresAt(Object? value) {
    if (value is int) return value;
    if (value is String) {
      return DateTime.tryParse(value)?.millisecondsSinceEpoch;
    }

    return null;
  }
}
