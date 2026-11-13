import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uniconnect/core/network/api_client.dart';
import 'package:uniconnect/features/auth/models/app_user.dart';
import 'package:uniconnect/features/auth/providers/auth_provider.dart';
import 'package:uniconnect/features/auth/services/api_auth_service.dart';
import 'package:uniconnect/features/teacher/presentation/create_activity_page.dart';
import 'package:uniconnect/features/teacher/presentation/teacher_grades_page.dart';
import 'package:uniconnect/features/teacher/providers/teacher_activity_provider.dart';
import 'package:uniconnect/features/teacher/providers/teacher_review_provider.dart';
import 'package:uniconnect/features/teacher/services/teacher_review_service.dart';
import 'package:uniconnect/features/tenant/models/tenant_context.dart';
import 'demo_day_test.dart' show pumpDemoPage;
import 'fakes/fake_auth_service.dart';
import 'fakes/fake_session_storage.dart';
import 'teacher_activity_service_test.dart'
    show activityRow, jsonResponse, page, service;
import 'teacher_academic_service_test.dart'
    show
        academicPage,
        examResult,
        reportJson,
        rosterJson,
        stageJson,
        studentJson;

const offerings = [
  {'id': 'class-1', 'name': 'Métodos', 'status': 'active'},
  {'id': 'class-2', 'name': 'Outra oferta', 'status': 'active'},
];
const examMetadata = {'stage': 'N1', 'category': 'exam', 'maxPoints': '7.00'};

class _NotesAuth extends FakeAuthService {
  AppUser user = fakeTeacher;
  String token = 'token-a';

  @override
  Future<AuthSession> login(
          {required String email, required String password}) async =>
      AuthSession(
        user: user,
        accessToken: token,
        refreshToken: 'fixture-refresh',
        expiresAt: 4102444800,
      );

  @override
  Future<AuthSession> refresh(String refreshToken,
      {required String tenantSlug}) async {
    token = 'token-a-rotated';
    return AuthSession(
      user: user,
      accessToken: token,
      refreshToken: 'fixture-rotated-refresh',
      expiresAt: 4102444800,
    );
  }
}

Future<void> pumpAcademic(WidgetTester tester, Widget widget,
    Future<http.Response> Function(http.Request) handler) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  final api = service((request) {
    if (request.url.path.endsWith('/offerings')) {
      return Future.value(jsonResponse(page(offerings)));
    }
    return handler(request);
  });
  await pumpDemoPage(tester, widget, user: fakeTeacher, overrides: [
    teacherActivityServiceProvider.overrideWithValue(api),
    teacherReviewServiceProvider.overrideWithValue(TeacherReviewService(
      ApiClient(
          baseUrl: 'https://fixture.invalid/api/v1',
          httpClient: MockClient(handler)),
      accessToken: 'fixture-token',
      tenantSlug: 'campus',
    )),
  ]);
  await tester.pumpAndSettle();
}

