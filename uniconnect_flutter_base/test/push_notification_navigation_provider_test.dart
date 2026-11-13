import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:uniconnect/core/constants/app_routes.dart';
import 'package:uniconnect/core/notifications/push_auth_listener.dart';
import 'package:uniconnect/core/notifications/push_notification_navigation_provider.dart';
import 'package:uniconnect/core/router/app_router.dart';
import 'package:uniconnect/features/activities/providers/activity_provider.dart';
import 'package:uniconnect/features/auth/providers/auth_provider.dart';
import 'package:uniconnect/features/auth/services/session_storage.dart';

import 'fakes/fake_auth_service.dart';
import 'fakes/fake_session_storage.dart';
import 'push_notification_navigation_test.dart'
    show FakeOpenSource, activityId, event;

Future<void> drain() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeOpenSource source;
  late List<String> routes;
  late ProviderContainer container;

  ProviderContainer create({FakeSessionStorage? storage}) =>
      ProviderContainer(overrides: [
        apiAuthServiceProvider.overrideWithValue(FakeAuthService()),
        sessionStorageProvider
            .overrideWithValue(storage ?? FakeSessionStorage()),
        pushTokenSourceProvider.overrideWithValue(null),
        pushOpenSourceProvider.overrideWithValue(source),
        pushNavigationHandlerProvider.overrideWithValue(routes.add),
      ]);
  Future<void> login() => container
      .read(authControllerProvider.notifier)
      .login(email: 'synthetic', password: 'synthetic', rememberSession: false);

  setUp(() {
    source = FakeOpenSource();
    routes = [];
  });
  tearDown(() async {
    container.dispose();
    if (!source.initial.isCompleted) source.initial.complete(null);
    await source.events.close();
  });

  test('provider connects authenticated notification taps to the destination',
      () async {
    container = create();
    container.read(pushNotificationNavigationProvider);
    await container.read(authControllerProvider.notifier).restoreSession();
    await login();
    source.events.add(event());
    await drain();
    expect(routes, ['/atividades/$activityId']);
  });

  test(
      'provider waits for stored-session validation before opening initial notification',
      () async {
    final read = Completer<StoredAuthSession?>();
    container = create(storage: FakeSessionStorage(readCompleter: read));
    container.read(pushNotificationNavigationProvider);
    source.initial.complete(event());
    await drain();
    expect(routes, isEmpty);
    read.complete(const StoredAuthSession(
        accessToken: 'synthetic',
        refreshToken: 'synthetic-refresh',
        expiresAt: 4102444800,
        tenantSlug: 'instituicao-teste',
        userId: 'student-test'));
    await container.read(authControllerProvider.notifier).restoreSession();
    await drain();
    expect(routes, ['/atividades/$activityId']);
  });

  test('provider reuses one listener and reads the initial message only once',
      () async {
    container = create();
    final first = container.read(pushNotificationNavigationProvider);
    expect(container.read(pushNotificationNavigationProvider), same(first));
    expect(source.initialCalls, 1);
    expect(source.events.hasListener, isTrue);
    container.dispose();
    expect(source.events.hasListener, isFalse);
  });

  test('provider observes logout and discards a queued destination', () async {
    container = create();
    container.read(pushNotificationNavigationProvider);
    final auth = container.read(authControllerProvider.notifier);
    await auth.restoreSession();
    await login();
    source.events.add(event());
    await auth.logout();
    source.initial.complete(event(id: 'initial-late'));
    await login();
    await drain();
    expect(routes, isEmpty);
  });

  test('provider can be disabled without requiring Firebase initialization',
      () async {
    container = ProviderContainer(overrides: [
      apiAuthServiceProvider.overrideWithValue(FakeAuthService()),
      sessionStorageProvider.overrideWithValue(FakeSessionStorage()),
      pushTokenSourceProvider.overrideWithValue(null),
      pushOpenSourceProvider.overrideWithValue(null),
      pushNavigationHandlerProvider.overrideWithValue(routes.add),
    ]);
    container.read(pushNotificationNavigationProvider);
    await container.read(authControllerProvider.notifier).restoreSession();
    await login();
    await drain();
    expect(routes, isEmpty);
  });

  testWidgets(
      'real navigation handler opens GoRouter destination and refreshes cached authorization',
      (tester) async {
    var reads = 0;
    late final GoRouter router;
    router = GoRouter(
        initialLocation: AppRoutes.studentDashboard,
        redirect: (_, state) {
          final auth = container.read(authControllerProvider);
          return computeRedirect(
              isRestoring: auth.isRestoring,
              isAuthenticated: auth.isAuthenticated,
              userRole: auth.role,
              location: state.uri.path);
        },
        routes: [
          GoRoute(
              path: AppRoutes.studentDashboard,
              builder: (_, __) => const Text('home')),
          GoRoute(
              path: AppRoutes.activityDetails,
              builder: (_, state) =>
                  Text('activity-${state.pathParameters['id']}')),
        ]);
    addTearDown(router.dispose);
    container = ProviderContainer(overrides: [
      apiAuthServiceProvider.overrideWithValue(FakeAuthService()),
      sessionStorageProvider.overrideWithValue(FakeSessionStorage()),
      pushTokenSourceProvider.overrideWithValue(null),
      pushOpenSourceProvider.overrideWithValue(source),
      appRouterProvider.overrideWithValue(router),
      activityByIdProvider(activityId).overrideWith((ref) async {
        reads++;
        return null;
      }),
    ]);
    container.read(pushNotificationNavigationProvider);
    await container.read(authControllerProvider.notifier).restoreSession();
    await login();
    final cached =
        container.listen(activityByIdProvider(activityId), (_, __) {});
    addTearDown(cached.close);
    await container.read(activityByIdProvider(activityId).future);
    expect(reads, 1);
    await tester.pumpWidget(WidgetsApp.router(
        color: const Color(0xff000000), routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    source.events.add(event());
    await tester.pumpAndSettle();
    expect(find.text('activity-$activityId'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path,
        '/atividades/$activityId');
    expect(reads, 2);
    await tester.pumpWidget(const SizedBox());
  });
}
