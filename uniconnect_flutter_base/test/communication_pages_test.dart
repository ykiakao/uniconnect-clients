import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uniconnect/core/network/api_client.dart';
import 'package:uniconnect/features/auth/presentation/forgot_password_page.dart';
import 'package:uniconnect/features/auth/providers/auth_provider.dart';
import 'package:uniconnect/features/auth/services/api_auth_service.dart';
import 'package:uniconnect/features/communication/models/communication_models.dart';
import 'package:uniconnect/features/communication/presentation/conversation_page.dart';
import 'package:uniconnect/features/communication/presentation/notice_form_page.dart';
import 'package:uniconnect/features/communication/presentation/notices_page.dart';
import 'package:uniconnect/features/communication/providers/communication_providers.dart';
import 'package:uniconnect/features/teacher/providers/teacher_activity_provider.dart';
import 'package:uniconnect/features/teacher/services/teacher_activity_service.dart';

import 'communication_service_test.dart'
    show json, messageJson, noticeJson, serviceWith;
import 'demo_day_test.dart' show pumpDemoPage;
import 'fakes/fake_auth_service.dart';

void main() {
  testWidgets('notices page lists notices and marks the unread ones',
      (tester) async {
    await pumpDemoPage(tester, const NoticesPage(), overrides: [
      unreadNotificationsProvider.overrideWith((ref) async => 0),
      noticesProvider.overrideWith(
          (ref, view) async => [AppNotice.fromJson(noticeJson())]),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('Prova remarcada'), findsOneWidget);
    expect(find.text('Novo'), findsOneWidget);
    expect(find.text('Prioridade alta'), findsOneWidget);
    expect(find.text('Novo aviso da turma'), findsNothing);
  });

  testWidgets('teacher notice form asks for title and message first',
      (tester) async {
    var requests = 0;
    await pumpDemoPage(tester, const NoticeFormPage(),
        user: fakeTeacher,
        overrides: [
          unreadNotificationsProvider.overrideWith((ref) async => 0),
          teacherOfferingsProvider.overrideWith((ref) async =>
              const [TeacherOffering(id: 'class-1', name: 'Métodos')]),
          communicationServiceProvider.overrideWithValue(serviceWith((_) async {
            requests++;
            return json(noticeJson());
          })),
        ]);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Publicar aviso'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Publicar aviso'));
    await tester.pumpAndSettle();

    expect(find.text('Informe o título.'), findsOneWidget);
    expect(find.text('Informe a mensagem.'), findsOneWidget);
    expect(requests, 0);
  });

  testWidgets('conversation shows messages on both sides and sends text',
      (tester) async {
    final sent = <String>[];
    await pumpDemoPage(
        tester, const ConversationPage(conversationId: 'conversation-1'),
        overrides: [
          unreadNotificationsProvider.overrideWith((ref) async => 0),
          communicationServiceProvider
              .overrideWithValue(serviceWith((http.Request request) async {
            if (request.method == 'POST' &&
                request.url.path.endsWith('/messages')) {
              sent.add(request.body);
              return json(messageJson(3, sender: fakeStudent.id), 201);
            }
            if (request.url.path.endsWith('/read')) return json({});
            return json({
              'data': [
                messageJson(1, sender: 'teacher-1'),
                messageJson(2, sender: fakeStudent.id),
              ],
              'meta': {'hasMore': false, 'nextAfterSequence': 2},
            });
          })),
        ]);
    await tester.pumpAndSettle();

    expect(find.text('Mensagem 1'), findsOneWidget);
    expect(find.text('Mensagem 2'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Obrigada!');
    await tester.pump();
    await tester.tap(find.byTooltip('Enviar mensagem'));
    await tester.pumpAndSettle();

    expect(sent.single, contains('Obrigada!'));
  });

  testWidgets('forgot password validates the e-mail before sending',
      (tester) async {
    final requests = <http.Request>[];
    final client = ApiClient(
      baseUrl: 'https://fixture.invalid/api/v1',
      httpClient: MockClient((request) async {
        requests.add(request);
        return json({'message': 'ok'}, 202);
      }),
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        apiAuthServiceProvider.overrideWithValue(ApiAuthService(client)),
      ],
      child: const MaterialApp(home: ForgotPasswordPage()),
    ));

    await tester.enterText(find.byType(TextField), 'sem-arroba');
    await tester.tap(find.text('Enviar instruções'));
    await tester.pumpAndSettle();
    expect(find.text('Informe um e-mail válido.'), findsOneWidget);
    expect(requests, isEmpty);

    await tester.enterText(find.byType(TextField), 'aluno@uni.com');
    await tester.tap(find.text('Enviar instruções'));
    await tester.pumpAndSettle();
    expect(requests.single.url.path, '/api/v1/auth/password/recovery');
    expect(find.text('Pedido enviado'), findsOneWidget);
  });
}
