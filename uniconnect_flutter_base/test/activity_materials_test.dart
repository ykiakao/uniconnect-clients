import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uniconnect/core/network/api_client.dart';
import 'package:uniconnect/features/activities/providers/attachment_providers.dart';
import 'package:uniconnect/features/activities/services/attachment_service.dart';
import 'package:uniconnect/features/teacher/services/teacher_activity_service.dart';
import 'package:uniconnect/features/teacher/widgets/activity_materials_sheet.dart';

import 'demo_day_test.dart' show pumpDemoPage;
import 'fakes/fake_auth_service.dart';

const _host = 'project.supabase.co';
const _existing = '22222222-2222-4222-8222-222222222222';
const _newFile = '33333333-3333-4333-8333-333333333333';

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'});

Map<String, dynamic> _file(String id, String name) => {
      'id': id,
      'name': name,
      'contentType': 'application/pdf',
      'sizeBytes': 2048,
      'createdAt': '2026-11-12T21:00:00.000Z',
    };

class _Api {
  final calls = <String>[];
  final bodies = <String, Object?>{};

  AttachmentService service() => AttachmentService(
        ApiClient(
            baseUrl: 'https://api.invalid/api/v1',
            httpClient: MockClient(handle)),
        accessToken: 'token',
        tenantSlug: 'campus',
        storageHost: _host,
        storageClient: MockClient((_) async => http.Response('', 200)),
        retryDelay: Duration.zero,
      );

  Future<http.Response> handle(http.Request request) async {
    final path = request.url.path.replaceFirst('/api/v1/tenants/campus', '');
    final call =
        '${request.method} $path${request.url.query.isEmpty ? '' : '?${request.url.query}'}';
    calls.add(call);
    if (request.body.isNotEmpty) bodies[call] = jsonDecode(request.body);
    return switch (call) {
      'GET /activities/act-1/attachments' => _json({
          'data': [_file(_existing, 'roteiro.pdf')]
        }),
      'POST /activities/act-1/attachment-uploads' => _json({
          'id': _newFile,
          'state': 'pending',
          'upload': {
            'url': 'https://$_host/upload?token=t',
            'method': 'PUT',
            'headers': {'Content-Type': 'application/pdf'},
          },
        }, 201),
      'POST /attachment-uploads/$_newFile/complete' => _json({
          'id': _newFile,
          'state': 'ready',
          'attachment': _file(_newFile, 'slides.pdf'),
        }),
      'POST /activities/act-1/attachments' => _json(
          {'attachment': _file(_newFile, 'slides.pdf'), 'revision': 4}, 201),
      'DELETE /activities/act-1/attachments/$_existing?expectedVersion=4' =>
        _json({'id': _existing, 'revision': 5}),
      _ => _json({
          'error': {'code': 'NOT_FOUND', 'message': call}
        }, 404),
    };
  }
}

const _work = TeacherActivity(
  id: 'act-1',
  classId: 'class-1',
  title: 'Projeto de banco relacional',
  state: 'draft',
  revision: 3,
  workflowEnabled: true,
);

void main() {
  test('materials are linked and removed with the activity revision', () async {
    final api = _Api();
    final service = api.service();

    final linked = await service.linkMaterial('act-1', _newFile, 3);
    final removed = await service.removeMaterial('act-1', _existing, 4);

    expect(api.bodies['POST /activities/act-1/attachments'],
        {'fileId': _newFile, 'expectedVersion': 3});
    expect(linked.revision, 4);
    expect(removed, 5);
    expect(canManageMaterials(_work), isTrue);
  });

  testWidgets('teacher adds and removes materials of an activity',
      (tester) async {
    final api = _Api();
    await pumpDemoPage(
      tester,
      const Scaffold(body: ActivityMaterialsSheet(work: _work)),
      user: fakeTeacher,
      overrides: [
        attachmentServiceProvider.overrideWithValue(api.service()),
        attachmentPickerProvider.overrideWithValue(() async => [
              (
                name: 'slides.pdf',
                size: 2048,
                read: () async => Uint8List(2048)
              ),
            ]),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.text('roteiro.pdf'), findsOneWidget);

    await tester.tap(find.text('Adicionar material'));
    await tester.pumpAndSettle();

    expect(find.text('slides.pdf'), findsOneWidget);
    expect(api.calls, contains('POST /attachment-uploads/$_newFile/complete'));
    expect(api.bodies['POST /activities/act-1/attachments'],
        {'fileId': _newFile, 'expectedVersion': 3});

    await tester.tap(find.byTooltip('Remover roteiro.pdf'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remover'));
    await tester.pumpAndSettle();

    expect(api.calls.last,
        'DELETE /activities/act-1/attachments/$_existing?expectedVersion=4');
    expect(find.text('roteiro.pdf'), findsNothing);
  });
}
