import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({
    http.Client? httpClient,
    String? baseUrl,
    this.timeout = const Duration(seconds: 12),
    this.refreshAccessToken,
  })  : _httpClient = httpClient ?? http.Client(),
        baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final http.Client _httpClient;
  final String baseUrl;
  final Duration timeout;
  final Future<String?> Function(String accessToken, String? tenantSlug)?
      refreshAccessToken;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? queryParams,
    String? accessToken,
    String? tenantSlug,
  }) {
    return _send(
      'GET',
      path,
      queryParams: queryParams,
      accessToken: accessToken,
      tenantSlug: tenantSlug,
    );
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    String? accessToken,
    String? tenantSlug,
    Map<String, String>? headers,
  }) {
    return _send(
      'POST',
      path,
      body: body,
      accessToken: accessToken,
      tenantSlug: tenantSlug,
      extraHeaders: headers,
    );
  }

  Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body, {
    String? accessToken,
    String? tenantSlug,
  }) {
    return _send(
      'PUT',
      path,
      body: body,
      accessToken: accessToken,
      tenantSlug: tenantSlug,
    );
  }

  Future<Map<String, dynamic>> patch(
    String path,
    Map<String, dynamic> body, {
    String? accessToken,
    String? tenantSlug,
  }) {
    return _send(
      'PATCH',
      path,
      body: body,
      accessToken: accessToken,
      tenantSlug: tenantSlug,
    );
  }

  /// Returns the decoded body (empty for 204).
  Future<Map<String, dynamic>> delete(
    String path, {
    String? accessToken,
    String? tenantSlug,
    Map<String, String>? queryParams,
  }) {
    return _send(
      'DELETE',
      path,
      queryParams: queryParams,
      accessToken: accessToken,
      tenantSlug: tenantSlug,
    );
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, String>? queryParams,
    Map<String, dynamic>? body,
    String? accessToken,
    String? tenantSlug,
    bool retrySession = true,
    Map<String, String>? extraHeaders,
  }) async {
    final uri = _buildUri(path, queryParams);
    final headers = {
      ..._buildHeaders(accessToken: accessToken, tenantSlug: tenantSlug),
      ...?extraHeaders,
    };

    late final http.Response response;

    try {
      response = await (switch (method) {
        'GET' => _httpClient.get(uri, headers: headers),
        'POST' => _httpClient.post(
            uri,
            headers: headers,
            body: jsonEncode(body ?? const {}),
          ),
        'PUT' => _httpClient.put(
            uri,
            headers: headers,
            body: jsonEncode(body ?? const {}),
          ),
        'PATCH' => _httpClient.patch(
            uri,
            headers: headers,
            body: jsonEncode(body ?? const {}),
          ),
        'DELETE' => _httpClient.delete(uri, headers: headers),
        _ => throw const ApiException('Método HTTP não suportado.'),
      })
          .timeout(timeout);
    } on TimeoutException {
      throw const ApiException(
        'Não foi possível conectar à API. Verifique sua conexão ou tente novamente.',
      );
    } on http.ClientException {
      throw const ApiException(
        'Não foi possível conectar à API. Verifique sua conexão ou tente novamente.',
      );
    }

    final decoded = _decodeResponse(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded['error'];
      final code = error is Map<String, dynamic> ? error['code'] : null;
      final refresh = refreshAccessToken;
      if (retrySession &&
          !path.startsWith('/auth/') &&
          accessToken != null &&
          response.statusCode == 401 &&
          code == 'INVALID_SESSION' &&
          refresh != null) {
        final replacement = await refresh(accessToken, tenantSlug);
        if (replacement != null && replacement != accessToken) {
          return _send(method, path,
              queryParams: queryParams,
              body: body,
              accessToken: replacement,
              tenantSlug: tenantSlug,
              retrySession: false,
              extraHeaders: extraHeaders);
        }
      }
      throw ApiException(
        _extractErrorMessage(decoded),
        statusCode: response.statusCode,
        code: code is String ? code : null,
      );
    }

    return decoded;
  }

  Uri _buildUri(String path, Map<String, String>? queryParams) {
    final uri = Uri.parse('$baseUrl$path');
    if (queryParams == null || queryParams.isEmpty) return uri;

    return uri.replace(
      queryParameters: {
        ...uri.queryParameters,
        ...queryParams,
      },
    );
  }

  Map<String, String> _buildHeaders({
    String? accessToken,
    String? tenantSlug,
  }) {
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (tenantSlug != null) 'x-tenant-slug': tenantSlug,
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
    };
  }

  Map<String, dynamic> _decodeResponse(String body) {
    if (body.isEmpty) return <String, dynamic>{};

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      throw const ApiException('A API retornou uma resposta inválida.');
    }

    throw const ApiException('A API retornou uma resposta inesperada.');
  }

  String _extractErrorMessage(Map<String, dynamic> decoded) {
    final error = decoded['error'];
    if (error is Map<String, dynamic>) {
      final message = error['message'];
      if (message is String && message.trim().isNotEmpty) return message;
    }

    final message = decoded['message'];
    if (message is String && message.trim().isNotEmpty) return message;

    return 'Erro ao comunicar com a API.';
  }
}
