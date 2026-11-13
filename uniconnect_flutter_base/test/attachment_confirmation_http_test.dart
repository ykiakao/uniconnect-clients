import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:uniconnect/core/network/api_client.dart';
import 'package:uniconnect/features/activities/services/attachment_service.dart';

void main() {
  test(
      'real local HTTP response timeout recovers ready with the default 12 second client',
      () async {
    const id = '11111111-1111-4111-8111-111111111111';
    final row = {
      'id': id,
      'state': 'ready',
      'attachment': {
        'id': id,
        'name': 'answer.pdf',
        'contentType': 'application/pdf',
        'sizeBytes': 4
      }
    };
    final release = Completer<void>();
    final postFinished = Completer<void>();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var posts = 0, gets = 0, deletes = 0;
    server.listen((request) async {
      await request.drain<void>();
      final post = request.method == 'POST';
      if (post) {
        posts++;
        await release.future;
      } else if (request.method == 'GET') {
        gets++;
      } else if (request.method == 'DELETE') {
        deletes++;
      }
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(row));
      await request.response.close();
      if (post) postFinished.complete();
    });
    final transport = http.Client();
    try {
      final client = ApiClient(
          baseUrl: Uri(
                  scheme: 'http',
                  host: '127.0.0.1',
                  port: server.port,
                  path: '/api/v1')
              .toString(),
          httpClient: transport);
      expect(client.timeout, const Duration(seconds: 12));
      final service = AttachmentService(client,
          accessToken: 'synthetic',
          tenantSlug: 'campus',
          retryDelay: Duration.zero);
      expect((await service.complete(id)).id, id);
      expect(posts, 1);
      expect(gets, 1);
      expect(deletes, 0);
    } finally {
      release.complete();
      if (posts > 0) {
        await postFinished.future.timeout(const Duration(seconds: 5));
      }
      transport.close();
      await server.close(force: true);
    }
  }, timeout: const Timeout(Duration(seconds: 30)));
}
