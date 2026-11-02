import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uniconnect/features/teacher/presentation/teacher_grades_page.dart';
import 'demo_day_test.dart' show pumpDemoPage;
import 'fakes/fake_auth_service.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uniconnect/core/network/api_client.dart';
import 'package:uniconnect/core/theme/app_theme.dart';
import 'package:uniconnect/features/auth/providers/auth_provider.dart';
import 'package:uniconnect/features/auth/services/api_auth_service.dart';
import 'fakes/fake_session_storage.dart';
import 'student_activity_contract_test.dart'
    show activityJson, listJson, response;
import 'teacher_review_service_test.dart' show reviewJson, reviewedSubmission;
import 'layout_quality_test.dart' show captureLayout;

Future<AuthController> pumpReviews(
    WidgetTester tester, Future<http.Response> Function(http.Request) handler,
    {double width = 390, double scale = 1, GlobalKey? frame}) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final auth = AuthController(
      FakeAuthService(
          loginResult: const AuthSession(
              accessToken: 'token',
              refreshToken: 'fixture',
              expiresAt: 4102444800,
              user: fakeTeacher)),
      FakeSessionStorage());
  await auth.login(
      email: fakeTeacher.email, password: 'fixture', rememberSession: false);
  await tester.pumpWidget(ProviderScope(
      retry: (_, __) => null,
      overrides: [
        authControllerProvider.overrideWith((ref) => auth),
        apiClientProvider
            .overrideWithValue(ApiClient(httpClient: MockClient((r) {
          expect(r.headers['Authorization'], 'Bearer token');
          expect(r.headers['x-tenant-slug'], fakeTeacher.tenant.slug);
          if (r.url.path.endsWith('/offerings')) {
            return Future.value(response(listJson([
              {'id': 'class-1', 'name': 'Métodos', 'status': 'active'}
            ])));
          }
          if (r.url.path.endsWith('/classes/class-1/activities')) {
            return Future.value(response(listJson([activityJson()])));
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
              home: const TeacherGradesPage()))));
  await tester.pumpAndSettle();
  for (final item in [(0, 'Métodos • class-1'), (1, 'Pesquisa • Publicada')]) {
    final dropdown = find.byType(DropdownButtonFormField<String>).at(item.$1);
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text(item.$2).last);
    await tester.pumpAndSettle();
  }
  return auth;
}

Future<void> tapReview(WidgetTester tester, String text) async {
  tester.testTextInput.hide();
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
      find.text(text), text == 'Atualizar entrega e avaliação' ? -200 : 200,
      scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(text));
  await tester.pump();
}

Future<void> openReview(WidgetTester tester) async {
  await tapReview(tester, 'Abrir entrega');
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'excess precision preserves grade text and feedback without sending',
      (tester) async {
    Map<String, dynamic>? review;
    var writes = 0;
    await pumpReviews(tester, (r) async {
      if (r.method == 'GET') {
        return response(r.url.path.endsWith('/submissions')
            ? listJson([reviewedSubmission(result: review)])
            : reviewedSubmission(result: review));
      }
      writes++;
      expect(jsonDecode(r.body)['grade'], 7.25);
      expect(jsonDecode(r.body)['feedback'], 'Feedback preservado');
      review = reviewJson(grade: 7.25, feedback: 'Feedback preservado');
      return response(review!);
    });
    await openReview(tester);
    await tester.enterText(
        find.byType(TextFormField).at(1), 'Feedback preservado');
    for (final text in [
      '7,255',
      '7.25000000000000001',
      '1.00000000000000001',
      '0.30000000000000004'
    ]) {
      await tester.enterText(find.byType(TextFormField).first, text);
      await tapReview(tester, 'Salvar correção');
      await tester.pumpAndSettle();
      expect(find.text('A nota deve ter no máximo duas casas decimais.'),
          findsOneWidget);
      expect(writes, 0);
      expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField).first)
              .controller!
              .text,
          text);
      expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField).at(1))
              .controller!
              .text,
          'Feedback preservado');
    }
    await tester.enterText(find.byType(TextFormField).first, '7,2500');
    await tapReview(tester, 'Salvar correção');
    await tester.pumpAndSettle();
    expect(writes, 1);
    expect(find.text('Correção salva. Resultado ainda não publicado.'),
        findsOneWidget);
  });
  setUpAll(() async {
    await (FontLoader('Inter')
          ..addFont(rootBundle.load('assets/fonts/Inter/Inter-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Inter/Inter-Bold.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  testWidgets('review controls remain usable at 320px with enlarged text',
      (tester) async {
    final frame = GlobalKey();
    await pumpReviews(
        tester,
        (r) async => response(r.url.path.endsWith('/submissions')
            ? listJson([reviewedSubmission()])
            : reviewedSubmission()),
        width: 320,
        scale: 2,
        frame: frame);
    await openReview(tester);
    await tester.scrollUntilVisible(find.text('Salvar correção'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await captureLayout(tester, frame, 'teacher-review-320-text200');
  });
  testWidgets(
      'late save completion after logout cannot restore private answer or success',
      (tester) async {
    final pending = Completer<http.Response>();
    final auth = await pumpReviews(
        tester,
        (r) async => r.method == 'GET'
            ? response(r.url.path.endsWith('/submissions')
                ? listJson([reviewedSubmission()])
                : reviewedSubmission())
            : pending.future);
    await openReview(tester);
    await tester.enterText(find.byType(TextFormField).first, '0');
    await tapReview(tester, 'Salvar correção');
    await auth.logout();
    await tester.pumpAndSettle();
    pending.complete(response(reviewJson(grade: 0, feedback: null)));
    await tester.pumpAndSettle();
    expect(find.text('Minha resposta'), findsNothing);
    expect(find.text('Correção salva. Resultado ainda não publicado.'),
        findsNothing);
  });
  testWidgets(
      'pending publication blocks duplicate action and awaits confirmation',
      (tester) async {
    final pending = Completer<http.Response>();
    var review = reviewJson();
    var writes = 0;
    await pumpReviews(tester, (r) async {
      if (r.method == 'GET') {
        return response(r.url.path.endsWith('/submissions')
            ? listJson([reviewedSubmission(result: review)])
            : reviewedSubmission(result: review));
      }
      writes++;
      final result = await pending.future;
      review = reviewJson(revision: 2, state: 'published');
      return result;
    });
    await openReview(tester);
    await tapReview(tester, 'Publicar avaliação');
    expect(
        find.text('Avaliação publicada e confirmada pela API.'), findsNothing);
    expect(
        tester
            .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Publicar avaliação'))
            .onPressed,
        isNull);
    await tester.tap(find.text('Publicar avaliação'));
    await tester.pump();
    expect(writes, 1);
    pending.complete(response(reviewJson(revision: 2, state: 'published')));
    await tester.pumpAndSettle();
    expect(find.text('Avaliação publicada e confirmada pela API.'),
        findsOneWidget);
  });
  testWidgets(
      'revision and submission conflict preserves fields and uses refreshed versions',
      (tester) async {
    var version = 1, revision = 1, writes = 0;
    var review = reviewJson();
    Map<String, dynamic> current() =>
        {...reviewedSubmission(result: review), 'version': version};
    await pumpReviews(tester, (r) async {
      if (r.method == 'GET') {
        return response(r.url.path.endsWith('/submissions')
            ? listJson([current()])
            : current());
      }
      writes++;
      if (writes == 1) {
        version = 2;
        revision = 3;
        review = reviewJson(version: version, revision: revision);
        return response({
          'error': {'message': 'Conflito'}
        }, 409);
      }
      expect(jsonDecode(r.body), {
        'expectedRevision': 3,
        'submissionVersion': 2,
        'grade': 7.25,
        'feedback': 'Preservar feedback',
        'publish': false
      });
      review = reviewJson(
          grade: 7.25, feedback: 'Preservar feedback', version: 2, revision: 4);
      return response(review);
    });
    await openReview(tester);
    await tester.enterText(find.byType(TextFormField).at(0), '7,25');
    await tester.enterText(
        find.byType(TextFormField).at(1), 'Preservar feedback');
    await tapReview(tester, 'Salvar correção');
    await tester.pumpAndSettle();
    expect(find.textContaining('Conflito de versão'), findsOneWidget);
    expect(
        tester
            .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Salvar correção'))
            .onPressed,
        isNull);
    await tapReview(tester, 'Atualizar entrega e avaliação');
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        '7,25');
    expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(1))
            .controller!
            .text,
        'Preservar feedback');
    expect(
        tester
            .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Publicar avaliação'))
            .onPressed,
        isNull);
    await tapReview(tester, 'Salvar correção');
    await tester.pumpAndSettle();
    expect(writes, 2);
    expect(find.text('Revisão da avaliação: 4'), findsOneWidget);
  });
  testWidgets('publication conflict requires refresh and current revision',
      (tester) async {
    var review = reviewJson();
    var publishes = 0;
    await pumpReviews(tester, (r) async {
      final row = reviewedSubmission(result: review);
      if (r.method == 'GET') {
        return response(
            r.url.path.endsWith('/submissions') ? listJson([row]) : row);
      }
      publishes++;
      if (publishes == 1) {
        review = reviewJson(revision: 4);
        return response({
          'error': {'message': 'Conflito'}
        }, 409);
      }
      expect(jsonDecode(r.body), {'expectedRevision': 4});
      review = reviewJson(revision: 5, state: 'published');
      return response(review);
    });
    await openReview(tester);
    await tapReview(tester, 'Publicar avaliação');
    await tester.pumpAndSettle();
    expect(
        find.text('Avaliação publicada e confirmada pela API.'), findsNothing);
    expect(
        tester
            .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Publicar avaliação'))
            .onPressed,
        isNull);
    await tapReview(tester, 'Atualizar entrega e avaliação');
    await tester.pumpAndSettle();
    await tapReview(tester, 'Publicar avaliação');
    await tester.pumpAndSettle();
    expect(publishes, 2);
    expect(find.text('Avaliação publicada'), findsOneWidget);
  });
  testWidgets('temporary refresh failure does not erase pending feedback',
      (tester) async {
    var fail = false;
    await pumpReviews(tester, (r) async {
      if (r.url.path.endsWith('/submissions')) {
        return response(listJson([reviewedSubmission()]));
      }
      return fail
          ? response({
              'error': {'message': 'Indisponível'}
            }, 503)
          : response(reviewedSubmission());
    });
    await openReview(tester);
    await tester.enterText(
        find.byType(TextFormField).at(1), 'Feedback pendente');
    fail = true;
    await tapReview(tester, 'Atualizar entrega e avaliação');
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(1))
            .controller!
            .text,
        'Feedback pendente');
    fail = false;
    await tapReview(tester, 'Atualizar entrega e avaliação');
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(1))
            .controller!
            .text,
        'Feedback pendente');
  });
  testWidgets(
      'teacher reads answer, saves zero and feedback privately then explicitly publishes',
      (tester) async {
    Map<String, dynamic>? review;
    var saves = 0, publications = 0;
    await pumpReviews(tester, (r) async {
      final row = reviewedSubmission(result: review);
      if (r.method == 'GET') {
        return response(
            r.url.path.endsWith('/submissions') ? listJson([row]) : row);
      }
      if (r.method == 'PUT') {
        saves++;
        expect(jsonDecode(r.body), {
          'expectedRevision': 0,
          'submissionVersion': 1,
          'grade': 0,
          'feedback': 'Muito bom',
          'publish': false
        });
        review = reviewJson(grade: 0, feedback: 'Muito bom');
        return response(review!);
      }
      publications++;
      expect(jsonDecode(r.body), {'expectedRevision': 1});
      review = reviewJson(
          grade: 0, feedback: 'Muito bom', revision: 2, state: 'published');
      return response(review!);
    });
    await openReview(tester);
    expect(find.text('Minha resposta'), findsOneWidget);
    expect(find.text('Aluno: student-test'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), '11');
    await tapReview(tester, 'Salvar correção');
    expect(find.textContaining('Informe uma nota de 0 a 10'), findsOneWidget);
    expect(saves, 0);
    await tester.enterText(find.byType(TextFormField).at(0), '0');
    await tester.enterText(find.byType(TextFormField).at(1), 'Muito bom');
    await tapReview(tester, 'Salvar correção');
    await tester.pumpAndSettle();
    expect(find.text('Correção salva. Resultado ainda não publicado.'),
        findsOneWidget);
    expect(publications, 0);
    await tapReview(tester, 'Publicar avaliação');
    await tester.pumpAndSettle();
    expect(publications, 1);
    expect(find.text('Avaliação publicada'), findsOneWidget);
    expect(find.text('Avaliação publicada e confirmada pela API.'),
        findsOneWidget);
    expect(find.text('Nota registrada: 0.0'), findsOneWidget);
  });
  testWidgets('empty and denied lists are different states', (tester) async {
    await pumpReviews(tester, (_) async => response(listJson([])));
    expect(find.text('Nenhuma entrega nesta atividade.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await pumpReviews(
        tester,
        (_) async => response({
              'error': {'message': 'Acesso negado'}
            }, 403));
    expect(find.textContaining('Erro ao consultar entregas.'), findsOneWidget);
    expect(find.text('Nenhuma entrega nesta atividade.'), findsNothing);
  });
  testWidgets('pending save blocks duplicate writes and cannot report success',
      (tester) async {
    final pending = Completer<http.Response>();
    var writes = 0;
    Map<String, dynamic>? review;
    await pumpReviews(tester, (r) async {
      if (r.method == 'GET') {
        return response(r.url.path.endsWith('/submissions')
            ? listJson([reviewedSubmission(result: review)])
            : reviewedSubmission(result: review));
      }
      writes++;
      final row = await pending.future;
      review = reviewJson(grade: 0, feedback: null);
      return row;
    });
    await openReview(tester);
    await tester.enterText(find.byType(TextFormField).first, '0');
    await tapReview(tester, 'Salvar correção');
    expect(find.text('Correção salva. Resultado ainda não publicado.'),
        findsNothing);
    expect(
        tester
            .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Salvar correção'))
            .onPressed,
        isNull);
    await tester.tap(find.text('Salvar correção'));
    await tester.pump();
    expect(writes, 1);
    pending.complete(response(reviewJson(grade: 0, feedback: null)));
    await tester.pumpAndSettle();
    expect(find.text('Correção salva. Resultado ainda não publicado.'),
        findsOneWidget);
  });
  testWidgets('student cannot view teacher submission list', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await pumpDemoPage(tester, const TeacherGradesPage());
    expect(find.text('Área exclusiva do professor'), findsOneWidget);
    expect(find.text('Ana Clara Oliveira'), findsNothing);
  });
  testWidgets(
      'teacher selects authorized offering rather than synthetic student rows',
      (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await pumpDemoPage(tester, const TeacherGradesPage(), user: fakeTeacher);
    await tester.pumpAndSettle();
    expect(find.text('Oferta acadêmica'), findsOneWidget);
    expect(find.text('P1'), findsNothing);
    expect(find.text('Média da Turma'), findsNothing);
  });
}
