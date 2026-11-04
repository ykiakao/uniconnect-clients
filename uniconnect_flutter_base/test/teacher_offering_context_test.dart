import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uniconnect/core/constants/app_routes.dart';
import 'package:uniconnect/core/network/api_client.dart';
import 'package:uniconnect/core/router/app_router.dart';
import 'package:uniconnect/features/auth/models/app_user.dart';
import 'package:uniconnect/features/auth/providers/auth_provider.dart';
import 'package:uniconnect/features/auth/services/api_auth_service.dart';
import 'package:uniconnect/features/teacher/providers/teacher_activity_provider.dart';
import 'package:uniconnect/features/teacher/providers/teacher_offering_selection.dart';
import 'package:uniconnect/features/tenant/models/tenant_context.dart';
import 'package:uniconnect/main.dart';

import 'fakes/fake_auth_service.dart';
import 'fakes/fake_session_storage.dart';
import 'teacher_activity_service_test.dart'
    show activityRow, jsonResponse, page;
import 'teacher_review_service_test.dart' show reviewedSubmission;

const offeringA = {'id': 'a', 'name': 'Turma A', 'status': 'active'};
const offeringB = {'id': 'b', 'name': 'Turma B', 'status': 'active'};

AuthSession session(AppUser user) => AuthSession(
      accessToken: 'token-${user.id}-${user.tenant.slug}',
      refreshToken: 'refresh',
      expiresAt: null,
      user: user,
    );

class _SwitchingAuth extends FakeAuthService {
  _SwitchingAuth() : super(meResult: fakeTeacher);
  AppUser nextUser = fakeTeacher;

