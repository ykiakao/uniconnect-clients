class ApiConfig {
  const ApiConfig._();

  static const _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static const _productionBaseUrl =
      'https://api-uni.juancjc.com.br/api/v1';

  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) {
      return _configuredBaseUrl;
    }

    return _productionBaseUrl;
  }
}
