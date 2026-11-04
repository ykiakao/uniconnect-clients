import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uniconnect/core/network/api_client.dart';
import 'package:uniconnect/features/academic/demo/synthetic_academic_providers.dart';
import 'package:uniconnect/features/auth/models/app_user.dart';
import 'package:uniconnect/features/auth/providers/auth_provider.dart';
import 'package:uniconnect/features/auth/services/api_auth_service.dart';
import 'package:uniconnect/features/grades/presentation/grades_page.dart';
import 'package:uniconnect/features/tenant/models/tenant_context.dart';

import 'fakes/fake_auth_service.dart';
import 'fakes/fake_session_storage.dart';
import 'student_report_card_service_test.dart'
    show
        reportCardJson,
        reportOffering,
        reportPage,
        reportResponse,
        reportStage;

class _SwitchingAuth extends FakeAuthService {
  _SwitchingAuth();

  AuthSession next = _session(fakeStudent, 'token-a');

  @override
  Future<AuthSession> login(
          {required String email, required String password}) async =>
      next;
}

AuthSession _session(AppUser user, String token) => AuthSession(
      user: user,
      accessToken: token,
      refreshToken: 'fixture-refresh',
      expiresAt: 4102444800,
    );

Future<AuthController> _mount(WidgetTester tester,
    Future<http.Response> Function(http.Request) reportHandler,
    {_SwitchingAuth? authService, ValueNotifier<bool>? showGrades}) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  tester.view.physicalSize = const Size(390, 1500);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final auth =
      AuthController(authService ?? _SwitchingAuth(), FakeSessionStorage());
  await auth.login(
      email: fakeStudent.email, password: 'fixture', rememberSession: false);
  final client = ApiClient(
    baseUrl: 'https://fixture.invalid/api/v1',
    httpClient: MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, isNot(endsWith('/grades')));
      expect(request.url.path, isNot(endsWith('/courses')));
      return reportHandler(request);
    }),
  );
  await tester.pumpWidget(ProviderScope(
    retry: (_, __) => null,
    overrides: [
      authControllerProvider.overrideWith((ref) => auth),
      apiClientProvider.overrideWithValue(client),
      syntheticDemoRequestedProvider.overrideWithValue(false),
    ],
    child: MaterialApp(
      home: showGrades == null
          ? const GradesPage()
          : ValueListenableBuilder<bool>(
              valueListenable: showGrades,
              builder: (_, show, __) =>
                  show ? const GradesPage() : const SizedBox(),
            ),
    ),
  ));
  await tester.pumpAndSettle();
  return auth;
}

