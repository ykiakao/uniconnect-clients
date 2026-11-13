import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'student_submission_widget_test.dart'
    show pumpStudentDetail, showDelivery, tapDelivery;
import 'student_submission_service_test.dart' show submissionJson;
import 'student_activity_contract_test.dart' show response;

const fileId = '11111111-1111-4111-8111-111111111111';
const fallback = 'Enviar nova versão só em texto';
Map<String, dynamic> file() => {
      'id': fileId,
      'name': 'answer.pdf',
      'contentType': 'application/pdf',
      'sizeBytes': 4
    };

class Api {
  bool readOnly = true;
  bool genericOutage = false;
  bool conflict = false;
  int version = 1, commits = 0, deletes = 0;
  String answer = 'Resposta anterior';
  final bodies = <Map<String, dynamic>>[];
  final history = <int, List<Map<String, dynamic>>>{
    1: [file()]
  };
  Future<http.Response> handle(http.Request request) async {
    if (request.method == 'DELETE') {
      deletes++;
      return http.Response('', 204);
    }
    if (request.method == 'GET' &&
        request.url.path.endsWith('/submissions/me')) {
      return response({
        ...submissionJson(version: version, answer: answer),
        'attachments': history[version]
      });
    }
    if (request.method == 'GET' &&
        request.url.path.endsWith('/versions/1/attachments')) {
      return response({'data': history[1]});
    }
    if (request.method == 'POST' && request.url.path.endsWith('/submissions')) {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      bodies.add(body);
      if (genericOutage) {
        return response({
          'error': {
            'code': 'DEPENDENCY_UNAVAILABLE',
            'message': 'Falha temporaria'
          }
        }, 503);
      }
      if (readOnly && (body['attachmentIds'] as List?)?.isNotEmpty == true) {
        return response({
          'error': {
            'code': 'ACADEMIC_ATTACHMENTS_UNAVAILABLE',
            'message': 'Novos anexos estao indisponiveis.'
          }
        }, 503);
      }
      if (conflict) {
        return response({
          'error': {'code': 'VERSION_CONFLICT', 'message': 'Versao alterada'}
        }, 409);
      }
      commits++;
      version++;
      answer = body['answer'] as String;
      history[version] =
          (body['attachmentIds'] as List?)?.isNotEmpty == true ? [file()] : [];
      return response({
        ...submissionJson(version: version, answer: answer),
        'attachments': history[version]
      }, 201);
    }
    return response({'data': []});
  }
}

Future<void> startFallback(WidgetTester tester, Api api) async {
  await showDelivery(tester);
  await tester.enterText(find.byType(TextFormField), 'Nova resposta textual');
  await tapDelivery(tester, 'Reenviar resposta');
  await tester.pumpAndSettle();
  expect(api.bodies, hasLength(1));
  expect(api.bodies.single['attachmentIds'], [fileId]);
  expect(api.commits, 0);
  await tapDelivery(tester, 'Atualizar minha entrega');
  await tester.pumpAndSettle();
  expect(find.text(fallback), findsOneWidget);
}

