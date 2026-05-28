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
    this.tenantSlug = 'universidade-norte',
  })  : _httpClient = httpClient ?? http.Client(),
        baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final http.Client _httpClient;
  final String baseUrl;
  final String tenantSlug;

  Future<Map<String, dynamic>> get(String path, {String? accessToken}) {
    return _send('GET', path, accessToken: accessToken);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) {
    return _send('POST', path, body: body);
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? accessToken,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'x-tenant-slug': tenantSlug,
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
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
        _ => throw ApiException('Método HTTP não suportado: $method'),
      })
          .timeout(const Duration(seconds: 12));
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
        decoded['message']?.toString() ?? 'Erro ao comunicar com a API.',
        statusCode: response.statusCode,
      );
    }

    return decoded;
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
}