Future<void> select(WidgetTester tester, int index, String option) async {
  final dropdown = find.byType(DropdownButtonFormField<String>).at(index);
  await tester.ensureVisible(dropdown);
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Future<void> tapLabel(WidgetTester tester, String label) async {
  final target = find.text(label).last;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'entry lists N2 exams and excludes work submissions while preserving discipline',
      (tester) async {
    final paths = <String>[];
    await pumpAcademic(tester, const TeacherGradesPage(), (request) async {
      final path = request.url.path;
      if (path.endsWith('/classes/class-1/activities')) {
        return jsonResponse(page([
          {
            ...activityRow(state: 'published'),
            'id': 'work-n2',
            'title': 'Trabalho',
            'assessment': {
              'stage': 'N2',
              'category': 'activity',
              'maxPoints': '2.00'
            },
          },
          activityRow(state: 'published'),
          {
            ...activityRow(state: 'draft'),
            'id': 'exam-n2',
            'title': 'Prova N2',
            'assessment': {...examMetadata, 'stage': 'N2'},
          },
        ]));
      }
      if (path.endsWith('/classes/class-2/activities')) {
        return jsonResponse(page([]));
      }
      paths.add(path);
      return jsonResponse(page([]));
    });
    expect(find.widgetWithText(AppBar, 'Notas'), findsOneWidget);
    expect(find.text('Disciplina'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Lançar notas'))
            .onPressed,
        isNull);
    expect(
        tester
            .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Consultar boletim'))
            .onPressed,
        isNull);
    await select(tester, 0, 'Métodos');
    await tapLabel(tester, 'Lançar notas');
    final dropdown = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>));
    expect(dropdown.initialValue, isNull);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    expect(find.text('Trabalho — N2 • Atividade • Publicada'), findsNothing);
    expect(find.text('Pesquisa • Publicada'), findsNothing);
    expect(find.text('Prova N2 — N2 • Prova • Rascunho'), findsWidgets);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(paths, isEmpty);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Notas'), findsOneWidget);
    expect(find.text('Métodos'), findsOneWidget);
    await select(tester, 0, 'Outra oferta');
    await tapLabel(tester, 'Lançar notas');
    expect(find.text('Nenhuma prova nesta disciplina.'), findsOneWidget);
  });

  testWidgets(
      'token renewal keeps Notes selection and logout hides open exam data',
      (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final service = _NotesAuth();
    final auth = AuthController(service, FakeSessionStorage());
    Future<void> signIn() => auth.login(
          email: service.user.email,
          password: 'fixture',
          rememberSession: false,
        );
    await signIn();
    final api = ApiClient(
      baseUrl: 'https://fixture.invalid/api/v1',
      httpClient: MockClient((request) async {
        final old = request.headers['x-tenant-slug'] == fakeTenant.slug;
        expectSync(request.headers['Authorization'], 'Bearer ${service.token}');
        expectSync(request.url.path,
            contains('/tenants/${old ? fakeTenant.slug : 'campus-b'}/'));
        if (request.url.path.endsWith('/offerings')) {
          return jsonResponse(page([
            {
              'id': 'class-1',
              'name': old ? 'Disciplina A' : 'Disciplina B',
              'status': 'active'
            },
          ]));
        }
        if (request.url.path.endsWith('/classes/class-1/activities')) {
          return jsonResponse(page(old
              ? [
                  {
                    ...activityRow(),
                    'id': 'exam-1',
                    'title': 'Prova sintética',
                    'assessment': examMetadata,
                  },
                ]
              : []));
        }
        expectSync(old, isTrue);
        expectSync(
            request.url.path, endsWith('/activities/exam-1/exam/grades'));
        return jsonResponse(rosterJson(students: [
          studentJson('student-1', 'Aluno da sessão anterior'),
        ]));
      }),
    );
    await tester.pumpWidget(ProviderScope(
      retry: (_, __) => null,
      overrides: [
        authControllerProvider.overrideWith((ref) => auth),
        apiClientProvider.overrideWithValue(api),
      ],
      child: const MaterialApp(home: TeacherGradesPage()),
    ));
    await tester.pumpAndSettle();
    await select(tester, 0, 'Disciplina A');
    expect(await auth.refreshAccessToken('token-a', fakeTenant.slug),
        'token-a-rotated');
    await tester.pumpAndSettle();
    expect(find.text('Disciplina A'), findsOneWidget);
    await tapLabel(tester, 'Lançar notas');
    await select(tester, 0, 'Prova sintética — N1 • Prova • Rascunho');
    await tapLabel(tester, 'Lançar nota');
    expect(find.byKey(const ValueKey('exam-points-input')), findsOneWidget);
    await auth.logout();
    await tester.pumpAndSettle();
    expect(find.text('A sessão mudou. Retorne à tela Notas.'), findsOneWidget);
    expect(find.text('Aluno da sessão anterior'), findsNothing);
    expect(find.byKey(const ValueKey('exam-points-input')), findsNothing);
    await tapLabel(tester, 'Fechar');
    expect(find.text('Área exclusiva do professor'), findsOneWidget);
    expect(find.text('Disciplina A'), findsNothing);

    service.user = AppUser(
      id: fakeTeacher.id,
      name: fakeTeacher.name,
      email: fakeTeacher.email,
      role: UserRole.teacher,
      tenant: const TenantContext(
        id: 'tenant-b',
        name: 'Campus B',
        slug: 'campus-b',
        plan: SubscriptionPlan.growth,
        status: SubscriptionStatus.trialing,
        activeUsers: 5,
      ),
    );
    service.token = 'token-b';
    await signIn();
    await tester.pumpAndSettle();
    expect(find.text('Disciplina B'), findsOneWidget);
    expect(find.text('Disciplina A'), findsNothing);
    await tapLabel(tester, 'Lançar notas');
    expect(find.text('Disciplina B'), findsOneWidget);
  });

  testWidgets(
      'assessment form validates the item and displays the server allocation error',
      (tester) async {
    var writes = 0;
    Object? sent;
    await pumpAcademic(tester, const CreateActivityPage(), (r) async {
      if (r.method == 'GET') return jsonResponse(page([]));
      writes++;
      sent = jsonDecode(r.body)['assessment'];
      return jsonResponse({
        'error': {'message': 'Distribuicao da etapa excedida'}
      }, 409);
    });
    await select(tester, 0, 'Métodos');
    await tester.enterText(find.byType(TextFormField).first, 'Trabalho');
    await tapLabel(tester, 'Vincular ao boletim N1/N2');
    await select(tester, 2, 'N2');
    final points = find.byKey(const ValueKey('assessment-max-points'));
    await tester.ensureVisible(points);
    await tester.enterText(points, '3,01');
    await tapLabel(tester, 'Salvar rascunho');
    expect(writes, 0);
    expect(find.text('Informe de 0 a 3,00 pontos.'), findsOneWidget);
    await tester.enterText(points, '1,50');
    await tapLabel(tester, 'Salvar rascunho');
    expect(writes, 1);
    expect(sent, {'stage': 'N2', 'category': 'activity', 'maxPoints': '1.50'});
    tester.testTextInput.hide();
    final message = find.textContaining('Distribuicao da etapa excedida');
    await tester.scrollUntilVisible(message, -300,
        scrollable: find.byType(Scrollable).first);
    expect(message, findsOneWidget);
  });

  testWidgets(
      'exam activation, zero draft, explicit publication and conflicting correction',
      (tester) async {
    var opened = false;
    var revision = 0;
    String? score;
    var published = false;
    var publishCalls = 0;
    var rosterCalls = 0;
    final writes = <Object?>[];
    await pumpAcademic(tester, const TeacherGradesPage(), (r) async {
      if (r.url.path.endsWith('/classes/class-1/activities')) {
        return jsonResponse(page([
          {
            ...activityRow(revision: 7),
            'id': 'exam-1',
            'title': 'Prova sintética',
            'assessment': examMetadata,
          }
        ]));
      }
      expect(r.url.path, contains('/activities/exam-1/exam/'));
      if (r.method == 'GET') {
        rosterCalls++;
        final number = int.parse(r.url.queryParameters['page']!);
        return jsonResponse(rosterJson(
            opened: opened,
            revision: opened ? 9 : 8,
            page: number,
            total: 21,
            students: number == 2
                ? [studentJson('student-2', 'Aluno da página 2')]
                : [
                    studentJson(
                        'student-1',
                        'Aluno da prova',
                        score == null
                            ? null
                            : examResult(score!, revision,
                                published: published)),
                  ]));
      }
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      writes.add(data);
      if (r.url.path.endsWith('/activate')) {
        opened = true;
        return jsonResponse({
          'examId': 'exam-1',
          'revision': 9,
          'gradingOpenedAt': '2026-11-03T19:00:00Z'
        });
      }
      if (r.method == 'PUT') {
        score = data['points'] as String;
        return jsonResponse(examResult(score!, ++revision));
      }
      publishCalls++;
      published = true;
      if (publishCalls == 2) {
        revision = 3;
        score = '6.00';
        return jsonResponse({
          'error': {'message': 'Conflito na prova'}
        }, 409);
      }
      return jsonResponse(examResult(score!, ++revision, published: true));
    });
    await select(tester, 0, 'Métodos');
    await tapLabel(tester, 'Lançar notas');
    await select(tester, 0, 'Prova sintética — N1 • Prova • Rascunho');
    expect(find.text('Sem nota'), findsOneWidget);
    await tapLabel(tester, 'Próxima');
    expect(find.text('Aluno da página 2'), findsOneWidget);
    await tapLabel(tester, 'Anterior');
    await tapLabel(tester, 'Abrir pauta');
    await tapLabel(tester, 'Lançar nota');
    await tester.enterText(
        find.byKey(const ValueKey('exam-points-input')), '0,00');
    await tapLabel(tester, 'Salvar rascunho');
    expect(find.text('0,00 pontos • Rascunho'), findsOneWidget);
    expect(publishCalls, 0);
    await tapLabel(tester, 'Publicar nota');
    expect(publishCalls, 0);
    await tapLabel(tester, 'Confirmar publicação');
    expect(find.text('0,00 pontos • Publicada'), findsOneWidget);
    await tapLabel(tester, 'Corrigir nota publicada');
    await tester.enterText(
        find.byKey(const ValueKey('exam-points-input')), '5,50');
    await tapLabel(tester, 'Confirmar correção');
    expect(find.text('6,00 pontos • Publicada'), findsOneWidget);
    expect(find.textContaining('Confira a pauta atualizada'), findsOneWidget);
    expect(publishCalls, 2);
    expect(rosterCalls, greaterThanOrEqualTo(7));
    expect(writes, [
      {'expectedVersion': 8},
      {'expectedRevision': 0, 'points': '0.00'},
      {'expectedRevision': 1},
      {'expectedRevision': 2, 'points': '5.50'},
    ]);
  });

  testWidgets(
      'closure rechecks blockers, requires confirmation and refreshes official results',
      (tester) async {
    var closed = false;
    var blockNextN1 = false;
    var n1Reads = 0;
    var closes = 0;
    await pumpAcademic(tester, const TeacherGradesPage(), (r) async {
      final path = r.url.path;
      if (path.endsWith('/activities')) return jsonResponse(page([]));
      if (path.endsWith('/close')) {
        closes++;
        expect(path, endsWith('/stages/N1/close'));
        closed = true;
        return jsonResponse({
          ...stageJson('class-1', 'N1', closed: true),
          'meta': {'page': 1, 'limit': 1, 'total': 0},
        });
      }
      if (path.endsWith('/stages/N2')) {
        return jsonResponse(stageJson('class-1', 'N2', blocked: true));
      }
      if (path.endsWith('/stages/N1')) {
        n1Reads++;
        final blocked = blockNextN1;
        blockNextN1 = false;
        return jsonResponse(
            stageJson('class-1', 'N1', closed: closed, blocked: blocked));
      }
      if (path.endsWith('/students/student-1')) {
        return jsonResponse({
          'classId': 'class-1',
          ...reportJson('student-1', 'Aluno do boletim', closed: closed)
        });
      }
      return jsonResponse({
        'classId': 'class-1',
        ...academicPage(
            [reportJson('student-1', 'Aluno do boletim', closed: closed)])
      });
    });
    await select(tester, 0, 'Métodos');
    await tapLabel(tester, 'Consultar boletim');
    await select(tester, 0, 'N2');
    expect(find.textContaining('Prova pendente'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Fechar N2'))
            .onPressed,
        isNull);
    await select(tester, 0, 'N1');
    blockNextN1 = true;
    await tapLabel(tester, 'Fechar N1');
    expect(find.textContaining('Confira os bloqueios'), findsOneWidget);
    expect(closes, 0);
    await tapLabel(tester, 'Atualizar boletim e pendências');
    await tapLabel(tester, 'Fechar N1');
    expect(find.text('Fechar N1?'), findsOneWidget);
    expect(closes, 0);
    await tapLabel(tester, 'Confirmar fechamento');
    expect(closes, 1);
    expect(n1Reads, greaterThanOrEqualTo(5));
    expect(find.text('N1 fechada pela API.'), findsOneWidget);
    await tapLabel(tester, 'Consultar boletim individual');
    expect(find.text('Média semestral: 6,999995'), findsOneWidget);
    expect(find.text('Elegível à prova final'), findsOneWidget);
  });

  testWidgets(
      'switching offerings discards a late summary from the previous offering',
      (tester) async {
    final late = Completer<http.Response>();
    await pumpAcademic(tester, const TeacherGradesPage(), (r) async {
      final path = r.url.path;
      final id = path.contains('/class-2/') ? 'class-2' : 'class-1';
      if (path.endsWith('/activities')) return jsonResponse(page([]));
      if (path.endsWith('/stages/N1')) {
        return jsonResponse(stageJson(id, 'N1', blocked: true));
      }
      if (id == 'class-1') return late.future;
      return jsonResponse({
        'classId': id,
        ...academicPage([reportJson('student-2', 'Aluno da oferta nova')])
      });
    });
    await select(tester, 0, 'Métodos');
    await tester.tap(find.text('Consultar boletim'));
    await tester.pump();
    await tester.tap(find.byTooltip('Retornar'));
    await tester.pumpAndSettle();
    expect(find.text('Métodos'), findsOneWidget);
    await select(tester, 0, 'Outra oferta');
    await tapLabel(tester, 'Consultar boletim');
    late.complete(jsonResponse({
      'classId': 'class-1',
      ...academicPage([reportJson('student-1', 'Aluno da oferta antiga')])
    }));
    await tester.pumpAndSettle();
    expect(find.text('Aluno da oferta nova'), findsOneWidget);
    expect(find.text('Aluno da oferta antiga'), findsNothing);
  });
}
