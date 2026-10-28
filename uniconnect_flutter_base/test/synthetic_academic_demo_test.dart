import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:uniconnect/core/theme/app_theme.dart';
import 'package:uniconnect/features/academic/demo/synthetic_academic_providers.dart';
import 'package:uniconnect/features/academic/demo/synthetic_academic_data.dart';
import 'package:uniconnect/features/activities/models/academic_activity.dart';
import 'package:uniconnect/features/activities/presentation/activities_page.dart';
import 'package:uniconnect/features/activities/presentation/activity_detail_page.dart';
import 'package:uniconnect/features/activities/providers/activity_provider.dart';
import 'package:uniconnect/features/auth/providers/auth_provider.dart';
import 'package:uniconnect/features/auth/services/api_auth_service.dart';
import 'package:uniconnect/features/grades/presentation/grades_page.dart';
import 'package:uniconnect/features/grades/providers/grades_provider.dart';
import 'package:uniconnect/features/student/presentation/student_dashboard_page.dart';
import 'package:uniconnect/features/profile/presentation/profile_page.dart';
import 'package:uniconnect/main.dart';

import 'fakes/fake_auth_service.dart';
import 'fakes/fake_session_storage.dart';
import 'layout_quality_test.dart' show captureLayout;
import 'synthetic_academic_data_test.dart'
    show syntheticStudent, CountingAcademicApi, signIn;

Finder get verticalScroll => find
    .byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
    .last;

const notice = 'Dados demonstrativos — EduKMais';
const demoExplanation =
    'Ambiente de demonstração. Dados acadêmicos fictícios da EduKMais.';
Finder get demoContext => find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.label == demoExplanation);

Future<(ProviderContainer, CountingAcademicApi)> prepare(WidgetTester tester,
    {bool enabled = true, Completer<AcademicActivity?>? detailResult}) async {
  return (await tester.runAsync(() async {
    final api = CountingAcademicApi();
    final container = ProviderContainer(retry: (_, __) => null, overrides: [
      syntheticDemoRequestedProvider.overrideWithValue(enabled),
      if (detailResult != null)
        activityByIdProvider.overrideWith((ref, id) => detailResult.future),
      apiAuthServiceProvider.overrideWithValue(FakeAuthService(
          loginResult: const AuthSession(
              accessToken: 'test-token',
              refreshToken: 'test-refresh',
              expiresAt: null,
              user: syntheticStudent))),
      sessionStorageProvider.overrideWithValue(FakeSessionStorage()),
      academicApiServiceProvider.overrideWithValue(api),
    ]);
    addTearDown(container.dispose);
    await signIn(container, syntheticStudent);
    await container.read(activitiesProvider.future);
    await container.read(subjectGradesProvider.future);
    return (container, api);
  }))!;
}

Future<GlobalKey> showPage(
    WidgetTester tester, ProviderContainer container, Widget page,
    {double width = 390, double scale = 1, double topInset = 0}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final frame = GlobalKey();
  if (page is ActivityDetailPage) {
    await tester.runAsync(
        () => container.read(activityByIdProvider(page.activityId).future));
  }
  await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: RepaintBoundary(
          key: frame,
          child: MaterialApp(
              key: UniqueKey(),
              theme: AppTheme.lightTheme,
              debugShowCheckedModeBanner: false,
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(scale),
                      padding: EdgeInsets.only(top: topInset)),
                  child: child!),
              home: page))));
  await tester.pumpAndSettle();
  expect(find.text(notice), findsNothing);
  expect(find.textContaining('Referência fixa:'), findsNothing);
  return frame;
}

