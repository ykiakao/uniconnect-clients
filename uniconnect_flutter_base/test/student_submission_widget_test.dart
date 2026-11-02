import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uniconnect/core/network/api_client.dart';
import 'package:uniconnect/core/theme/app_theme.dart';
import 'package:uniconnect/features/academic/demo/synthetic_academic_providers.dart';
import 'package:uniconnect/features/activities/presentation/activity_detail_page.dart';
import 'package:uniconnect/features/auth/models/app_user.dart';
import 'package:uniconnect/features/auth/providers/auth_provider.dart';
import 'package:uniconnect/features/auth/services/api_auth_service.dart';
import 'fakes/fake_auth_service.dart';
import 'fakes/fake_session_storage.dart';
import 'student_activity_contract_test.dart'
    show activityId, activityJson, listJson, response;
import 'student_submission_service_test.dart' show submissionJson, noSubmission;
import 'layout_quality_test.dart' show captureLayout;

Future<AuthController> pumpStudentDetail(
    WidgetTester tester, Future<http.Response> Function(http.Request) handler,
    {AppUser user = fakeStudent,
    GlobalKey? frame,
    double width = 390,
    double scale = 1,
    Map<String, dynamic>? activity,
    Future<http.Response> Function()? detailResponse}) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final auth = AuthController(
      FakeAuthService(
          loginResult: AuthSession(
              accessToken: 'access-token',
              refreshToken: 'fixture',
              expiresAt: 4102444800,
              user: user)),
      FakeSessionStorage());
  await auth.login(
      email: user.email, password: 'fixture', rememberSession: false);
  await tester.pumpWidget(ProviderScope(
      retry: (_, __) => null,
      overrides: [
        authControllerProvider.overrideWith((ref) => auth),
        syntheticDemoRequestedProvider.overrideWithValue(false),
        apiClientProvider
            .overrideWithValue(ApiClient(httpClient: MockClient((r) {
          expect(r.headers['Authorization'], 'Bearer access-token');
          expect(r.headers['x-tenant-slug'], user.tenant.slug);
          if (r.url.path.endsWith('/activities/$activityId')) {
            return detailResponse?.call() ??
                Future.value(response(activity ?? activityJson()));
          }
          if (r.url.path.endsWith('/classes/class-1')) {
            return Future.value(response({'id': 'class-1', 'name': 'Métodos'}));
          }
          if (r.url.path.endsWith('/courses')) {
            return Future.value(response(listJson([])));
          }
          return handler(r);
        }))),
      ],
      child: RepaintBoundary(
          key: frame,
          child: MaterialApp(
              theme: AppTheme.lightTheme,
              debugShowCheckedModeBanner: false,
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!),
              home: const ActivityDetailPage(activityId: activityId)))));
  await tester.pumpAndSettle();
  return auth;
}

