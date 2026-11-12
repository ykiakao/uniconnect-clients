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

    return _sessionFromResponse(response, tenantSlug);
  }

  /// Always answers the same way, so it never reveals whether an account
  /// exists for [email].
  Future<void> requestPasswordRecovery(String email) async {
    await _apiClient.post('/auth/password/recovery', {'email': email});
  }

  Future<AuthSession> refresh(String refreshToken,
      {required String tenantSlug}) async {
    final response = await _apiClient.post(
      '/auth/refresh',
      {'refreshToken': refreshToken},
      tenantSlug: tenantSlug,
    );
    return _sessionFromResponse(response, tenantSlug);
  }

  Future<void> logout(String accessToken, {required String tenantSlug}) async {
    await _apiClient.post('/auth/logout', const {},
        accessToken: accessToken, tenantSlug: tenantSlug);
  }

  AuthSession _sessionFromResponse(
      Map<String, dynamic> response, String tenantSlug) {
    final userJson = response['user'] as Map<String, dynamic>;
    final tenant = _tenantFromResponse(response, userJson, tenantSlug);
    final user = AppUser.fromJson(
      userJson,
      tenant: tenant,
    );

    final accessToken = response['accessToken'];
    final refreshToken = response['refreshToken'];
    if (accessToken is! String ||
        accessToken.trim().isEmpty ||
        refreshToken is! String ||
        refreshToken.trim().isEmpty) {
      throw const FormatException('Resposta de sessão inválida.');
    }
    return AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: _parseExpiresAt(response['expiresAt']),
      user: user,
    );
  }

  Future<AppUser> me(String accessToken, {String? tenantSlug}) async {
    tenantSlug ??= getActiveTenantSlug();
    final response = await _apiClient.get(
      '/auth/me',
      accessToken: accessToken,
      tenantSlug: tenantSlug,
    );
    final userJson = response['user'] is Map<String, dynamic>
        ? response['user'] as Map<String, dynamic>
        : response;
    final tenant = _tenantFromResponse(response, userJson, tenantSlug);

    return AppUser.fromJson(
      userJson,
      tenant: tenant,
    );
  }

  TenantContext _tenantFromResponse(
    Map<String, dynamic> response,
    Map<String, dynamic> userJson,
    String expectedSlug,
  ) {
    final tenantJson = response['tenant'];
    final userSlug = userJson['tenantSlug'];
    if ((userSlug != null && userSlug != expectedSlug) ||
        (tenantJson is Map<String, dynamic> &&
            tenantJson['slug'] != expectedSlug)) {
      throw const FormatException('Contexto institucional inválido.');
    }
    if (tenantJson is Map<String, dynamic>) {
      return TenantContext.fromJson(tenantJson);
    }

    return TenantContext(
      id: '',
      name: 'Universidade Norte',
      slug: expectedSlug,
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
