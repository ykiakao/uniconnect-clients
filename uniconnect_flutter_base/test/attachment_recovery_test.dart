import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uniconnect/core/network/api_client.dart';
import 'package:uniconnect/features/activities/services/attachment_service.dart';
import 'package:uniconnect/features/activities/widgets/submission_attachments.dart';

const id = '11111111-1111-4111-8111-111111111111';
http.Response json(Object row, [int status = 200]) =>
    http.Response(jsonEncode(row), status);

class Fixture {
  final methods = <String>[];
  int reservations = 0;
  int puts = 0;
  bool transferUncertain = false;
  bool offline = true;
  String state = 'ready';
  Completer<http.Response>? statusGate;
  late final service = AttachmentService(
    ApiClient(
        baseUrl: 'https://api.invalid/api/v1',
        httpClient: MockClient((r) async {
          methods.add(r.method);
          if (r.url.path.endsWith('/submissions/attachment-uploads')) {
            reservations++;
            return json({
              'id': id,
              'state': 'pending',
              'upload': {
                'url': 'https://project.supabase.co/upload',
                'method': 'PUT',
                'headers': {'Content-Type': 'application/pdf'}
              }
            }, 201);
          }
          if (r.url.path.endsWith('/complete')) {
            throw TimeoutException('synthetic');
          }
          if (r.method == 'GET') {
            if (statusGate != null) return statusGate!.future;
            if (offline) throw http.ClientException('synthetic');
            return status();
          }
          return http.Response('', 204);
        })),
    accessToken: 'synthetic',
    tenantSlug: 'campus',
    storageHost: 'project.supabase.co',
    storageClient: MockClient((r) async {
      puts++;
      if (transferUncertain) throw http.ClientException('synthetic');
      return http.Response('', 200);
    }),
    retryDelay: Duration.zero,
  );
  http.Response status() => json({
        'id': id,
        'state': state,
        if (state == 'ready')
          'attachment': {
            'id': id,
            'name': 'answer.pdf',
            'contentType': 'application/pdf',
            'sizeBytes': 4
          }
      });
  Future<AttachmentDraftController> upload() async {
    final drafts = AttachmentDraftController();
    addTearDown(drafts.dispose);
    await drafts.pickAndUpload(
        pick: () async =>
            [(name: 'answer.pdf', size: 4, read: () async => Uint8List(4))],
        service: service,
        activityId: 'activity',
        expectedVersion: 0);
    return drafts;
  }
}

void main() {
  test(
      'an ambiguous transfer also retains its reservation without automatic cancellation',
      () async {
    final api = Fixture()..transferUncertain = true;
    final drafts = await api.upload();
    expect(drafts.files.single.state, DraftFileState.awaitingConfirmation);
    expect(api.methods.contains('DELETE'), isFalse);
    api.offline = false;
    await drafts.recover(drafts.files.single, api.service);
    expect(drafts.readyIds, [id]);
    expect(api.reservations, 1);
    expect(api.puts, 1);
  });
  test(
      'student keeps an indeterminate file and recovers without upload, reservation or cancellation',
      () async {
    final api = Fixture();
    final drafts = await api.upload();
    expect(drafts.files.single.fileId, id);
    expect(drafts.files.single.state, DraftFileState.awaitingConfirmation);
    expect(drafts.needsConfirmation, isTrue);
    expect(drafts.readyIds, isEmpty);
    expect(drafts.busy, isFalse);
    expect(api.methods.contains('DELETE'), isFalse);
    api.offline = false;
    await drafts.recover(drafts.files.single, api.service);
    expect(drafts.readyIds, [id]);
    expect(drafts.needsConfirmation, isFalse);
    await drafts.recover(drafts.files.single, api.service);
    expect(api.reservations, 1);
    expect(api.puts, 1);
    expect(api.methods.where((m) => m == 'POST').length, 2);
    expect(api.methods.contains('DELETE'), isFalse);
  });
  test(
      'student preserves processing state and only explicit removal can cancel',
      () async {
    final api = Fixture()
      ..offline = false
      ..state = 'validating';
    final drafts = await api.upload();
    expect(drafts.files.single.state, DraftFileState.awaitingConfirmation);
    expect(api.methods.contains('DELETE'), isFalse);
    await drafts.remove(drafts.files.single, api.service);
    expect(drafts.files, isEmpty);
    expect(api.methods.last, 'DELETE');
  });
  test(
      'student recognizes actual cancellation without another cancellation request',
      () async {
    final api = Fixture()
      ..offline = false
      ..state = 'cancelled';
    final drafts = await api.upload();
    expect(drafts.files.single.state, DraftFileState.failed);
    expect(drafts.files.single.error, contains('cancelled'));
    expect(drafts.readyIds, isEmpty);
    expect(api.methods.contains('DELETE'), isFalse);
  });
  test(
      'concurrent recovery clicks share the retained draft and do not duplicate requests',
      () async {
    final api = Fixture();
    final drafts = await api.upload();
    api.offline = false;
    api.statusGate = Completer<http.Response>();
    final draft = drafts.files.single;
    final first = drafts.recover(draft, api.service);
    final second = drafts.recover(draft, api.service);
    expect(drafts.busy, isTrue);
    api.statusGate!.complete(api.status());
    await Future.wait([first, second]);
    expect(drafts.readyIds, [id]);
    expect(api.methods.where((m) => m == 'GET').length, 2);
    expect(api.reservations, 1);
    expect(api.puts, 1);
  });
}
