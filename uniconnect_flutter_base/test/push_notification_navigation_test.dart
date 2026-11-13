import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:uniconnect/core/notifications/push_notification_navigation.dart';
import 'package:uniconnect/features/auth/providers/auth_provider.dart';
import 'package:uniconnect/features/auth/services/session_storage.dart';

import 'fakes/fake_auth_service.dart';

class FakeOpenSource implements PushOpenSource {
  final events = StreamController<PushOpenEvent>.broadcast(sync: true);
  final initial = Completer<PushOpenEvent?>();
  int initialCalls = 0;
  @override
  Future<PushOpenEvent?> getInitialMessage() {
    initialCalls++;
    return initial.future;
  }

  @override
  Stream<PushOpenEvent> get onOpened => events.stream;
}

const activityId = 'c4bf0e60-9df0-4b91-bfcf-2f76ce3814a9';
PushOpenEvent event(
        {String? id = 'message-a', Map<String, dynamic> fields = const {}}) =>
    PushOpenEvent({
      'type': 'activity_published',
      'tenantId': fakeTenant.id,
      'classId': 'test-class',
      'activityId': activityId,
      ...fields,
    }, messageId: id);
Future<void> drain() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeOpenSource source;
  late List<String> routes;
  late PushNotificationNavigator navigator;
  void authenticate(
          {SessionRenewal renewal = SessionRenewal.idle, int logout = 0}) =>
      navigator.updateAuth(
          const AuthState.authenticated(fakeStudent,
              accessToken: 'synthetic-access'),
          logoutGeneration: logout,
          renewal: renewal);
  setUp(() {
    source = FakeOpenSource();
    routes = [];
    navigator = PushNotificationNavigator(source, routes.add);
  });
  tearDown(() async {
    navigator.dispose();
    if (!source.initial.isCompleted) source.initial.complete(null);
    await source.events.close();
  });

  test('notification tap opens the exact activity of the authenticated student',
      () async {
    authenticate();
    source.events.add(event());
    await drain();
    expect(routes, ['/atividades/$activityId']);
  });

  test('cold start retains the initial notification until session restoration',
      () async {
    navigator.updateAuth(const AuthState.restoring(),
        logoutGeneration: 0, renewal: SessionRenewal.idle);
    source.initial.complete(event());
    await drain();
    expect(routes, isEmpty);
    authenticate();
    await drain();
    expect(routes, ['/atividades/$activityId']);
    expect(source.initialCalls, 1);
  });

  test('notification while signed out waits for login', () async {
    navigator.updateAuth(const AuthState.unauthenticated(),
        logoutGeneration: 0, renewal: SessionRenewal.idle);
    source.events.add(event());
    await drain();
    expect(routes, isEmpty);
    authenticate();
    await drain();
    expect(routes, ['/atividades/$activityId']);
  });

  for (final renewal in [SessionRenewal.pending, SessionRenewal.failed]) {
    test('waits during ${renewal.name} renewal before opening the activity',
        () async {
      authenticate(renewal: renewal);
      source.events.add(event());
      await drain();
      expect(routes, isEmpty);
      authenticate();
      await drain();
      expect(routes, ['/atividades/$activityId']);
    });
  }

  test('initial message and tap with same messageId navigate only once',
      () async {
    authenticate();
    source.initial.complete(event());
    await drain();
    source.events.add(event());
    await drain();
    expect(routes, ['/atividades/$activityId']);
  });

  test('deduplicates messages without a provider ID by destination', () async {
    authenticate();
    source.events.add(event(id: null));
    source.events.add(event(id: null));
    await drain();
    expect(routes, ['/atividades/$activityId']);
  });

  test('latest tap wins while waiting for authentication', () async {
    source.events.add(event());
    source.events.add(
        event(id: 'message-b', fields: {'activityId': 'another-activity'}));
    authenticate();
    await drain();
    expect(routes, ['/atividades/another-activity']);
  });

  for (final fields in <Map<String, dynamic>>[
    {'tenantId': 'another-tenant'},
    {'tenantId': ''},
    {'tenantId': null},
    {'tenantSlug': 'another-institution'},
    {'activityId': '../outside'},
    {'activityId': 'https://evil.invalid'},
    {'activityId': 'activity?token=unsafe'},
    {'activityId': 123},
    {'activityId': ''},
    {'type': 'unsupported'},
  ]) {
    test(
        'ignores invalid or out-of-tenant payload ${fields.keys.join(',')}: $fields',
        () async {
      authenticate();
      source.events.add(event(fields: fields));
      await drain();
      expect(routes, isEmpty);
    });
  }

  test('does not open a student route for a teacher', () async {
    navigator.updateAuth(
        const AuthState.authenticated(fakeTeacher, accessToken: 'synthetic'),
        logoutGeneration: 0,
        renewal: SessionRenewal.idle);
    source.events.add(event());
    await drain();
    expect(routes, isEmpty);
  });

  test('logout invalidates a pending destination', () async {
    authenticate(renewal: SessionRenewal.pending);
    source.events.add(event());
    navigator.updateAuth(const AuthState.unauthenticated(),
        logoutGeneration: 1, renewal: SessionRenewal.idle);
    authenticate(logout: 1);
    await drain();
    expect(routes, isEmpty);
  });

  test('late initial message is discarded after logout', () async {
    authenticate();
    navigator.updateAuth(const AuthState.unauthenticated(),
        logoutGeneration: 1, renewal: SessionRenewal.idle);
    source.initial.complete(event());
    authenticate(logout: 1);
    await drain();
    expect(routes, isEmpty);
  });

  test('account switch invalidates a pending destination', () async {
    authenticate(renewal: SessionRenewal.pending);
    source.events.add(event());
    navigator.updateAuth(
        const AuthState.authenticated(fakeTeacher, accessToken: 'other'),
        logoutGeneration: 0,
        renewal: SessionRenewal.idle);
    authenticate();
    await drain();
    expect(routes, isEmpty);
  });

  test(
      'logout before the scheduled navigation prevents opening the destination',
      () async {
    authenticate();
    source.events.add(event());
    navigator.updateAuth(const AuthState.unauthenticated(),
        logoutGeneration: 1, renewal: SessionRenewal.idle);
    await drain();
    expect(routes, isEmpty);
  });

  test('initial-message failure does not break subsequent taps', () async {
    authenticate();
    source.initial.completeError(StateError('synthetic Firebase failure'));
    await drain();
    source.events.add(event());
    await drain();
    expect(routes, ['/atividades/$activityId']);
  });

  test('stream error does not break subsequent taps', () async {
    authenticate();
    source.events.addError(StateError('synthetic stream error'));
    await drain();
    source.events.add(event());
    await drain();
    expect(routes, ['/atividades/$activityId']);
  });

  test('dispose stops delivery of a late initial message and cancels listener',
      () async {
    authenticate();
    navigator.dispose();
    source.initial.complete(event());
    await drain();
    expect(routes, isEmpty);
    expect(source.events.hasListener, isFalse);
  });
}
