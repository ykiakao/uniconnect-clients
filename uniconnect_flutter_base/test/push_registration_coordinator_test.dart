import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uniconnect/core/network/api_client.dart';
import 'package:uniconnect/core/notifications/push_auth_listener.dart';
import 'package:uniconnect/core/notifications/push_device_registration.dart';
import 'package:uniconnect/core/notifications/push_registration_coordinator.dart';
import 'package:uniconnect/features/auth/providers/auth_provider.dart';
import 'package:uniconnect/features/auth/services/api_auth_service.dart';

import 'fakes/fake_auth_service.dart';
import 'fakes/fake_session_storage.dart';

const student = PushSession(
  userId: 'student',
  tenantId: 'tenant-a',
  tenantSlug: 'institution-a',
  accessToken: 'student-access',
);
const teacher = PushSession(
  userId: 'teacher',
  tenantId: 'tenant-a',
  tenantSlug: 'institution-a',
  accessToken: 'teacher-access',
);
const otherTenant = PushSession(
  userId: 'student',
  tenantId: 'tenant-b',
  tenantSlug: 'institution-b',
  accessToken: 'other-access',
);

class FakeTokens implements PushTokenSource {
  final events = StreamController<String>.broadcast(sync: true);
  String? token = 'device-a';
  Object? lookupError;
  Object? subscriptionError;
  Completer<String?>? lookup;
  int reads = 0;
  int subscriptions = 0;

  @override
  Future<String?> getToken() async {
    reads++;
    if (lookupError != null) throw lookupError!;
    return lookup == null ? token : lookup!.future;
  }

  @override
  Stream<String> get onTokenRefresh {
    subscriptions++;
    if (subscriptionError != null) throw subscriptionError!;
    return events.stream;
  }
}

class FakeRegistration extends PushDeviceRegistration {
  FakeRegistration() : super(ApiClient());

  final calls = <String>[];
  Completer<void>? registering;
  Completer<void>? unregistering;
  bool failRegister = false;
  bool failUnregister = false;

  @override
  Future<void> register({
    required String accessToken,
    required String tenantSlug,
    required String token,
  }) async {
    calls.add('POST $accessToken $tenantSlug $token');
    await registering?.future;
    if (failRegister) throw StateError('synthetic registration failure');
    calls.add('POST done');
  }

  @override
  Future<void> unregister({
    required String accessToken,
    required String tenantSlug,
    required String token,
  }) async {
    calls.add('DELETE $accessToken $tenantSlug $token');
    await unregistering?.future;
    if (failUnregister) throw StateError('synthetic unlink failure');
    calls.add('DELETE done');
  }
}

