import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uniconnect/core/network/api_client.dart';
import 'package:uniconnect/features/activities/services/attachment_service.dart';

const fileId = '11111111-1111-4111-8111-111111111111';
Map<String, dynamic> ready() => {
      'id': fileId,
      'state': 'ready',
      'attachment': {
        'id': fileId,
        'name': 'answer.pdf',
        'contentType': 'application/pdf',
        'sizeBytes': 4
      }
    };
http.Response json(Object data, [int status = 200]) =>
    http.Response(jsonEncode(data), status);
AttachmentService service(
        Future<http.Response> Function(http.Request) handle) =>
    AttachmentService(
        ApiClient(
            baseUrl: 'https://api.invalid/api/v1',
            httpClient: MockClient(handle)),
        accessToken: 'synthetic',
        tenantSlug: 'campus',
        retryDelay: Duration.zero);

void main() {
  test('a foreign status cannot trigger another completion request', () async {
    var posts = 0;
    final api = service((r) async {
      if (r.method == 'POST') {
        posts++;
        return json({'id': fileId, 'state': 'validating'}, 202);
      }
      return json({'id': 'another-file', 'state': 'pending'});
    });
    await expectLater(
        api.complete(fileId), throwsA(isA<AttachmentConfirmationPending>()));
    expect(posts, 1);
  });
  test('later recovery reads the retained file after an indeterminate result',
      () async {
    final methods = <String>[];
    var offline = true;
    final api = service((r) async {
      methods.add(r.method);
      expect(r.url.path.contains(fileId), isTrue);
      if (r.method == 'POST') throw TimeoutException('synthetic');
      if (offline) throw http.ClientException('synthetic');
      return json(ready());
    });
    await expectLater(
        api.complete(fileId),
        throwsA(isA<AttachmentConfirmationPending>()
            .having((e) => e.fileId, 'retained file', fileId)));
    offline = false;
    expect((await api.recover(fileId)).id, fileId);
    expect((await api.recover(fileId)).id, fileId);
    expect(methods, ['POST', 'GET', 'GET', 'GET']);
  });
  test('processing timeout reports pending rather than cancellation', () async {
    final api = service((r) async {
      if (r.method == 'POST') throw TimeoutException('synthetic');
      return json({'id': fileId, 'state': 'validating'});
    });
    await expectLater(
        api.complete(fileId),
        throwsA(isA<AttachmentConfirmationPending>()
            .having((e) => e.state, 'state', 'validating')));
  });
  for (final state in [
    'cancelled',
    'rejected',
    'expired',
    'deleting',
    'deleted'
  ]) {
    test('recovery preserves terminal state $state', () async {
      final api = service((r) async {
        expect(r.method, 'GET');
        return json({'id': fileId, 'state': state});
      });
      await expectLater(
          api.recover(fileId),
          throwsA(isA<ApiException>()
              .having((e) => e.code, 'code', 'ATTACHMENT_UPLOAD_INELIGIBLE')
              .having(
                  (e) => e.message.contains(state), 'terminal state', isTrue)));
    });
  }
  test('a failed processing lookup remains indeterminate', () async {
    final api = service((r) async {
      if (r.method == 'POST') {
        return json({'id': fileId, 'state': 'validating'}, 202);
      }
      return json({
        'error': {'code': 'UNAVAILABLE', 'message': 'Synthetic outage'}
      }, 503);
    });
    await expectLater(
        api.complete(fileId), throwsA(isA<AttachmentConfirmationPending>()));
  });
  test('a lost dependency response is recovered through status', () async {
    final api = service((r) async => r.method == 'POST'
        ? json({
            'error': {'code': 'UNAVAILABLE', 'message': 'Synthetic outage'}
          }, 503)
        : json(ready()));
    expect((await api.complete(fileId)).id, fileId);
  });
  test('ready metadata for another file never confirms the requested file',
      () async {
    final row = ready();
    (row['attachment'] as Map<String, dynamic>)['id'] = 'another-file';
    final api = service((r) async => json(row));
    await expectLater(
        api.complete(fileId), throwsA(isA<AttachmentConfirmationPending>()));
  });
  test('F1 accepts ready from the final permitted status response', () async {
    var gets = 0;
    final api = service((r) async {
      if (r.method == 'POST') {
        return json({'id': fileId, 'state': 'validating'}, 202);
      }
      gets++;
      return json(gets == 10 ? ready() : {'id': fileId, 'state': 'validating'});
    });
    expect((await api.complete(fileId)).id, fileId);
    expect(gets, 10);
  });
  test('F2 recognizes ready after completion times out', () async {
    final methods = <String>[];
    final api = service((r) async {
      methods.add(r.method);
      if (r.method == 'POST') throw TimeoutException('synthetic');
      return json(ready());
    });
    expect((await api.complete(fileId)).id, fileId);
    expect(methods, ['POST', 'GET']);
  });
  test('F2 follows processing state after timeout without resending complete',
      () async {
    var gets = 0;
    final methods = <String>[];
    final api = service((r) async {
      methods.add(r.method);
      if (r.method == 'POST') throw TimeoutException('synthetic');
      return json(
          ++gets == 2 ? ready() : {'id': fileId, 'state': 'validating'});
    });
    expect((await api.complete(fileId)).id, fileId);
    expect(methods, ['POST', 'GET', 'GET']);
  });
  test('F2 preserves a confirmed cancelled state after timeout', () async {
    final methods = <String>[];
    final api = service((r) async {
      methods.add(r.method);
      if (r.method == 'POST') throw TimeoutException('synthetic');
      return json({'id': fileId, 'state': 'cancelled'});
    });
    await expectLater(
        api.complete(fileId),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', 'ATTACHMENT_UPLOAD_INELIGIBLE')));
    expect(methods, ['POST', 'GET']);
  });
  test('F2 reports indeterminate state if the status lookup also fails',
      () async {
    final methods = <String>[];
    final api = service((r) async {
      methods.add(r.method);
      if (r.method == 'POST') throw TimeoutException('synthetic');
      throw http.ClientException('synthetic');
    });
    await expectLater(
        api.complete(fileId),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', 'ATTACHMENT_CONFIRMATION_PENDING')));
    expect(methods, ['POST', 'GET']);
  });
  test('F2 limits processing checks and keeps the reservation recoverable',
      () async {
    var gets = 0;
    final api = service((r) async {
      if (r.method == 'POST') {
        return json({'id': fileId, 'state': 'validating'}, 202);
      }
      gets++;
      return json({'id': fileId, 'state': 'validating'});
    });
    await expectLater(
        api.complete(fileId),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', 'ATTACHMENT_CONFIRMATION_PENDING')));
    expect(gets, 10);
  });
  test(
      'inconclusive ready metadata is not treated as success or definite failure',
      () async {
    final api = service((r) async => json({'id': fileId, 'state': 'ready'}));
    await expectLater(
        api.complete(fileId),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', 'ATTACHMENT_CONFIRMATION_PENDING')));
  });
  test('definitive format errors remain definitive without status retry',
      () async {
    final methods = <String>[];
    final api = service((r) async {
      methods.add(r.method);
      return json({
        'error': {
          'code': 'ATTACHMENT_FORMAT_REJECTED',
          'message': 'Invalid file'
        }
      }, 415);
    });
    await expectLater(
        api.complete(fileId),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'status', 415)
            .having((e) => e.code, 'code', 'ATTACHMENT_FORMAT_REJECTED')));
    expect(methods, ['POST']);
  });
  test(
      'pending recovery reconfirms the same file without reserving or uploading again',
      () async {
    final methods = <String>[];
    var posts = 0;
    final api = service((r) async {
      expect(r.url.path.contains(fileId), isTrue);
      methods.add(r.method);
      if (r.method == 'POST') {
        if (++posts == 1) throw TimeoutException('synthetic');
        return json(ready());
      }
      return json({'id': fileId, 'state': 'pending'});
    });
    expect((await api.complete(fileId)).id, fileId);
    expect(methods, ['POST', 'GET', 'GET', 'POST']);
  });
  test(
      'repeated confirmation uses the same file and does not reserve another upload',
      () async {
    final calls = <String>[];
    final api = service((r) async {
      calls.add(r.url.path);
      return json(ready());
    });
    expect((await api.complete(fileId)).id, fileId);
    expect((await api.complete(fileId)).id, fileId);
    expect(
        calls,
        List.filled(
            2, '/api/v1/tenants/campus/attachment-uploads/$fileId/complete'));
  });
}
