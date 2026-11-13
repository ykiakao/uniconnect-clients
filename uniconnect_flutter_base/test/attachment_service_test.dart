import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uniconnect/core/network/api_client.dart';
import 'package:uniconnect/features/activities/models/academic_attachment.dart';
import 'package:uniconnect/features/activities/services/attachment_service.dart';
import 'package:uniconnect/features/activities/services/student_submission_service.dart';
import 'package:uniconnect/features/activities/widgets/submission_attachments.dart';

const _storageHost = 'project.supabase.co';
const _fileId = '11111111-1111-4111-8111-111111111111';

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'});

Map<String, dynamic> _attachment([String name = 'resposta.pdf']) => {
      'id': _fileId,
      'name': name,
      'contentType': 'application/pdf',
      'sizeBytes': 4,
      'createdAt': '2026-11-12T21:00:00.000Z',
    };

/// Fake API + Storage recording what each side received.
class _Fake {
  final api = <http.Request>[];
  final storage = <http.Request>[];
  int completeCalls = 0;
  bool firstCompleteBusy = false;
  bool storageFails = false;

  AttachmentService service() => AttachmentService(
        ApiClient(
            baseUrl: 'https://api.invalid/api/v1',
            httpClient: MockClient(_api)),
        accessToken: 'uniconnect-token',
        tenantSlug: 'campus',
        storageHost: _storageHost,
        storageClient: MockClient((request) async {
          storage.add(request);
          return storageFails ? http.Response('', 400) : http.Response('', 200);
        }),
        retryDelay: Duration.zero,
      );

  Future<http.Response> _api(http.Request request) async {
    api.add(request);
    final path = request.url.path;
    if (path.endsWith('/submissions/attachment-uploads')) {
      return _json({
        'id': _fileId,
        'state': 'pending',
        'upload': {
          'url': 'https://$_storageHost/storage/v1/upload/sign/x?token=t',
          'method': 'PUT',
          'headers': {'Content-Type': 'application/pdf', 'x-upsert': 'false'},
        },
      }, 201);
    }
    if (path.endsWith('/complete')) {
      completeCalls++;
      if (firstCompleteBusy && completeCalls == 1) {
        return _json({'id': _fileId, 'state': 'validating'}, 202);
      }
      return _json(
          {'id': _fileId, 'state': 'ready', 'attachment': _attachment()});
    }
    if (request.method == 'GET' &&
        path.endsWith('/attachment-uploads/$_fileId')) {
      return _json(
          {'id': _fileId, 'state': 'ready', 'attachment': _attachment()});
    }
    if (request.method == 'DELETE') return http.Response('', 204);
    if (path.endsWith('/download-url')) {
      return _json({'url': 'https://$_storageHost/sign/final?token=d'});
    }
    return _json({'data': []});
  }
}