Future<void> showDelivery(WidgetTester tester) async {
  await tester.scrollUntilVisible(find.text('Sua entrega'), 250,
      scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

Future<void> tapDelivery(WidgetTester tester, String text) async {
  tester.testTextInput.hide();
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.text(text), 180,
      scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(text));
  await tester.pump();
}

void main() {
  setUpAll(() async {
    await (FontLoader('Inter')
          ..addFont(rootBundle.load('assets/fonts/Inter/Inter-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Inter/Inter-Bold.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Inter/Inter-Medium.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  testWidgets('text submission stays usable at 320px with enlarged text',
      (tester) async {
    final frame = GlobalKey();
    await pumpStudentDetail(tester, (_) async => response(noSubmission),
        frame: frame, width: 320, scale: 2);
    await showDelivery(tester);
    await tester.scrollUntilVisible(find.text('Enviar resposta'), 180,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await captureLayout(tester, frame, 'student-submission-320-text200');
  });
  testWidgets(
      'late write response after logout cannot restore private delivery or success',
      (tester) async {
    final pending = Completer<http.Response>();
    final auth = await pumpStudentDetail(
        tester,
        (r) async =>
            r.method == 'GET' ? response(noSubmission) : pending.future);
    await showDelivery(tester);
    await tester.enterText(find.byType(TextFormField), 'Minha resposta');
    await tapDelivery(tester, 'Enviar resposta');
    await auth.logout();
    await tester.pumpAndSettle();
    pending.complete(response(submissionJson(), 201));
    await tester.pumpAndSettle();
    expect(find.text('Resposta enviada e confirmada pela API.'), findsNothing);
    expect(find.text('Minha resposta'), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
  });
  testWidgets(
      'temporary detail refresh failure preserves typed draft and blocks send until recovery',
      (tester) async {
    var unavailable = false;
    await pumpStudentDetail(tester, (_) async => response(noSubmission),
        detailResponse: () async => unavailable
            ? response({
                'error': {'message': 'Detalhes indisponíveis'}
              }, 503)
            : response(activityJson()));
    await showDelivery(tester);
    await tester.enterText(
        find.byType(TextFormField), 'Meu rascunho deve permanecer');
    unavailable = true;
    await tapDelivery(tester, 'Atualizar minha entrega');
    await tester.pumpAndSettle();
    expect(find.text('Detalhes da atividade'), findsOneWidget);
    expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        'Meu rascunho deve permanecer');
    expect(
        tester
            .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Enviar resposta'))
            .onPressed,
        isNull);
    unavailable = false;
    await tapDelivery(tester, 'Atualizar minha entrega');
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        'Meu rascunho deve permanecer');
    expect(
        tester
            .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Enviar resposta'))
            .onPressed,
        isNotNull);
  });

  testWidgets('inaccessible activity never exposes an editor', (tester) async {
    await pumpStudentDetail(
        tester, (_) async => throw StateError('No submission query expected'),
        detailResponse: () async => response({
              'error': {'message': 'Indisponível'}
            }, 404));
    expect(find.text('Atividade indisponível ou acesso não autorizado.'),
        findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
  });
  testWidgets(
      'real activity details, absence, validated send and revision use own versions',
      (tester) async {
    var current = 0;
    var text = '';
    var writes = 0;
    await pumpStudentDetail(tester, (r) async {
      if (r.method == 'GET') {
        expect(r.url.path.endsWith('/submissions/me'), isTrue);
        return response(current == 0
            ? noSubmission
            : submissionJson(version: current, answer: text));
      }
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      expect(body['expectedVersion'], current);
      current++;
      writes++;
      text = body['answer'] as String;
      return response(submissionJson(version: current, answer: text), 201);
    });
    expect(find.text('Pesquisa'), findsOneWidget);
    expect(find.text('MÉTODOS'), findsOneWidget);
    expect(find.text('Contexto\n\nResponda em texto'), findsOneWidget);
    expect(find.text('Clareza'), findsOneWidget);
    await showDelivery(tester);
    expect(find.text('Nenhuma entrega enviada.'), findsOneWidget);
    await tapDelivery(tester, 'Enviar resposta');
    expect(find.text('Informe sua resposta.'), findsOneWidget);
    expect(writes, 0);
    await tester.enterText(find.byType(TextFormField), 'Minha resposta');
    await tapDelivery(tester, 'Enviar resposta');
    await tester.pumpAndSettle();
    expect(
        find.text('Resposta enviada e confirmada pela API.'), findsOneWidget);
    expect(find.text('Resposta enviada • Versão 1'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Resposta revisada');
    await tapDelivery(tester, 'Reenviar resposta');
    await tester.pumpAndSettle();
    expect(find.text('Resposta enviada • Versão 2'), findsOneWidget);
    expect(find.text('Resposta revisada'), findsWidgets);
    expect(writes, 2);
  });

  testWidgets('pending POST cannot announce success or send twice',
      (tester) async {
    final pending = Completer<http.Response>();
    var writes = 0;
    var saved = false;
    await pumpStudentDetail(tester, (r) async {
      if (r.method == 'GET') {
        return response(saved ? submissionJson() : noSubmission);
      }
      writes++;
      final result = await pending.future;
      saved = true;
      return result;
    });
    await showDelivery(tester);
    await tester.enterText(find.byType(TextFormField), 'Minha resposta');
    await tapDelivery(tester, 'Enviar resposta');
    expect(find.text('Resposta enviada e confirmada pela API.'), findsNothing);
    final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Enviando resposta...'));
    expect(button.onPressed, isNull);
    await tester.tap(find.text('Enviando resposta...'));
    await tester.pump();
    expect(writes, 1);
    pending.complete(response(submissionJson(), 201));
    await tester.pumpAndSettle();
    expect(find.text('Resposta enviada • Versão 1'), findsOneWidget);
  });

  testWidgets(
      'conflict preserves typed answer and requires refreshing own revision',
      (tester) async {
    var version = 1;
    var writes = 0;
    var answer = 'Resposta anterior';
    await pumpStudentDetail(tester, (r) async {
      if (r.method == 'GET') {
        return response(submissionJson(version: version, answer: answer));
      }
      writes++;
      if (writes == 1) {
        version = 3;
        return response({
          'error': {'message': 'Conflito'}
        }, 409);
      }
      expect(jsonDecode(r.body)['expectedVersion'], 3);
      answer = jsonDecode(r.body)['answer'] as String;
      version = 4;
      return response(submissionJson(version: version, answer: answer), 201);
    });
    await showDelivery(tester);
    await tester.enterText(
        find.byType(TextFormField), 'Minha revisão preservada');
    await tapDelivery(tester, 'Reenviar resposta');
    await tester.pumpAndSettle();
    expect(find.textContaining('Conflito de versão'), findsOneWidget);
    expect(find.text('Resposta enviada e confirmada pela API.'), findsNothing);
    expect(
        tester
            .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Reenviar resposta'))
            .onPressed,
        isNull);
    await tapDelivery(tester, 'Atualizar minha entrega');
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        'Minha revisão preservada');
    await tapDelivery(tester, 'Reenviar resposta');
    await tester.pumpAndSettle();
    expect(find.text('Resposta enviada • Versão 4'), findsOneWidget);
    expect(writes, 2);
  });

  for (final status in [401, 403, 404, 503]) {
    testWidgets('own query HTTP $status is not an absent submission',
        (tester) async {
      await pumpStudentDetail(
          tester,
          (_) async => response({
                'error': {'message': 'Falha'}
              }, status));
      await showDelivery(tester);
      expect(find.textContaining('Erro ao consultar sua entrega.'),
          findsOneWidget);
      expect(find.text('Nenhuma entrega enviada.'), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
    });
  }

  testWidgets('failed write keeps draft and requires query before retry',
      (tester) async {
    await pumpStudentDetail(
        tester,
        (r) async => r.method == 'GET'
            ? response(noSubmission)
            : response({
                'error': {'message': 'Indisponível'}
              }, 503));
    await showDelivery(tester);
    await tester.enterText(find.byType(TextFormField), 'Não perder este texto');
    await tapDelivery(tester, 'Enviar resposta');
    await tester.pumpAndSettle();
    expect(find.text('Resposta enviada e confirmada pela API.'), findsNothing);
    expect(find.textContaining('Consulte sua entrega antes de repetir'),
        findsOneWidget);
    expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        'Não perder este texto');
    expect(
        tester
            .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Enviar resposta'))
            .onPressed,
        isNull);
  });

  testWidgets('closed activity can be consulted but not submitted',
      (tester) async {
    await pumpStudentDetail(tester, (_) async => response(noSubmission),
        activity: activityJson(state: 'closed'));
    await showDelivery(tester);
    expect(find.text('Atividade encerrada ou indisponível para envio.'),
        findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
  });
  testWidgets('deadline without late policy blocks submission', (tester) async {
    await pumpStudentDetail(tester, (_) async => response(noSubmission),
        activity: {...activityJson(), 'dueDate': '2020-01-01T00:00:00Z'});
    await showDelivery(tester);
    expect(find.textContaining('Esta atividade não permite envio em atraso.'),
        findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
  });
  testWidgets('late policy permits textual input and review locks revision',
      (tester) async {
    await pumpStudentDetail(tester, (_) async => response(noSubmission),
        activity: {
          ...activityJson(allowLate: true),
          'dueDate': '2020-01-01T00:00:00Z'
        });
    await showDelivery(tester);
    expect(find.textContaining('permite envio em atraso.'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);
  });
  testWidgets('under-review receipt is read only', (tester) async {
    await pumpStudentDetail(
        tester, (_) async => response(submissionJson(status: 'in_review')));
    await showDelivery(tester);
    expect(find.text('Em avaliação • Versão 1'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
  });
  testWidgets('teacher cannot query personal student submission',
      (tester) async {
    await pumpStudentDetail(tester,
        (_) async => throw StateError('Must not query student submission'),
        user: fakeTeacher);
    await tester.scrollUntilVisible(
        find.text('Consulta e envio pessoais disponíveis apenas para alunos.'),
        250,
        scrollable: find.byType(Scrollable).first);
    expect(find.byType(TextFormField), findsNothing);
  });
}