  @override
  Future<AuthSession> login(
          {required String email, required String password}) async =>
      session(nextUser);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<ProviderContainer> openApp(
    WidgetTester tester, {
    required Future<http.Response> Function(http.Request) reply,
    bool authenticated = true,
    String? location,
    _SwitchingAuth? auth,
  }) async {
    tester.view.physicalSize = const Size(450, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final storage = FakeSessionStorage();
    if (authenticated) await storage.save(session(fakeTeacher));
    final container = ProviderContainer(overrides: [
      sessionStorageProvider.overrideWithValue(storage),
      apiAuthServiceProvider.overrideWithValue(auth ?? _SwitchingAuth()),
      apiClientProvider.overrideWithValue(ApiClient(
        baseUrl: 'https://fixture.invalid/api/v1',
        httpClient: MockClient(reply),
      )),
    ]);
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);
    if (location != null) router.go(location);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const UniConnectApp(),
    ));
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> choose(WidgetTester tester, String name,
      {bool settle = true}) async {
    final picker = find.byType(DropdownButtonFormField<String>).first;
    await tester.ensureVisible(picker);
    await tester.tap(picker);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text(name).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    if (settle) await tester.pumpAndSettle();
  }

  String? selected(ProviderContainer container) =>
      container.read(selectedTeacherClassIdProvider);

  testWidgets('one authorized offering is selected, zero disables selection',
      (tester) async {
    var rows = [offeringA];
    final container = await openApp(tester,
        location: AppRoutes.teacherActivities,
        reply: (request) async => jsonResponse(page(rows)));
    expect(selected(container), 'a');
    rows = [offeringB];
    container.invalidate(teacherOfferingsProvider);
    await tester.pumpAndSettle();
    expect(selected(container), isNull);
    expect(find.text('A oferta selecionada não está mais disponível.'),
        findsOneWidget);
    expect(find.text('Turma B'), findsNothing);
    rows = [];
    container.invalidate(teacherOfferingsProvider);
    await tester.pumpAndSettle();
    final dropdown = tester
        .widget<DropdownButton<String>>(find.byType(DropdownButton<String>));
    expect(dropdown.onChanged, isNull);
  });

  testWidgets(
      'selection is shared across home, activities, grades and legacy creation',
      (tester) async {
    final container = await openApp(tester,
        reply: (request) async => jsonResponse(page(
            request.url.path.endsWith('/offerings')
                ? [offeringA, offeringB]
                : [])));
    final router = container.read(appRouterProvider);
    expect(selected(container), isNull);
    await choose(tester, 'Turma B');
    expect(selected(container), 'b');
    router.go(AppRoutes.teacherActivities);
    await tester.pumpAndSettle();
    expect(find.text('Turma B'), findsOneWidget);
    await choose(tester, 'Turma A');
    router.go(AppRoutes.teacherGrades);
    await tester.pumpAndSettle();
    expect(find.text('Turma A'), findsOneWidget);
    expect(selected(container), 'a');
    router.go(AppRoutes.teacherCreateActivity);
    await tester.pumpAndSettle();
    expect(find.text('Criar atividade'), findsOneWidget);
    expect(find.text('Turma A'), findsOneWidget);
  });

  testWidgets(
      'authorized classId resumes after login and invalid links cannot change it',
      (tester) async {
    final container = await openApp(tester,
        location: '${AppRoutes.teacherGrades}?classId=b',
        authenticated: false,
        reply: (request) async => jsonResponse(page([offeringA, offeringB])));
    final router = container.read(appRouterProvider);
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.login);
    final auth = container.read(authControllerProvider.notifier);
    await auth.login(
        email: fakeTeacher.email,
        password: 'test-only',
        rememberSession: false);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path,
        AppRoutes.teacherGrades);
    expect(selected(container), 'b');

    router.go('${AppRoutes.teacherActivities}?classId=a');
    await tester.pumpAndSettle();
    expect(selected(container), 'a');

    for (final query in ['classId=forbidden', 'classId=a&classId=b']) {
      router.go('${AppRoutes.teacherActivities}?$query');
      await tester.pumpAndSettle();
      expect(selected(container), 'a');
      expect(
          find.text('A oferta deste link não está disponível para sua conta.'),
          findsOneWidget);
      expect(find.text('Criar atividade'), findsNothing);
      await tester.tap(find.text('Continuar sem usar a oferta do link'));
      await tester.pumpAndSettle();
      expect(find.text('Turma A'), findsOneWidget);
    }
  });

  testWidgets('legacy draft stays with its offering when a change is canceled',
      (tester) async {
    final container = await openApp(tester,
        location: '${AppRoutes.teacherCreateActivity}?classId=a',
        reply: (request) async => jsonResponse(page(
            request.url.path.endsWith('/offerings')
                ? [offeringA, offeringB]
                : [])));
    final title = find.byType(TextFormField).first;
    await tester.enterText(title, 'Rascunho da turma A');
    await choose(tester, 'Turma B');
    expect(find.text('Descartar alterações não salvas?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(selected(container), 'a');
    expect(tester.widget<TextFormField>(title).controller!.text,
        'Rascunho da turma A');

    final router = container.read(appRouterProvider);
    router.go('${AppRoutes.teacherGrades}?classId=b');
    await tester.pumpAndSettle();
    expect(find.text('Descartar alterações não salvas?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(router.routerDelegate.currentConfiguration.uri.path,
        AppRoutes.teacherCreateActivity);
    expect(selected(container), 'a');
    expect(tester.widget<TextFormField>(title).controller!.text,
        'Rascunho da turma A');

    router.go('${AppRoutes.teacherCreateActivity}?classId=b');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Descartar alterações não salvas?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(selected(container), 'a');
    await tester.tap(find.text('Continuar sem usar a oferta do link'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(title).controller!.text,
        'Rascunho da turma A');

    await choose(tester, 'Turma B');
    await tester.tap(find.text('Descartar alterações'));
    await tester.pumpAndSettle();
    expect(selected(container), 'b');
    expect(tester.widget<TextFormField>(title).controller!.text, isEmpty);
  });

  testWidgets('an offer deep link respects the dirty review before leaving work',
      (tester) async {
    final container = await openApp(tester,
        location: '${AppRoutes.teacherActivities}?classId=a',
        reply: (request) async {
          final path = request.url.path;
          if (path.endsWith('/offerings')) {
            return jsonResponse(page([offeringA, offeringB]));
          }
          if (path.endsWith('/classes/a/activities')) {
            return jsonResponse(page([
              {...activityRow(state: 'published'), 'classId': 'a'},
            ]));
          }
          if (path.endsWith('/enrollments')) return jsonResponse(page([]));
          if (path.endsWith('/submissions')) {
            return jsonResponse(page([reviewedSubmission()]));
          }
          return jsonResponse(reviewedSubmission());
        });
    await tester.tap(find.text('Ver entregas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abrir entrega'));
    await tester.pumpAndSettle();
    final feedback = find.byType(TextFormField).last;
    await tester.enterText(feedback, 'Devolutiva da turma A');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();

    final router = container.read(appRouterProvider);
    router.go('${AppRoutes.teacherGrades}?classId=b');
    await tester.pumpAndSettle();
    expect(find.text('Descartar alterações da correção?'), findsOneWidget);
    await tester.tap(find.text('Continuar corrigindo'));
    await tester.pumpAndSettle();
    expect(selected(container), 'a');
    expect(tester.widget<TextFormField>(feedback).controller!.text,
        'Devolutiva da turma A');

    router.go('${AppRoutes.teacherGrades}?classId=b');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar alterações'));
    await tester.pumpAndSettle();
    expect(selected(container), 'b');
    expect(find.text('Devolutiva da turma A'), findsNothing);
    expect(find.text('Consultar boletim'), findsOneWidget);
  });

  testWidgets(
      'late HTTP response cannot overwrite the current offer after A to B to A',
      (tester) async {
    final lateA = Completer<http.Response>();
    var readsA = 0;
    final container = await openApp(tester,
        location: AppRoutes.teacherCreateActivity, reply: (request) async {
      final path = request.url.path;
      if (path.endsWith('/offerings')) {
        return jsonResponse(page([offeringA, offeringB]));
      }
      if (path.endsWith('/classes/a/activities')) {
        if (++readsA == 1) return lateA.future;
        return jsonResponse(page([
          {...activityRow(), 'classId': 'a', 'title': 'A atual'}
        ]));
      }
      return jsonResponse(page([
        {...activityRow(), 'classId': 'b', 'title': 'B atual'}
      ]));
    });
    await choose(tester, 'Turma A', settle: false);
    expect(readsA, 1);
    await choose(tester, 'Turma B');
    expect(selected(container), 'b');
    await tester.scrollUntilVisible(find.text('B atual'), 250,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('B atual'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, 1200));
    await tester.pumpAndSettle();
    await choose(tester, 'Turma A');
    await tester.scrollUntilVisible(find.text('A atual'), 250,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('A atual'), findsOneWidget);
    lateA.complete(jsonResponse(page([
      {...activityRow(), 'classId': 'a', 'title': 'A antiga'}
    ])));
    await tester.pumpAndSettle();
    expect(find.text('A atual'), findsOneWidget);
    expect(find.text('A antiga'), findsNothing);
    expect(find.text('B atual'), findsNothing);
  });

  testWidgets('a failed offer lookup can be retried before applying a link',
      (tester) async {
    var attempts = 0;
    final container = await openApp(tester,
        location: '${AppRoutes.teacherActivities}?classId=b',
        reply: (request) async {
      if (++attempts == 1) {
        return jsonResponse({
          'error': {'message': 'Sem conexão'}
        }, 503);
      }
      return jsonResponse(page([offeringA, offeringB]));
    });
    expect(selected(container), isNull);
    expect(find.text('Não foi possível validar a oferta do link.'),
        findsOneWidget);
    expect(find.text('Criar atividade'), findsNothing);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(selected(container), 'b');
    expect(find.text('Turma B'), findsOneWidget);
  });

  testWidgets('logout isolates an equal classId across users and tenants',
      (tester) async {
    const otherTenant = TenantContext(
      id: 'other',
      name: 'Outra instituição',
      slug: 'outra',
      plan: SubscriptionPlan.growth,
      status: SubscriptionStatus.trialing,
      activeUsers: 1,
    );
    const otherUser = AppUser(
        id: 'another',
        name: 'Outra pessoa',
        email: 'another@example.invalid',
        role: UserRole.teacher,
        tenant: otherTenant);
    final service = _SwitchingAuth();
    final container = await openApp(tester,
        auth: service,
        location: AppRoutes.teacherActivities, reply: (request) async {
      final other = request.url.path.contains('/tenants/outra/');
      expect(
          request.headers['x-tenant-slug'], other ? 'outra' : fakeTenant.slug);
      return jsonResponse(page(other
          ? [
              {...offeringA, 'name': 'A da outra instituição'},
              offeringB
            ]
          : [offeringA, offeringB]));
    });
    await choose(tester, 'Turma A');
    expect(selected(container), 'a');
    final auth = container.read(authControllerProvider.notifier);
    await auth.logout();
    await tester.pumpAndSettle();
    expect(selected(container), isNull);
    service.nextUser = otherUser;
    await auth.login(
        email: otherUser.email, password: 'test-only', rememberSession: false);
    await tester.pumpAndSettle();
    expect(selected(container), isNull);
    expect(find.text('Turma A'), findsNothing);
    await choose(tester, 'A da outra instituição');
    expect(selected(container), 'a');
  });
}
