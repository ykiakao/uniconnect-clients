import 'package:flutter/foundation.dart';

class ApiConfig {
  const ApiConfig._();

  static const _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) return _configuredBaseUrl;

    if (kIsWeb) return 'http://localhost:3333/api/v1';

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'http://10.0.2.2:3333/api/v1',
      _ => 'http://localhost:3333/api/v1',
    };
  }
}
