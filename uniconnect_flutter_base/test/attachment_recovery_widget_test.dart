import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uniconnect/core/network/api_client.dart';
import 'package:uniconnect/features/academic/demo/synthetic_academic_providers.dart';
import 'package:uniconnect/features/activities/models/academic_activity.dart';
import 'package:uniconnect/features/activities/providers/attachment_providers.dart';
import 'package:uniconnect/features/activities/providers/student_submission_provider.dart';
import 'package:uniconnect/features/activities/services/attachment_service.dart';
import 'package:uniconnect/features/activities/widgets/student_submission_panel.dart';
import 'package:uniconnect/features/auth/providers/auth_provider.dart';
import 'package:uniconnect/features/auth/services/api_auth_service.dart';
import 'package:uniconnect/features/teacher/services/teacher_activity_service.dart';
import 'package:uniconnect/features/teacher/widgets/activity_materials_sheet.dart';
import 'demo_day_test.dart' show pumpDemoPage;
import 'fakes/fake_auth_service.dart';
import 'fakes/fake_session_storage.dart';

const id = '11111111-1111-4111-8111-111111111111';
http.Response json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status);
Map<String, dynamic> metadata() => {
      'id': id,
      'name': 'answer.pdf',
      'contentType': 'application/pdf',
      'sizeBytes': 4
    };

class Api {
  bool offline = true;
  bool lostLink = false;
  bool lostOnce = false;
  int reservations = 0, puts = 0, deletes = 0, links = 0;
  final revisions = <int>[];
  late final service = AttachmentService(
      ApiClient(
          baseUrl: 'https://api.invalid/api/v1',
          httpClient: MockClient((r) async {
            if (r.method == 'DELETE') {
              deletes++;
              return http.Response('', 204);
            }
            if (r.url.path.endsWith('/attachment-uploads')) {
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
              if (offline) throw TimeoutException('synthetic');
              return status();
            }
            if (r.url.path.endsWith('/attachment-uploads/$id')) {
              if (offline) throw http.ClientException('synthetic');
              return status();
            }
            if (r.url.path.endsWith('/attachments')) {
              if (r.method == 'GET') return json({'data': []});
              links++;
              revisions.add((jsonDecode(r.body)
                  as Map<String, dynamic>)['expectedVersion'] as int);
              if (lostLink && !lostOnce) {
                lostOnce = true;
                throw TimeoutException('synthetic');
              }
              return json({'attachment': metadata(), 'revision': 4}, 201);
            }
            return json({'data': []});
          })),
      accessToken: 'synthetic',
      tenantSlug: 'campus',
      storageHost: 'project.supabase.co', storageClient: MockClient((r) async {
    puts++;
    return http.Response('', 200);
  }), retryDelay: Duration.zero);
  http.Response status() =>
      json({'id': id, 'state': 'ready', 'attachment': metadata()});
}

const work = TeacherActivity(
    id: 'activity',
    classId: 'class',
    title: 'Synthetic task',
    state: 'draft',
    revision: 3,
    workflowEnabled: true);
const activity = AcademicActivity(
    id: 'activity',
    subject: 'Synthetic',
    title: 'Task',
    description: '',
    dueDate: null,
    teacher: 'Teacher',
    status: ActivityStatus.pending,
    criteria: [],
    attachments: [],
    publicationState: 'published',
    workflowEnabled: true);
void main() {
  testWidgets(
      'teacher retries the retained confirmation without another upload or cancellation',
      (tester) async {
    final api = Api();
    await pumpDemoPage(
        tester, const Scaffold(body: ActivityMaterialsSheet(work: work)),
        user: fakeTeacher,
        overrides: [
          attachmentServiceProvider.overrideWithValue(api.service),
          attachmentPickerProvider.overrideWithValue(() async =>
              [(name: 'answer.pdf', size: 4, read: () async => Uint8List(4))]),
        ]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adicionar material'));
    await tester.pumpAndSettle();
    expect(find.text('Verificar arquivo'), findsOneWidget);
    expect(api.reservations, 1);
    expect(api.puts, 1);
    expect(api.deletes, 0);
    expect(api.links, 0);
    api.offline = false;
    await tester.tap(find.text('Verificar arquivo'));
    await tester.pumpAndSettle();
    expect(find.text('Verificar arquivo'), findsNothing);
    expect(find.text('answer.pdf'), findsOneWidget);
    expect(api.reservations, 1);
    expect(api.puts, 1);
    expect(api.deletes, 0);
    expect(api.links, 1);
    expect(api.revisions, [3]);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'teacher retries a lost link response with the original file and revision',
      (tester) async {
    final api = Api()
      ..offline = false
      ..lostLink = true;
    await pumpDemoPage(
        tester, const Scaffold(body: ActivityMaterialsSheet(work: work)),
        user: fakeTeacher,
        overrides: [
          attachmentServiceProvider.overrideWithValue(api.service),
          attachmentPickerProvider.overrideWithValue(() async =>
              [(name: 'answer.pdf', size: 4, read: () async => Uint8List(4))]),
        ]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adicionar material'));
    await tester.pumpAndSettle();
    expect(find.text('Verificar arquivo'), findsOneWidget);
    expect(api.deletes, 0);
    await tester.tap(find.text('Verificar arquivo'));
    await tester.pumpAndSettle();
    expect(api.reservations, 1);
    expect(api.puts, 1);
    expect(api.revisions, [3, 3]);
    expect(find.text('answer.pdf'), findsOneWidget);
    expect(api.deletes, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'student cannot submit while confirmation is indeterminate and can verify the same file',
      (tester) async {
    final api = Api();
    final auth = AuthController(
        FakeAuthService(
            loginResult: AuthSession(
                accessToken: 'synthetic',
                refreshToken: 'fixture',
                expiresAt: 4102444800,
                user: fakeStudent)),
        FakeSessionStorage());
    await auth.login(
        email: fakeStudent.email, password: 'fixture', rememberSession: false);
    await pumpDemoPage(
        tester,
        const Scaffold(
            body: SingleChildScrollView(
                child: StudentSubmissionPanel(activity: activity))),
        overrides: [
          authControllerProvider.overrideWith((ref) => auth),
          syntheticDemoRequestedProvider.overrideWithValue(false),
          ownSubmissionProvider('activity').overrideWith((ref) async => null),
          attachmentServiceProvider.overrideWithValue(api.service),
          attachmentPickerProvider.overrideWithValue(() async =>
              [(name: 'answer.pdf', size: 4, read: () async => Uint8List(4))]),
        ]);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Synthetic answer');
    await tester.scrollUntilVisible(find.text('Adicionar arquivo'), 100,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Adicionar arquivo'));
    await tester.pumpAndSettle();
    final button = find.widgetWithText(ElevatedButton, 'Enviar resposta');
    expect(tester.widget<ElevatedButton>(button).onPressed, isNull);
    expect(find.byTooltip('Verificar answer.pdf'), findsOneWidget);
    expect(api.deletes, 0);
    api.offline = false;
    await tester.tap(find.byTooltip('Verificar answer.pdf'));
    await tester.pumpAndSettle();
    expect(tester.widget<ElevatedButton>(button).onPressed, isNotNull);
    expect(api.reservations, 1);
    expect(api.puts, 1);
    expect(api.deletes, 0);
    expect(tester.takeException(), isNull);
  });
}