void main() {
  setUp(() {
    final semantics =
        TestWidgetsFlutterBinding.ensureInitialized().ensureSemantics();
    addTearDown(semantics.dispose);
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

  testWidgets(
      'dashboard preserves synthetic values and accessible context without a banner',
      (tester) async {
    final (container, api) = await prepare(tester);
    final frame =
        await showPage(tester, container, const StudentDashboardPage());
    expect(find.text('8.2'), findsOneWidget);
    expect(find.text('8.3'), findsNothing);
    expect(demoContext, findsOneWidget);
    await captureLayout(tester, frame, 'synthetic-dashboard-390');
    await tester.scrollUntilVisible(find.text('Prazo próximo (24h)'), 200,
        scrollable: verticalScroll);
    final row = find
        .ancestor(
            of: find.text('Prazo próximo (24h)'), matching: find.byType(Row))
        .first;
    expect(find.descendant(of: row, matching: find.text('2')), findsOneWidget);
    await tester.scrollUntilVisible(
        find
            .text('Revisão de histórias e critérios de aceitação')
            .hitTestable(),
        180,
        scrollable: verticalScroll);
    expect(demoContext, findsOneWidget);
    expect(api.activityCalls + api.gradeCalls, 0);
    expect(container.read(currentUserProvider), same(syntheticStudent));
  });

  testWidgets(
      'all evaluations have discipline and period, with history outside current mean',
      (tester) async {
    final (container, _) = await prepare(tester);
    final frame = await showPage(tester, container, const GradesPage());
    expect(find.textContaining('Referência: AVL'), findsNWidgets(6));
    expect(find.text('8.2'), findsWidgets);
    expect(find.text('Histórico acadêmico demonstrativo'), findsOneWidget);
    expect(find.text('Disciplina/turma: Testes de Software'), findsOneWidget);
    expect(find.text('Período acadêmico: 2026.1'), findsOneWidget);
    expect(find.text('Período acadêmico: 2026.2'), findsNWidgets(5));
    expect(find.text('Nota da avaliação'), findsNWidgets(2));
    await tester.scrollUntilVisible(
        find.text('Histórico acadêmico demonstrativo').hitTestable(), 400,
        scrollable: verticalScroll);
    await captureLayout(tester, frame, 'synthetic-grades-history-390');
    expect(demoContext, findsOneWidget);
  });

  testWidgets(
      'search and priority survive details and Acre deadline is independent of device zone',
      (tester) async {
    final (container, api) = await prepare(tester);
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: const UniConnectApp()));
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(NavigationBar)));
    router.go('/atividades');
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextField).first, 'Revisão de histórias');
    tester
        .widget<SegmentedButton<ActivityPriority?>>(
            find.byType(SegmentedButton<ActivityPriority?>))
        .onSelectionChanged!({ActivityPriority.critical});
    await tester.pumpAndSettle();
    expect(find.text('Exibindo 1 de 10 atividade(s)'), findsOneWidget);
    await tester.scrollUntilVisible(
        find
            .text('Revisão de histórias e critérios de aceitação')
            .hitTestable(),
        200,
        scrollable: verticalScroll);
    await tester.runAsync(() => container
        .read(activityByIdProvider('demo-edukmais-activity-005').future));
    await tester
        .tap(find.text('Revisão de histórias e critérios de aceitação'));
    await tester.pumpAndSettle();
    expect(
        GoRouterState.of(tester.element(find.text('Detalhes da atividade')))
            .uri
            .path,
        '/atividades/demo-edukmais-activity-005');
    expect(find.textContaining('28/10/2026 • 22:00'), findsOneWidget);
    expect(find.textContaining('Horário do Acre'), findsOneWidget);
    expect(demoContext, findsOneWidget);
    await tester.tap(find.byTooltip('Retornar'));
    await tester.pumpAndSettle();
    expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'Revisão de histórias');
    expect(
        tester
            .widget<SegmentedButton<ActivityPriority?>>(
                find.byType(SegmentedButton<ActivityPriority?>))
            .selected,
        {ActivityPriority.critical});
    expect(api.activityCalls + api.gradeCalls, 0);
  });

  testWidgets('normal screens have no synthetic notice or academic data',
      (tester) async {
    final (container, api) = await prepare(tester, enabled: false);
    for (final page in [
      const StudentDashboardPage(),
      const ActivitiesPage(),
      const GradesPage(),
      const ActivityDetailPage(activityId: 'activity-1')
    ]) {
      await showPage(tester, container, page);
      expect(find.text(notice), findsNothing);
      expect(find.textContaining('AVL001'), findsNothing);
      expect(tester.takeException(), isNull);
    }
    expect(api.activityCalls, 1);
    expect(api.gradeCalls, 1);
  });

  testWidgets(
      'academic content respects safe area without space reserved for a banner',
      (tester) async {
    final (container, _) = await prepare(tester);
    await showPage(tester, container, const StudentDashboardPage(),
        topInset: 32);
    expect(tester.getRect(find.text('UniConnect • Área do aluno')).top,
        closeTo(48, .5));
    expect(tester.getSemantics(demoContext).label, demoExplanation);
  });

  testWidgets(
      'detail loading and errors retain accessible demonstration context',
      (tester) async {
    final pending = Completer<AcademicActivity?>();
    final (container, api) = await prepare(tester, detailResult: pending);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const ActivityDetailPage(activityId: 'test-pending'))));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(demoContext, findsOneWidget);
    pending.completeError(const FormatException('Test invalid asset'));
    await tester.pumpAndSettle();
    expect(demoContext, findsOneWidget);
    expect(find.text('Tentar Novamente'), findsOneWidget);
    expect(api.activityCalls + api.gradeCalls, 0);
  });

  testWidgets(
      'unknown synthetic activity retains accessible demonstration context',
      (tester) async {
    final (container, _) = await prepare(tester);
    await showPage(tester, container,
        const ActivityDetailPage(activityId: 'missing-synthetic-id'));
    expect(find.text('Atividade não encontrada'), findsOneWidget);
    expect(demoContext, findsOneWidget);
  });

  testWidgets(
      'retry reloads a failed synthetic source without falling back to API',
      (tester) async {
    final data = (await tester.runAsync(() async =>
        SyntheticAcademicData.fromJson(jsonDecode(
                await rootBundle.loadString(SyntheticAcademicData.assetPath))
            as Map<String, dynamic>)))!;
    var attempts = 0;
    final api = CountingAcademicApi();
    final container = ProviderContainer(retry: (_, __) => null, overrides: [
      syntheticDemoRequestedProvider.overrideWithValue(true),
      syntheticAcademicDataProvider.overrideWith((ref) async {
        attempts++;
        if (attempts == 1) throw const FormatException('Test failed load');
        return data;
      }),
      apiAuthServiceProvider.overrideWithValue(FakeAuthService(
          loginResult: const AuthSession(
              accessToken: 'test-token',
              refreshToken: 'test-refresh',
              expiresAt: null,
              user: syntheticStudent))),
      sessionStorageProvider.overrideWithValue(FakeSessionStorage()),
      academicApiServiceProvider.overrideWithValue(api),
    ]);
    addTearDown(container.dispose);
    await tester.runAsync(() async {
      await signIn(container, syntheticStudent);
      try {
        await container.read(activitiesProvider.future);
      } catch (_) {}
    });
    await showPage(tester, container, const ActivitiesPage());
    expect(demoContext, findsOneWidget);
    await tester.tap(find.text('Tentar Novamente'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Exibindo 10 de 10 atividade(s)'), findsOneWidget);
    expect(api.activityCalls + api.gradeCalls, 0);
  });

  for (final enabled in [false, true]) {
    testWidgets(
        'profile clearly identifies synthetic data only when enabled=$enabled',
        (tester) async {
      final (container, _) = await prepare(tester, enabled: enabled);
      final frame = await showPage(tester, container, const ProfilePage(),
          width: 320, scale: 2);
      if (enabled) {
        await tester.scrollUntilVisible(
            find.text('Ambiente de demonstração').hitTestable(), 150,
            scrollable: verticalScroll);
        expect(
            find.text(
                'Dados acadêmicos fictícios da EduKMais, usados para apresentação. Não representam registros reais da sua conta.'),
            findsOneWidget);
        expect(find.text('Referência fixa:'), findsNothing);
        await captureLayout(tester, frame, 'commercial-profile-320-text200');
      } else {
        expect(find.text('Ambiente de demonstração'), findsNothing);
        expect(find.textContaining('Dados acadêmicos fictícios'), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [320.0, 360.0, 390.0, 430.0, 768.0]) {
    testWidgets('synthetic pages remain usable at $width px and text 2x',
        (tester) async {
      final (container, _) = await prepare(tester);
      for (final (name, page) in [
        ('dashboard', const StudentDashboardPage()),
        ('activities', const ActivitiesPage()),
        (
          'detail',
          const ActivityDetailPage(activityId: 'demo-edukmais-activity-005')
        ),
        ('grades', const GradesPage()),
      ]) {
        final frame =
            await showPage(tester, container, page, width: width, scale: 2);
        expect(demoContext, findsOneWidget);
        expect(tester.takeException(), isNull, reason: '$name at $width');
        await tester.drag(verticalScroll, const Offset(0, -1600));
        await tester.pumpAndSettle();
        expect(demoContext, findsOneWidget);
        expect(tester.takeException(), isNull,
            reason: '$name scrolled at $width');
        if (width == 320 || width == 390 || width == 768) {
          await captureLayout(
              tester, frame, 'synthetic-$name-${width.toInt()}-text200');
        }
      }
    });
  }
}
