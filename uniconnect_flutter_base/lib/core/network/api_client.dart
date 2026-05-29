import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({
    http.Client? httpClient,
    String? baseUrl,
    this.timeout = const Duration(seconds: 12),
  })  : _httpClient = httpClient ?? http.Client(),
        baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final http.Client _httpClient;
  final String baseUrl;
  final Duration timeout;

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
  }) {
    return _send(
      'POST',
      path,
      body: body,
      accessToken: accessToken,
      tenantSlug: tenantSlug,
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

  Future<void> delete(
    String path, {
    String? accessToken,
    String? tenantSlug,
  }) async {
    await _send(
      'DELETE',
      path,
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
  }) async {
    final uri = _buildUri(path, queryParams);
    final headers = _buildHeaders(
      accessToken: accessToken,
      tenantSlug: tenantSlug,
    );

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
      throw ApiException(
        _extractErrorMessage(decoded),
        statusCode: response.statusCode,
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