Future<void> confirm(WidgetTester tester) async {
  await tapDelivery(tester, fallback);
  await tester.pumpAndSettle();
  expect(find.textContaining('não incluirá arquivos'), findsOneWidget);
  await tester.tap(find.widgetWithText(FilledButton, 'Enviar só o texto'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'F3 sends no automatic retry and only confirmed text creates the next version, preserving history',
      (tester) async {
    final api = Api();
    await pumpStudentDetail(tester, api.handle);
    await startFallback(tester, api);
    await tapDelivery(tester, fallback);
    await tester.pumpAndSettle();
    expect(api.bodies, hasLength(1));
    expect(api.commits, 0);
    expect(tester.widget<TextFormField>(find.byType(TextFormField)).enabled,
        isFalse);
    expect(find.textContaining('não incluirá arquivos'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Enviar só o texto'));
    await tester.pumpAndSettle();
    expect(api.bodies, hasLength(2));
    expect(api.bodies.last.containsKey('attachmentIds'), isFalse);
    expect(api.bodies.last['expectedVersion'], 1);
    expect(api.bodies.last['answer'], 'Nova resposta textual');
    expect(api.version, 2);
    expect(api.commits, 1);
    expect(api.history[1]!.single['id'], fileId);
    expect(api.history[2], isEmpty);
    expect(api.deletes, 0);
    expect(
        find.text('Resposta enviada e confirmada pela API.'), findsOneWidget);
    await tapDelivery(tester, 'Versão 1');
    await tester.pumpAndSettle();
    expect(find.text('answer.pdf'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('F3 declining confirmation retains attachments and sends nothing',
      (tester) async {
    final api = Api();
    await pumpStudentDetail(tester, api.handle);
    await startFallback(tester, api);
    await tapDelivery(tester, fallback);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Voltar'));
    await tester.pumpAndSettle();
    expect(api.bodies, hasLength(1));
    expect(api.commits, 0);
    expect(api.version, 1);
    expect(api.deletes, 0);
    expect(find.text('answer.pdf'), findsWidgets);
    await confirm(tester);
    expect(api.bodies, hasLength(2));
    expect(api.commits, 1);
    expect(api.history[1]!.single['id'], fileId);
    expect(tester.takeException(), isNull);
  });
  testWidgets('F3 generic 503 never authorizes dropping attachments',
      (tester) async {
    final api = Api()..genericOutage = true;
    await pumpStudentDetail(tester, api.handle);
    await showDelivery(tester);
    await tester.enterText(find.byType(TextFormField), 'Texto');
    await tapDelivery(tester, 'Reenviar resposta');
    await tester.pumpAndSettle();
    expect(find.text(fallback), findsNothing);
    expect(api.bodies, hasLength(1));
    expect(api.bodies.single['attachmentIds'], [fileId]);
    expect(api.deletes, 0);
  });
  testWidgets('F3 preserves the enabled workflow and its attached next version',
      (tester) async {
    final api = Api()..readOnly = false;
    await pumpStudentDetail(tester, api.handle);
    await showDelivery(tester);
    await tester.enterText(find.byType(TextFormField), 'Texto com arquivo');
    await tapDelivery(tester, 'Reenviar resposta');
    await tester.pumpAndSettle();
    expect(api.commits, 1);
    expect(api.bodies.single['attachmentIds'], [fileId]);
    expect(api.history[1]!.single['id'], fileId);
    expect(api.history[2]!.single['id'], fileId);
    expect(find.text(fallback), findsNothing);
    expect(api.deletes, 0);
  });
  testWidgets(
      'F3 text-only confirmation respects stale revisions and keeps the old version intact',
      (tester) async {
    final api = Api()..conflict = true;
    await pumpStudentDetail(tester, api.handle);
    await startFallback(tester, api);
    await confirm(tester);
    expect(api.bodies, hasLength(2));
    expect(api.bodies.last.containsKey('attachmentIds'), isFalse);
    expect(api.commits, 0);
    expect(api.version, 1);
    expect(api.history[1]!.single['id'], fileId);
    expect(find.text('Resposta enviada e confirmada pela API.'), findsNothing);
    expect(find.textContaining('Conflito de versão'), findsOneWidget);
    expect(api.deletes, 0);
  });
  testWidgets(
      'F3 logout during confirmation cannot submit under the old session',
      (tester) async {
    final api = Api();
    final auth = await pumpStudentDetail(tester, api.handle);
    await startFallback(tester, api);
    await tapDelivery(tester, fallback);
    await tester.pumpAndSettle();
    await auth.logout();
    await tester.pumpAndSettle();
    final accept = find.widgetWithText(FilledButton, 'Enviar só o texto');
    if (accept.evaluate().isNotEmpty) {
      await tester.tap(accept);
      await tester.pumpAndSettle();
    }
    expect(api.bodies, hasLength(1));
    expect(api.commits, 0);
    expect(api.deletes, 0);
    expect(tester.takeException(), isNull);
  });
}