void main() {
  test('reservation sends the idempotency key and the declared file', () async {
    final fake = _Fake();
    final reservation = await fake.service().reserveSubmissionFile('act-1',
        fileName: 'resposta.pdf',
        sizeBytes: 4,
        expectedVersion: 0,
        idempotencyKey: 'att-0123456789');

    final request = fake.api.single;
    expect(request.headers['Idempotency-Key'], 'att-0123456789');
    expect(jsonDecode(request.body), {
      'fileName': 'resposta.pdf',
      'sizeBytes': 4,
      'contentType': 'application/pdf',
      'expectedVersion': 0,
    });
    expect(reservation.ticket?.method, 'PUT');
  });

  test('bytes go to the Storage host only, without UniConnect credentials',
      () async {
    final fake = _Fake();
    final service = fake.service();
    await service.uploadBytes(
        UploadTicket(
            url: Uri.parse('https://$_storageHost/upload?token=t'),
            method: 'PUT',
            headers: const {'Content-Type': 'application/pdf'}),
        Uint8List.fromList([1, 2, 3, 4]));

    final sent = fake.storage.single;
    expect(sent.method, 'PUT');
    expect(sent.headers.containsKey('Authorization'), isFalse);
    expect(sent.headers.containsKey('x-tenant-slug'), isFalse);
    expect(sent.bodyBytes, [1, 2, 3, 4]);

    expect(
        () => service.uploadBytes(
            UploadTicket(
                url: Uri.parse('https://evil.example/upload'),
                method: 'PUT',
                headers: const {}),
            Uint8List(1)),
        throwsA(isA<ApiException>()));
  });

  test('complete waits while another validation holds the file', () async {
    final fake = _Fake()..firstCompleteBusy = true;
    final attachment = await fake.service().complete(_fileId);

    expect(attachment.name, 'resposta.pdf');
    expect(fake.api.map((r) => r.method), ['POST', 'GET']);
  });

  test('draft uploads a picked file and only ready files are sent', () async {
    final fake = _Fake();
    final drafts = AttachmentDraftController();
    addTearDown(drafts.dispose);

    await drafts.pickAndUpload(
      pick: () async => [
        (
          name: 'resposta.pdf',
          size: 4,
          read: () async => Uint8List.fromList([1, 2, 3, 4])
        ),
        (name: 'script.exe', size: 4, read: () async => Uint8List(4)),
      ],
      service: fake.service(),
      activityId: 'act-1',
      expectedVersion: 0,
    );

    expect(drafts.readyIds, [_fileId]);
    expect(drafts.notice, contains('Formato não aceito'));
    expect(fake.storage, hasLength(1));
  });

  test(
      'a definitively rejected transfer is marked and its reservation cancelled',
      () async {
    final fake = _Fake()..storageFails = true;
    final drafts = AttachmentDraftController();
    addTearDown(drafts.dispose);

    await drafts.pickAndUpload(
      pick: () async => [
        (name: 'foto.png', size: 4, read: () async => Uint8List(4)),
      ],
      service: fake.service(),
      activityId: 'act-1',
      expectedVersion: 0,
    );
    await pumpEventQueue();

    expect(drafts.files.single.state, DraftFileState.failed);
    expect(drafts.readyIds, isEmpty);
    expect(fake.api.any((r) => r.method == 'DELETE'), isTrue);
  });

  test('client validation follows the contract limits', () {
    expect(attachmentValidationError('a.pdf', attachmentMaxBytes), isNull);
    expect(attachmentValidationError('a.pdf', attachmentMaxBytes + 1),
        'O arquivo passa de 10 MB.');
    expect(attachmentValidationError('a.docx', 0), 'O arquivo está vazio.');
    expect(attachmentContentType('Foto.JPG'), 'image/jpeg');
  });

  test('submission sends attachment ids only when there are files', () async {
    final bodies = <Map<String, dynamic>>[];
    final service = StudentSubmissionService(
      ApiClient(
          baseUrl: 'https://api.invalid/api/v1',
          httpClient: MockClient((request) async {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            bodies.add(body);
            return _json({
              'id': 'sub-1',
              'activityId': 'act-1',
              'studentId': 'student-1',
              'version': (body['expectedVersion'] as int) + 1,
              'answer': body['answer'],
              'submittedAt': '2026-11-12T21:05:00.000Z',
              'isLate': false,
              'status': 'submitted',
              'result': null,
              if (body['attachmentIds'] != null) 'attachments': [_attachment()],
            }, 201);
          })),
      accessToken: 'token',
      tenantSlug: 'campus',
      studentId: 'student-1',
    );

    final textOnly =
        await service.submit('act-1', answer: 'Texto', expectedVersion: 0);
    final withFile = await service.submit('act-1',
        answer: 'Texto', expectedVersion: 1, attachmentIds: [_fileId]);

    expect(bodies.first.containsKey('attachmentIds'), isFalse);
    expect(bodies.last['attachmentIds'], [_fileId]);
    expect(textOnly.attachments, isEmpty);
    expect(withFile.attachments.single.name, 'resposta.pdf');
  });
}