Future<void> _select(WidgetTester tester, String name,
    {bool settle = true}) async {
  final selector = find.byType(DropdownButtonFormField<String>);
  await tester.ensureVisible(selector);
  await tester.tap(selector);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.tap(find.text(name).last);
  await tester.pump();
  if (settle) await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'lists authorized offers, renders only official partial stages and preserves zero and null',
      (tester) async {
    final paths = <String>[];
    await _mount(tester, (request) async {
      paths.add(request.url.path);
      expect(request.headers['Authorization'], 'Bearer token-a');
      expect(request.headers['x-tenant-slug'], fakeTenant.slug);
      if (request.url.path.endsWith('/offerings')) {
        return reportResponse(
            reportPage([reportOffering('class-1'), reportOffering('class-2')]));
      }
      expect(request.url.query, isEmpty);
      return reportResponse(reportCardJson(
        classId: 'class-2',
        n1: {
          ...reportStage(examPoints: '0.00', total: '0.00', pending: 2),
          'draftValue': '9.87'
        },
        n2: reportStage(
            activityPoints: '0.00999', total: '0.00999', pending: 1),
      ));
    });
    expect(paths, ['/api/v1/tenants/instituicao-teste/offerings']);
    await _select(tester, 'Métodos • Oferta class-2');
    expect(paths.last,
        '/api/v1/tenants/instituicao-teste/classes/class-2/report-card/me');
    expect(find.text('N1 • Aberta'), findsOneWidget);
    expect(find.text('N2 • Aberta'), findsOneWidget);
    expect(find.text('Pontos de provas: 0,00'), findsOneWidget);
    expect(find.text('Pontos de trabalhos: Não disponível'), findsOneWidget);
    expect(find.text('Total parcial: 0,00999'), findsOneWidget);
    expect(find.text('2 avaliações pendentes'), findsOneWidget);
    expect(find.text('1 avaliação pendente'), findsOneWidget);
    expect(find.text('Resultado semestral parcial'), findsOneWidget);
    expect(find.textContaining('Média semestral:'), findsNothing);
    expect(find.textContaining('9,87'), findsNothing);
  });

  for (final (status, average, label) in [
    ('approved', '7.00', 'Aprovado'),
    ('final_exam_eligible', '6.99', 'Elegível à prova final'),
    ('below_minimum', '4.999995', 'Abaixo da média mínima'),
  ]) {
    testWidgets('shows official status $status without rounding',
        (tester) async {
      await _mount(tester, (request) async {
        if (request.url.path.endsWith('/offerings')) {
          return reportResponse(reportPage([reportOffering('class-1')]));
        }
        return reportResponse(reportCardJson(
          n1: reportStage(closed: true, examPoints: average, total: average),
          n2: reportStage(closed: true, examPoints: average, total: average),
          status: status,
          average: average,
        ));
      });
      await _select(tester, 'Métodos');
      expect(find.text('N1 • Fechada'), findsOneWidget);
      expect(find.text('N2 • Fechada'), findsOneWidget);
      expect(find.text('Total definitivo: ${average.replaceAll('.', ',')}'),
          findsNWidgets(2));
      expect(find.text('Média semestral: ${average.replaceAll('.', ',')}'),
          findsOneWidget);
      expect(find.text(label), findsOneWidget);
    });
  }

  testWidgets(
      'shows a closed stage outside the student roster and an open pending stage',
      (tester) async {
    await _mount(tester, (request) async {
      if (request.url.path.endsWith('/offerings')) {
        return reportResponse(reportPage([reportOffering('class-1')]));
      }
      return reportResponse(reportCardJson(
          n1: reportStage(closed: true, applies: false),
          n2: reportStage(pending: 1)));
    });
    await _select(tester, 'Métodos');
    expect(
        find.text('Esta etapa não se aplica ao seu vínculo.'), findsOneWidget);
    expect(find.text('Total: Não disponível'), findsOneWidget);
    expect(find.text('1 avaliação pendente'), findsOneWidget);
    expect(find.textContaining('Média semestral:'), findsNothing);
  });

  testWidgets('handles an empty offering list and offers without assessments',
      (tester) async {
    var empty = true;
    await _mount(tester, (request) async {
      if (request.url.path.endsWith('/offerings')) {
        return reportResponse(
            reportPage(empty ? [] : [reportOffering('class-1')]));
      }
      return reportResponse(reportCardJson());
    });
    expect(find.text('Nenhuma disciplina disponível'), findsOneWidget);
    empty = false;
    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pumpAndSettle();
    await _select(tester, 'Métodos');
    expect(find.text('Oferta sem avaliações no boletim'), findsOneWidget);
  });

  testWidgets('keeps the valid offer when leaving and returning to grades',
      (tester) async {
    final showGrades = ValueNotifier(true);
    addTearDown(showGrades.dispose);
    final reports = <String>[];
    await _mount(tester, (request) async {
      if (request.url.path.endsWith('/offerings')) {
        return reportResponse(reportPage([
          reportOffering('class-1', name: 'Oferta A'),
          reportOffering('class-2', name: 'Oferta B'),
        ]));
      }
      reports.add(request.url.path);
      return reportResponse(reportCardJson(classId: 'class-2'));
    }, showGrades: showGrades);
    expect(reports, isEmpty);
    await _select(tester, 'Oferta B');
    expect(reports.single, endsWith('/class-2/report-card/me'));
    showGrades.value = false;
    await tester.pumpAndSettle();
    showGrades.value = true;
    await tester.pumpAndSettle();
    expect(find.text('Oferta B'), findsOneWidget);
    expect(find.text('Selecione uma oferta para consultar o boletim.'),
        findsNothing);
    expect(reports, hasLength(2));
    expect(reports.last, endsWith('/class-2/report-card/me'));
  });

  testWidgets('discards a late report when switching offers', (tester) async {
    final late = Completer<http.Response>();
    await _mount(tester, (request) async {
      if (request.url.path.endsWith('/offerings')) {
        return reportResponse(reportPage([
          reportOffering('class-1', name: 'Oferta inicial'),
          reportOffering('class-2', name: 'Oferta atual'),
        ]));
      }
      if (request.url.path.contains('/class-1/')) return late.future;
      return reportResponse(reportCardJson(
          classId: 'class-2',
          n1: reportStage(examPoints: '2.25', total: '2.25')));
    });
    await _select(tester, 'Oferta inicial', settle: false);
    expect(find.text('Carregando boletim…'), findsOneWidget);
    await _select(tester, 'Oferta atual');
    late.complete(reportResponse(
        reportCardJson(n1: reportStage(examPoints: '5.75', total: '5.75'))));
    await tester.pumpAndSettle();
    expect(find.text('Total parcial: 2,25'), findsOneWidget);
    expect(find.text('Total parcial: 5,75'), findsNothing);
  });

  for (final (kind, message) in [
    ('network', 'Confira sua conexão e tente novamente.'),
    ('expired', 'Sessão expirada. Entre novamente.'),
    ('forbidden', 'O boletim não está disponível para seu vínculo acadêmico.'),
    ('invalid', 'A API retornou uma resposta acadêmica inválida.'),
  ]) {
    testWidgets('shows a safe retryable message for $kind', (tester) async {
      var requests = 0;
      await _mount(tester, (request) async {
        if (request.url.path.endsWith('/offerings')) {
          return reportResponse(reportPage([reportOffering('class-1')]));
        }
        if (++requests == 1) {
          switch (kind) {
            case 'network':
              throw http.ClientException('private transport');
            case 'expired':
              return reportResponse({
                'error': {'message': 'private note'}
              }, 401);
            case 'forbidden':
              return reportResponse({
                'error': {'message': 'private note'}
              }, 403);
            default:
              return reportResponse(
                  {'classId': 'class-1', 'private': 'private note'});
          }
        }
        return reportResponse(reportCardJson());
      });
      await _select(tester, 'Métodos');
      expect(find.text(message), findsOneWidget);
      expect(find.textContaining('private'), findsNothing);
      await tester.tap(find.text('Tentar Novamente'));
      await tester.pumpAndSettle();
      expect(find.text('Oferta sem avaliações no boletim'), findsOneWidget);
    });
  }

  testWidgets(
      'clears report selection on logout and isolates a new tenant session',
      (tester) async {
    final service = _SwitchingAuth();
    final late = Completer<http.Response>();
    var oldReports = 0;
    final auth = await _mount(tester, (request) async {
      final old = request.headers['x-tenant-slug'] == fakeTenant.slug;
      expect(request.headers['Authorization'],
          old ? 'Bearer token-a' : 'Bearer token-b');
      expect(request.url.path,
          contains(old ? '/tenants/instituicao-teste/' : '/tenants/campus-b/'));
      if (request.url.path.endsWith('/offerings')) {
        return reportResponse(reportPage([
          reportOffering('class-1',
              name: old ? 'Disciplina A' : 'Disciplina B',
              tenantId: old ? fakeTenant.id : 'tenant-b'),
          if (!old)
            reportOffering('class-2',
                name: 'Disciplina C', tenantId: 'tenant-b'),
        ]));
      }
      if (old && ++oldReports > 1) return late.future;
      return reportResponse(reportCardJson(
        studentId: old ? fakeStudent.id : 'student-b',
        n1: reportStage(
            examPoints: old ? '5.50' : '6.25', total: old ? '5.50' : '6.25'),
      ));
    }, authService: service);
    await _select(tester, 'Disciplina A');
    expect(find.text('Total parcial: 5,50'), findsOneWidget);

    await tester.tap(find.text('Atualizar boletim'));
    await tester.pump();
    await auth.logout();
    await tester.pumpAndSettle();
    expect(find.text('Boletim acadêmico N1/N2'), findsNothing);

    const tenantB = TenantContext(
        id: 'tenant-b',
        name: 'Campus B',
        slug: 'campus-b',
        plan: SubscriptionPlan.growth,
        status: SubscriptionStatus.trialing,
        activeUsers: 5);
    service.next = _session(
        const AppUser(
            id: 'student-b',
            name: 'Aluno B',
            email: 'b@example.invalid',
            role: UserRole.student,
            tenant: tenantB),
        'token-b');
    await auth.login(
        email: 'b@example.invalid',
        password: 'fixture',
        rememberSession: false);
    await tester.pumpAndSettle();
    expect(find.text('Selecione uma oferta para consultar o boletim.'),
        findsOneWidget);
    await _select(tester, 'Disciplina B');
    late.complete(reportResponse(
        reportCardJson(n1: reportStage(examPoints: '5.50', total: '5.50'))));
    await tester.pumpAndSettle();
    expect(find.text('Total parcial: 6,25'), findsOneWidget);
    expect(find.text('Total parcial: 5,50'), findsNothing);
  });
}
