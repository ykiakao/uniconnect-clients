import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:uniconnect/core/network/api_client.dart';
import 'package:uniconnect/features/academic/demo/synthetic_academic_providers.dart';
import 'package:uniconnect/features/auth/providers/auth_provider.dart';
import 'package:uniconnect/features/auth/services/api_auth_service.dart';
import 'package:uniconnect/features/activities/providers/student_submission_provider.dart';
import 'fakes/fake_auth_service.dart';
import 'fakes/fake_session_storage.dart';
import 'synthetic_academic_data_test.dart' show syntheticStudent;
import 'student_activity_contract_test.dart' show activityId;

void main() {
  for (final mode in ['unauthenticated', 'teacher', 'synthetic']) {
    test('$mode cannot query or submit persistent student data', () async {
      final user = mode == 'synthetic' ? syntheticStudent : fakeTeacher;
      final auth = AuthController(
          FakeAuthService(
              loginResult: AuthSession(
                  accessToken: 'token',
                  refreshToken: 'fixture',
                  expiresAt: 4102444800,
                  user: user)),
          FakeSessionStorage());
      if (mode != 'unauthenticated') {
        await auth.login(
            email: user.email, password: 'fixture', rememberSession: false);
      }
      var calls = 0;
      final container = ProviderContainer(retry: (_, __) => null, overrides: [
        authControllerProvider.overrideWith((ref) => auth),
        syntheticDemoRequestedProvider.overrideWithValue(mode == 'synthetic'),
        apiClientProvider
            .overrideWithValue(ApiClient(httpClient: MockClient((_) async {
          calls++;
          throw StateError('Must not reach HTTP');
        }))),
      ]);
      addTearDown(container.dispose);
      await expectLater(
          container.read(ownSubmissionProvider(activityId).future),
          throwsA(anything));
      expect(calls, 0);
    });
  }
}
