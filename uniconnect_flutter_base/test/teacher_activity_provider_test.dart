import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniconnect/features/auth/providers/auth_provider.dart';
import 'package:uniconnect/features/auth/services/api_auth_service.dart';
import 'package:uniconnect/features/teacher/providers/teacher_activity_provider.dart';
import 'package:uniconnect/core/network/api_client.dart';
import 'package:http/testing.dart';
import 'fakes/fake_auth_service.dart';
import 'fakes/fake_session_storage.dart';
import 'teacher_activity_service_test.dart' show jsonResponse, page;

void main() {
  test('student session cannot obtain teacher service or send HTTP', () async {
    final auth = AuthController(FakeAuthService(), FakeSessionStorage());
    await auth.login(
        email: 'fixture', password: 'fixture', rememberSession: false);
    var calls = 0;
    final container = ProviderContainer(retry: (_, __) => null, overrides: [
      authControllerProvider.overrideWith((ref) => auth),
      apiClientProvider
          .overrideWithValue(ApiClient(httpClient: MockClient((_) async {
        calls++;
        return jsonResponse(page([]));
      }))),
    ]);
    addTearDown(container.dispose);
    await expectLater(
        container.read(teacherOfferingsProvider.future), throwsA(anything));
    expect(calls, 0);
  });
  test(
      'teacher offerings use authenticated session and unauthorized class never requests activities',
      () async {
    final auth = AuthController(
        FakeAuthService(
            loginResult: const AuthSession(
                accessToken: 'teacher-token',
                refreshToken: 'fixture-refresh',
                expiresAt: 4102444800,
                user: fakeTeacher)),
        FakeSessionStorage());
    await auth.login(
        email: 'fixture', password: 'fixture', rememberSession: false);
    final paths = <String>[];
    final container = ProviderContainer(retry: (_, __) => null, overrides: [
      authControllerProvider.overrideWith((ref) => auth),
      apiClientProvider
          .overrideWithValue(ApiClient(httpClient: MockClient((r) async {
        paths.add(r.url.path);
        expect(r.headers['Authorization'], 'Bearer teacher-token');
        expect(r.headers['x-tenant-slug'], fakeTeacher.tenant.slug);
        return jsonResponse(page([
          {'id': 'class-1', 'name': 'Oferta', 'status': 'active'}
        ]));
      }))),
    ]);
    addTearDown(container.dispose);
    expect((await container.read(teacherOfferingsProvider.future)).single.id,
        'class-1');
    await expectLater(
        container.read(teacherActivitiesProvider('forbidden').future),
        throwsA(anything));
    expect(paths, hasLength(1));
    expect(paths.single.endsWith('/offerings'), isTrue);
  });
}