Future<void> drain() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeTokens tokens;
  late FakeRegistration registration;
  late PushRegistrationCoordinator coordinator;

  setUp(() {
    tokens = FakeTokens();
    registration = FakeRegistration();
    coordinator = PushRegistrationCoordinator(registration, tokens);
  });

  tearDown(() async {
    coordinator.dispose();
    await tokens.events.close();
  });

  test('registers exact FCM token with authenticated owner', () async {
    await coordinator.setSession(student);
    expect(registration.calls,
        ['POST student-access institution-a device-a', 'POST done']);
  });

  test('deduplicates session events and access-token renewals', () async {
    await coordinator.setSession(student);
    await coordinator.setSession(student.withAccessToken('renewed-access'));
    tokens.events.add('device-a');
    await drain();
    expect(tokens.reads, 1);
    expect(registration.calls.where((call) => call.startsWith('POST ')),
        hasLength(2)); // one request and its completion
    await coordinator.beforeRemoteLogout('renewed-access', 'institution-a');
    expect(
        registration.calls[2], 'DELETE renewed-access institution-a device-a');
  });

  test('refresh unlinks old token before registering replacement once',
      () async {
    await coordinator.setSession(student);
    tokens.events.add('device-b');
    tokens.events.add('device-b');
    await drain();
    expect(registration.calls, [
      'POST student-access institution-a device-a',
      'POST done',
      'DELETE student-access institution-a device-a',
      'DELETE done',
      'POST student-access institution-a device-b',
      'POST done',
    ]);
  });

  test('refresh wins over older getToken result', () async {
    tokens.lookup = Completer<String?>();
    final login = coordinator.setSession(student);
    tokens.events.add('device-new');
    await drain();
    tokens.lookup!.complete('device-old');
    await login;
    expect(registration.calls,
        ['POST student-access institution-a device-new', 'POST done']);
  });

  test('multiple refreshes serialize against an in-flight registration',
      () async {
    registration.registering = Completer<void>();
    final login = coordinator.setSession(student);
    await drain();
    tokens.events.add('device-b');
    tokens.events.add('device-c');
    await drain();
    expect(registration.calls, ['POST student-access institution-a device-a']);
    registration.registering!.complete();
    await login;
    await drain();
    expect(registration.calls, [
      'POST student-access institution-a device-a',
      'POST done',
      'DELETE student-access institution-a device-a',
      'DELETE done',
      'POST student-access institution-a device-c',
      'POST done',
    ]);
  });

  test('new owner waits for old POST and DELETE to finish', () async {
    registration.registering = Completer<void>();
    final first = coordinator.setSession(student);
    await drain();
    registration.unregistering = Completer<void>();
    final second = coordinator.setSession(otherTenant);
    registration.registering!.complete();
    await drain();
    expect(registration.calls, [
      'POST student-access institution-a device-a',
      'POST done',
      'DELETE student-access institution-a device-a',
    ]);
    registration.unregistering!.complete();
    await Future.wait([first, second]);
    expect(registration.calls, [
      'POST student-access institution-a device-a',
      'POST done',
      'DELETE student-access institution-a device-a',
      'DELETE done',
      'POST other-access institution-b device-a',
      'POST done',
    ]);
  });

  test('logout waits for pending POST before DELETE and never re-registers',
      () async {
    registration.registering = Completer<void>();
    final login = coordinator.setSession(student);
    await drain();
    final logout =
        coordinator.beforeRemoteLogout('student-access', 'institution-a');
    tokens.events.add('device-after-logout');
    await drain();
    expect(registration.calls, ['POST student-access institution-a device-a']);
    registration.registering!.complete();
    await Future.wait([login, logout]);
    expect(registration.calls, [
      'POST student-access institution-a device-a',
      'POST done',
      'DELETE student-access institution-a device-a',
      'DELETE done',
    ]);
  });

  test('hung Firebase lookup does not delay logout or register afterwards',
      () async {
    tokens.lookup = Completer<String?>();
    final login = coordinator.setSession(student);
    await coordinator.beforeRemoteLogout('student-access', 'institution-a');
    tokens.lookup!.complete('device-late');
    await login;
    expect(registration.calls, isEmpty);
  });

  test('user switch cannot apply stale token lookup from previous user',
      () async {
    final firstLookup = tokens.lookup = Completer<String?>();
    final first = coordinator.setSession(student);
    tokens.lookup = Completer<String?>();
    final second = coordinator.setSession(teacher);
    tokens.lookup!.complete('device-new');
    await second;
    firstLookup.complete('device-stale');
    await first;
    expect(registration.calls,
        ['POST teacher-access institution-a device-new', 'POST done']);
  });

  for (final next in [
    teacher,
    otherTenant,
    const PushSession(
        userId: 'student',
        tenantId: 'different-id',
        tenantSlug: 'institution-a',
        accessToken: 'other-id-access')
  ]) {
    test(
        'switch to ${next.userId}/${next.tenantId} removes previous owner first',
        () async {
      await coordinator.setSession(student);
      await coordinator.setSession(next);
      expect(registration.calls, [
        'POST student-access institution-a device-a',
        'POST done',
        'DELETE student-access institution-a device-a',
        'DELETE done',
        'POST ${next.accessToken} ${next.tenantSlug} device-a',
        'POST done',
      ]);
    });
  }

  test('failed unlink blocks reassociation to another user or tenant',
      () async {
    await coordinator.setSession(student);
    registration.failUnregister = true;
    await coordinator.setSession(otherTenant);
    expect(registration.calls.where((call) => call.contains('other-access')),
        isEmpty);
    registration.failUnregister = false;
    await coordinator.setSession(otherTenant);
    expect(
        registration.calls.lastIndexOf('DELETE done'),
        lessThan(registration.calls
            .indexOf('POST other-access institution-b device-a')));
  });

  test('uncertain POST still requires DELETE during logout', () async {
    registration.failRegister = true;
    await coordinator.setSession(student);
    await coordinator.beforeRemoteLogout('student-access', 'institution-a');
    expect(registration.calls, [
      'POST student-access institution-a device-a',
      'DELETE student-access institution-a device-a',
      'DELETE done',
    ]);
  });

  test('failed POST can retry on next auth event without duplicate success',
      () async {
    registration.failRegister = true;
    await coordinator.setSession(student);
    registration.failRegister = false;
    await coordinator.setSession(student);
    await coordinator.setSession(student);
    expect(
        registration.calls.where((call) => call == 'POST done'), hasLength(1));
  });

  test('failed DELETE does not throw or prevent subsequent safe retry',
      () async {
    await coordinator.setSession(student);
    registration.failUnregister = true;
    await coordinator.beforeRemoteLogout('student-access', 'institution-a');
    registration.failUnregister = false;
    await coordinator.beforeRemoteLogout('new-access', 'institution-a');
    expect(registration.calls[3], 'DELETE new-access institution-a device-a');
    expect(registration.calls.last, 'DELETE done');
  });

  test('missing token does not fabricate a registration', () async {
    tokens.token = null;
    await coordinator.setSession(student);
    expect(registration.calls, isEmpty);
    tokens.events.add('device-later');
    await drain();
    expect(registration.calls.last, 'POST done');
  });

  test('Firebase lookup error allows logout and a later lookup retry',
      () async {
    tokens.lookupError = StateError('synthetic Firebase failure');
    await coordinator.setSession(student);
    tokens.lookupError = null;
    await coordinator.setSession(student);
    expect(registration.calls.last, 'POST done');
    await coordinator.beforeRemoteLogout('student-access', 'institution-a');
    expect(registration.calls.last, 'DELETE done');
  });

  test('refresh stream errors do not break following events or logout',
      () async {
    await coordinator.setSession(student);
    tokens.events.addError(StateError('synthetic stream error'));
    tokens.events.add('device-b');
    await drain();
    await coordinator.beforeRemoteLogout('student-access', 'institution-a');
    expect(registration.calls[4], 'POST student-access institution-a device-b');
    expect(
        registration.calls[6], 'DELETE student-access institution-a device-b');
  });

  test('Firebase subscription initialization failure does not break auth',
      () async {
    coordinator.dispose();
    tokens.subscriptionError = StateError('Firebase unavailable');
    coordinator = PushRegistrationCoordinator(registration, tokens);
    await coordinator.setSession(student);
    await coordinator.beforeRemoteLogout('student-access', 'institution-a');
    expect(registration.calls.last, 'DELETE done');
  });

  test('logout uses renewed bearer after local unauthenticated event',
      () async {
    await coordinator.setSession(student);
    final signedOut = coordinator.setSession(null);
    final logout = coordinator.beforeRemoteLogout('renewed', 'institution-a');
    await Future.wait([signedOut, logout]);
    expect(registration.calls[2], 'DELETE renewed institution-a device-a');
  });

  test('refresh cannot register while signed out', () async {
    tokens.events.add('device-a');
    await coordinator.setSession(null);
    await drain();
    expect(registration.calls, isEmpty);
  });

  test('dispose cancels subscription and invalidates pending lookup', () async {
    tokens.lookup = Completer<String?>();
    final login = coordinator.setSession(student);
    coordinator.dispose();
    expect(tokens.events.hasListener, isFalse);
    tokens.events.add('device-new');
    tokens.lookup!.complete('device-old');
    await login;
    expect(registration.calls, isEmpty);
  });

  test('POST and DELETE preserve existing HTTP device contract', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response('{}', 200);
    });
    addTearDown(client.close);
    final api = PushDeviceRegistration(
        ApiClient(httpClient: client, baseUrl: 'https://test.invalid/api/v1'));
    await api.register(
        accessToken: 'synthetic-access',
        tenantSlug: 'institution-a',
        token: 'synthetic-fcm');
    await api.unregister(
        accessToken: 'synthetic-access',
        tenantSlug: 'institution-a',
        token: 'synthetic-fcm');
    expect(requests.map((request) => request.method), ['POST', 'DELETE']);
    for (final request in requests) {
      expect(request.url.path,
          '/api/v1/tenants/institution-a/notifications/devices');
      expect(request.headers['authorization'], 'Bearer synthetic-access');
      expect(request.headers['x-tenant-slug'], 'institution-a');
      expect(jsonDecode(request.body), {'token': 'synthetic-fcm'});
    }
  });

  group('Riverpod wiring', () {
    const session = AuthSession(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        expiresAt: 4102444800,
        user: fakeStudent);

    ProviderContainer containerFor(
        FakeAuthService auth, FakeSessionStorage storage) {
      final container = ProviderContainer(overrides: [
        apiAuthServiceProvider.overrideWithValue(auth),
        sessionStorageProvider.overrideWithValue(storage),
        pushTokenSourceProvider.overrideWithValue(tokens),
        pushDeviceRegistrationProvider.overrideWithValue(registration),
      ]);
      addTearDown(container.dispose);
      return container;
    }

    test(
        'coordinator is shared within container and isolated between containers',
        () {
      final subscriptionsBefore = tokens.subscriptions;
      final first = containerFor(FakeAuthService(), FakeSessionStorage());
      final second = containerFor(FakeAuthService(), FakeSessionStorage());
      expect(first.read(pushRegistrationCoordinatorProvider),
          same(first.read(pushRegistrationCoordinatorProvider)));
      expect(first.read(pushRegistrationCoordinatorProvider),
          isNot(same(second.read(pushRegistrationCoordinatorProvider))));
      expect(tokens.subscriptions, subscriptionsBefore + 2);
    });

    test('login registers and logout unlinks before remote auth logout',
        () async {
      final auth = FakeAuthService();
      final container = containerFor(auth, FakeSessionStorage());
      container.read(pushAuthListenerProvider);
      final controller = container.read(authControllerProvider.notifier);
      await controller.restoreSession();
      await controller.login(
          email: 'synthetic', password: 'synthetic', rememberSession: false);
      await drain();
      expect(registration.calls.first,
          'POST access-token instituicao-teste device-a');
      registration.unregistering = Completer<void>();
      final logout = controller.logout();
      await drain();
      expect(auth.logoutCalls, isEmpty);
      expect(container.read(authControllerProvider).isAuthenticated, isFalse);
      registration.unregistering!.complete();
      await logout;
      expect(registration.calls.last, 'DELETE done');
      expect(auth.logoutCalls, [('access-token', 'instituicao-teste')]);
    });

    test('restored session registers without an interactive login', () async {
      final storage = FakeSessionStorage();
      await storage.save(session);
      final auth = FakeAuthService();
      final container = containerFor(auth, storage);
      container.read(pushAuthListenerProvider);
      await container.read(authControllerProvider.notifier).restoreSession();
      await drain();
      expect(auth.loginCalls, 0);
      expect(registration.calls,
          ['POST access-token instituicao-teste device-a', 'POST done']);
    });

    test('network failure unlinking device still performs remote logout',
        () async {
      final auth = FakeAuthService();
      final container = containerFor(auth, FakeSessionStorage());
      container.read(pushAuthListenerProvider);
      final controller = container.read(authControllerProvider.notifier);
      await controller.restoreSession();
      await controller.login(
          email: 'synthetic', password: 'synthetic', rememberSession: false);
      await drain();
      registration.failUnregister = true;
      await controller.logout();
      expect(auth.logoutCalls, hasLength(1));
      expect(controller.state.isAuthenticated, isFalse);
    });

    testWidgets('logout deadline does not release the FCM mutation queue',
        (tester) async {
      final auth = FakeAuthService();
      final container = containerFor(auth, FakeSessionStorage());
      container.read(pushAuthListenerProvider);
      final controller = container.read(authControllerProvider.notifier);
      await controller.restoreSession();
      registration.registering = Completer<void>();
      await controller.login(
        email: 'synthetic',
        password: 'synthetic',
        rememberSession: false,
      );
      await tester.pump();
      final logout = controller.logout();
      await tester.pump();
      expect(auth.logoutCalls, isEmpty);
      await tester.pump(const Duration(seconds: 4));
      await logout;
      expect(auth.logoutCalls, hasLength(1));
      expect(
          registration.calls, ['POST access-token instituicao-teste device-a']);
      registration.registering!.complete();
      await tester.pump();
      expect(registration.calls, [
        'POST access-token instituicao-teste device-a',
        'POST done',
        'DELETE access-token instituicao-teste device-a',
        'DELETE done',
      ]);
    });

    test('logout during auth renewal retries unlink with renewed credentials',
        () async {
      final renewal = Completer<AuthSession>();
      final auth = FakeAuthService(refreshCompleter: renewal);
      final container = containerFor(auth, FakeSessionStorage());
      container.read(pushAuthListenerProvider);
      final controller = container.read(authControllerProvider.notifier);
      await controller.restoreSession();
      await controller.login(
        email: 'synthetic',
        password: 'synthetic',
        rememberSession: false,
      );
      await drain();
      final refreshing =
          controller.refreshAccessToken('access-token', 'instituicao-teste');
      registration.failUnregister = true;
      final logout = controller.logout();
      await drain();
      expect(auth.logoutCalls, isEmpty);
      expect(registration.calls.last,
          'DELETE access-token instituicao-teste device-a');
      registration.failUnregister = false;
      renewal.complete(const AuthSession(
        accessToken: 'renewed-access',
        refreshToken: 'renewed-refresh',
        expiresAt: 4102444800,
        user: fakeStudent,
      ));
      await Future.wait([refreshing, logout]);
      expect(registration.calls.sublist(3), [
        'DELETE renewed-access instituicao-teste device-a',
        'DELETE done',
      ]);
      expect(auth.logoutCalls, [('renewed-access', 'instituicao-teste')]);
      expect(controller.state.isAuthenticated, isFalse);
    });
  });
}
