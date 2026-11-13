import '../network/api_client.dart';

class PushDeviceRegistration {
  const PushDeviceRegistration(this.apiClient);

  final ApiClient apiClient;

  Future<void> unregister({
    required String accessToken,
    required String tenantSlug,
    required String token,
  }) async {
    await apiClient.delete(
      '/tenants/$tenantSlug/notifications/devices',
      body: {'token': token},
      accessToken: accessToken,
      tenantSlug: tenantSlug,
    );
  }

  Future<void> register({
    required String accessToken,
    required String tenantSlug,
    required String token,
  }) async {
    await apiClient.post(
      '/tenants/$tenantSlug/notifications/devices',
      {'token': token},
      accessToken: accessToken,
      tenantSlug: tenantSlug,
    );
  }
}
