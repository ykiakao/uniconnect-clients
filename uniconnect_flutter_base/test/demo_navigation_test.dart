import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:uniconnect/core/constants/app_routes.dart';
import 'package:uniconnect/core/network/api_client.dart';
import 'package:uniconnect/core/router/app_router.dart';
import 'package:uniconnect/features/activities/providers/activity_provider.dart';
import 'package:uniconnect/features/auth/models/app_user.dart';
import 'package:uniconnect/features/auth/providers/auth_provider.dart';
import 'package:uniconnect/features/auth/services/api_auth_service.dart';
import 'package:uniconnect/features/auth/services/session_storage.dart';
import 'package:uniconnect/features/grades/providers/grades_provider.dart';
import 'package:uniconnect/features/grades/providers/student_report_card_provider.dart';
import 'package:uniconnect/features/teacher/providers/teacher_activity_provider.dart';
import 'package:uniconnect/features/teacher/services/teacher_activity_service.dart';
import 'package:uniconnect/main.dart';

import 'demo_day_test.dart' show demoActivity;
import 'fakes/fake_auth_service.dart';
import 'fakes/fake_session_storage.dart';

void main() {
  testWidgets('restoration and login resume the last recognized protected link',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final pendingStorage = Completer<StoredAuthSession?>();
    final pendingLogin = Completer<AuthSession>();
    final container = ProviderContainer(overrides: [
      sessionStorageProvider.overrideWithValue(
        FakeSessionStorage(readCompleter: pendingStorage),
      ),
      apiAuthServiceProvider.overrideWithValue(
        FakeAuthService(loginCompleter: pendingLogin),
      ),
      activitiesProvider.overrideWith((ref) async => [demoActivity]),
      activityByIdProvider.overrideWith((ref, id) async => demoActivity),
      subjectGradesProvider.overrideWith((ref) async => []),
    ]);
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const UniConnectApp(),
    ));

    router.go(AppRoutes.grades);
    await tester.pump();
    expect(
        router.routeInformationProvider.value.uri.path, AppRoutes.authLoading);
    expect(find.text('Quadro de notas'), findsNothing);

    pendingStorage.complete();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.login);
    await tester.enterText(find.byType(TextField).first, fakeStudent.email);
    await tester.enterText(find.byType(TextField).last, 'test-password');
    final loginButton = find.widgetWithText(ElevatedButton, 'Entrar');
    await tester.ensureVisible(loginButton);
    await tester.pumpAndSettle();
    await tester.tap(loginButton);
    await tester.pump();

    router.go('/atividades/activity-1');
    await tester.pump();
    router.go('/desconhecida');
    await tester.pump();
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.login);
    pendingLogin.complete(const AuthSession(
      accessToken: 'token',
      refreshToken: 'refresh',
      expiresAt: null,
      user: fakeStudent,
    ));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path,
        '/atividades/activity-1');
    expect(find.text('Detalhes da atividade'), findsOneWidget);
    router.go(AppRoutes.login);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path,
        AppRoutes.studentDashboard);
  });

  testWidgets('renewal failure hides protected content and retries the route',
      (tester) async {
    final storage = FakeSessionStorage();
    await storage.save(const AuthSession(
      accessToken: 'token',
      refreshToken: 'refresh',
      expiresAt: null,
      user: fakeStudent,
    ));
    final service = _RetryableRenewal();
    final container = ProviderContainer(overrides: [
      sessionStorageProvider.overrideWithValue(storage),
      apiAuthServiceProvider.overrideWithValue(service),
      activitiesProvider.overrideWith((ref) async => [demoActivity]),
      subjectGradesProvider.overrideWith((ref) async => []),
    ]);
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const UniConnectApp(),
    ));
    await tester.pumpAndSettle();
    router.go(AppRoutes.academic);
    await tester.pumpAndSettle();

    final auth = container.read(authControllerProvider.notifier);
    final refresh = auth.refreshAccessToken('token', fakeStudent.tenant.slug);
    await tester.pump();
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.academic);
    expect(find.text('Horários e calendário acadêmico ainda indisponíveis.'),
        findsNothing);
    service.first.completeError(const ApiException('offline', statusCode: 503));
    await refresh;
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível renovar a sessão.'), findsOneWidget);
    expect(find.text('Horários e calendário acadêmico ainda indisponíveis.'),
        findsNothing);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.academic);

    final stale =
        auth.refreshAccessToken('rotated-access', fakeStudent.tenant.slug);
    final logout = auth.logout();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.login);
    service.lateRenewal.complete(const AuthSession(
      accessToken: 'late-access',
      refreshToken: 'late-refresh',
      expiresAt: null,
      user: fakeStudent,
    ));
    await stale;
    await logout;
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.login);

    await auth.login(
        email: fakeStudent.email,
        password: 'test-password',
        rememberSession: false);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path,
        AppRoutes.studentDashboard);
  });

  for (final user in [fakeStudent, fakeTeacher]) {
    testWidgets('logout from ${user.role.name} closes dialog before redirect',
        (tester) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = AuthSession(
        accessToken: 'test-token',
        refreshToken: 'test-refresh',
        expiresAt: null,
        user: user,
      );
      final storage = FakeSessionStorage();
      await storage.save(session);
      final revocation = Completer<void>();
      final service = FakeAuthService(
        meResult: user,
        logoutCompleter: revocation,
      );
      await tester.pumpWidget(ProviderScope(
        overrides: [
          apiAuthServiceProvider.overrideWithValue(service),
          sessionStorageProvider.overrideWithValue(storage),
          activitiesProvider.overrideWith((ref) async => [demoActivity]),
          subjectGradesProvider.overrideWith((ref) async => []),
        ],
        child: const UniConnectApp(),
      ));
      await tester.pumpAndSettle();
      final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
      final isTeacher = user.role == UserRole.teacher;
      final protectedPath =
          isTeacher ? AppRoutes.teacherDashboard : AppRoutes.profile;
      final logoutButton = isTeacher
          ? find.byTooltip('Sair')
          : find.widgetWithText(ElevatedButton, 'Sair');
      if (!isTeacher) {
        router.go(protectedPath);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(logoutButton, 250,
            scrollable: find
                .byWidgetPredicate((widget) =>
                    widget is Scrollable &&
                    widget.axisDirection == AxisDirection.down)
                .first);
      }
      await tester.tap(logoutButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, protectedPath);
      expect(service.logoutCalls, isEmpty);
      expect((await storage.read())?.userId, user.id);

      await tester.tap(logoutButton);
      await tester.pumpAndSettle();
      final dialog = find.byType(AlertDialog);
      final dialogRoute = ModalRoute.of(tester.element(dialog))!;
      await tester.tap(find.descendant(
          of: dialog, matching: find.widgetWithText(ElevatedButton, 'Sair')));
      expect(dialogRoute.isCurrent, isFalse);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(router.routeInformationProvider.value.uri.path, AppRoutes.login);
      expect(service.logoutCalls, [(session.accessToken, user.tenant.slug)]);
      expect(revocation.isCompleted, isFalse);
      expect(await storage.read(), isNull);

      await router.routeInformationProvider.didPushRouteInformation(
        RouteInformation(uri: Uri.parse(protectedPath)),
      );
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, AppRoutes.login);
      expect(find.text('Entrar'), findsOneWidget);

      revocation.complete();
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, AppRoutes.login);
      expect(service.logoutCalls, hasLength(1));
      expect(tester.takeException(), isNull);
    });
  }

  for (final user in [fakeStudent, fakeTeacher]) {
    testWidgets('login and complete navigation for ${user.role.name}',
        (tester) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final storage = FakeSessionStorage();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          apiAuthServiceProvider.overrideWithValue(FakeAuthService(
            loginResult: AuthSession(
              accessToken: 'test-token',
              refreshToken: 'test-refresh',
              expiresAt: null,
              user: user,
            ),
          )),
          sessionStorageProvider.overrideWithValue(storage),
          activitiesProvider.overrideWith((ref) async => [demoActivity]),
          activityByIdProvider.overrideWith((ref, id) async => demoActivity),
          studentReportOfferingsProvider
              .overrideWith((ref, session) async => []),
          teacherOfferingsProvider.overrideWith((ref) async => const [
                TeacherOffering(id: 'class-1', name: 'Oferta docente'),
              ]),
          teacherActivitiesProvider.overrideWith((ref, classId) async => []),
          teacherActivityPreviewProvider.overrideWith(
              (ref, classId) async => (rows: <TeacherActivity>[], total: 0)),
          subjectGradesProvider.overrideWith((ref) async => []),
        ],
        child: const UniConnectApp(),
      ));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, user.email);
      await tester.enterText(find.byType(TextField).last, 'test-password');
      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Entrar'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Entrar'));
      await tester.pumpAndSettle();
      final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
      String currentLocation() =>
          GoRouterState.of(tester.element(find.byType(Scaffold).first))
              .uri
              .path;

      if (user.role == UserRole.student) {
        expect(currentLocation(), AppRoutes.studentDashboard);
        expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .destinations
              .cast<NavigationDestination>()
              .map((tab) => tab.label),
          ['Início', 'Atividades', 'Chat', 'Notas', 'Acadêmico'],
        );
        await tester.tap(find.text('Acadêmico'));
        await tester.pumpAndSettle();
        expect(currentLocation(), AppRoutes.academic);
        expect(find.byTooltip('Meu perfil'), findsOneWidget);
        await tester.tap(find.text('Início').last);
        await tester.pumpAndSettle();
        for (final (label, destination) in [
          ('Ver notas', AppRoutes.grades),
          ('Ver avisos', AppRoutes.notices),
          ('Ver acadêmico', AppRoutes.academic),
        ]) {
          await tester.scrollUntilVisible(find.text(label).hitTestable(), 160,
              scrollable: find.byType(Scrollable).first);
          await tester.tap(find.text(label));
          await tester.pumpAndSettle();
          expect(currentLocation(), destination);
          router.go(AppRoutes.studentDashboard);
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('Ver atividades'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('Pesquisa aplicada'), 200,
            scrollable: find
                .byWidgetPredicate((w) =>
                    w is Scrollable && w.axisDirection == AxisDirection.down)
                .first);
        await tester.tap(find.text('Pesquisa aplicada'));
        await tester.pumpAndSettle();
        expect(
            GoRouterState.of(tester.element(find.byType(Scaffold).first))
                .uri
                .path,
            '/atividades/activity-1');
        expect(find.text('Detalhes da atividade'), findsOneWidget);
        await tester.tap(find.text('Notas'));
        await tester.pumpAndSettle();
        expect(currentLocation(), AppRoutes.grades);
        expect(find.text('Nenhuma disciplina disponível'), findsOneWidget);
        await tester.tap(find.text('Chat'));
        await tester.pumpAndSettle();
        expect(currentLocation(), AppRoutes.chat);
        expect(find.byTooltip('Meu perfil'), findsOneWidget);
        await tester.tap(find.text('Notas'));
        await tester.pumpAndSettle();
        expect(currentLocation(), AppRoutes.grades);
        await tester.tap(find.byTooltip('Meu perfil'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Retornar'));
        await tester.pumpAndSettle();
        expect(currentLocation(), AppRoutes.grades);
        await tester.tap(find.byTooltip('Meu perfil'));
        await tester.pumpAndSettle();
      } else {
        expect(currentLocation(), AppRoutes.teacherDashboard);
        router.go('/atividades/activity-1');
        await tester.pumpAndSettle();
        expect(currentLocation(), AppRoutes.teacherDashboard);
        final teacherBar = find.byType(NavigationBar);
        expect(
          tester
              .widget<NavigationBar>(teacherBar)
              .destinations
              .cast<NavigationDestination>()
              .map((tab) => tab.label),
          ['Início', 'Atividades', 'Chat', 'Notas'],
        );
        await tester
            .tap(find.descendant(of: teacherBar, matching: find.text('Chat')));
        await tester.pumpAndSettle();
        expect(currentLocation(), AppRoutes.teacherChat);
        expect(find.byTooltip('Meu perfil'), findsOneWidget);
        await tester.tap(
            find.descendant(of: teacherBar, matching: find.text('Atividades')));
        await tester.pumpAndSettle();
        expect(currentLocation(), AppRoutes.teacherActivities);
        await tester.tap(find.widgetWithText(FilledButton, 'Criar atividade'));
        await tester.pumpAndSettle();
        expect(currentLocation(), AppRoutes.teacherCreateActivity);
        await tester.tap(find.byTooltip('Retornar'));
        await tester.pumpAndSettle();
        expect(currentLocation(), AppRoutes.teacherActivities);
        await tester.tap(
            find.descendant(of: teacherBar, matching: find.text('Início')));
        await tester.pumpAndSettle();
        expect(currentLocation(), AppRoutes.teacherDashboard);
        Future<void> openShortcut(String label) async {
          // Shortcuts sit near the top: start there, then scroll down.
          await tester.drag(
              find.byType(Scrollable).first, const Offset(0, 2000));
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(find.text(label).hitTestable(), 160,
              scrollable: find.byType(Scrollable).first);
          await tester.tap(find.text(label));
          await tester.pumpAndSettle();
        }

        await openShortcut('Criar atividade');
        expect(currentLocation(), AppRoutes.teacherCreateActivity);
        await tester.tap(find.byTooltip('Retornar'));
        await tester.pumpAndSettle();
        expect(currentLocation(), AppRoutes.teacherDashboard);
        await openShortcut('Lançar notas');
        expect(currentLocation(), AppRoutes.teacherGrades);
        await tester.tap(
            find.descendant(of: teacherBar, matching: find.text('Início')));
        await tester.pumpAndSettle();
        expect(currentLocation(), AppRoutes.teacherDashboard);
        for (final (label, destination) in [
          ('Avisos da turma', AppRoutes.notices),
          ('Ver entregas', AppRoutes.teacherActivities),
        ]) {
          await openShortcut(label);
          expect(currentLocation(), destination);
          router.go(AppRoutes.teacherDashboard);
          await tester.pumpAndSettle();
        }
        await tester.tap(find.byTooltip('Meu perfil'));
        await tester.pumpAndSettle();
        expect(find.byType(NavigationBar), findsNothing);
        await tester.tap(find.byTooltip('Retornar'));
        await tester.pumpAndSettle();
        expect(currentLocation(), AppRoutes.teacherDashboard);
        await tester.tap(find.byTooltip('Meu perfil'));
        await tester.pumpAndSettle();
      }

      await tester.scrollUntilVisible(
          find.widgetWithText(ElevatedButton, 'Sair'), 250,
          scrollable: find
              .byWidgetPredicate((w) =>
                  w is Scrollable && w.axisDirection == AxisDirection.down)
              .first);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sair'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(currentLocation(), AppRoutes.profile);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sair'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sair').last);
      await tester.pumpAndSettle();
      expect(currentLocation(), AppRoutes.login);
      expect(find.text('Entrar'), findsOneWidget);
      expect(await storage.read(), isNull);
      expect(tester.takeException(), isNull);
    });
  }
}

class _RetryableRenewal extends FakeAuthService {
  final first = Completer<AuthSession>();
  final lateRenewal = Completer<AuthSession>();
  int attempts = 0;

  @override
  Future<AuthSession> refresh(String refreshToken,
      {required String tenantSlug}) {
    if (++attempts == 1) return first.future;
    if (attempts == 3) return lateRenewal.future;
    return super.refresh(refreshToken, tenantSlug: tenantSlug);
  }
}
