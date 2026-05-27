import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:uniconnect/core/network/api_client.dart';
import 'package:uniconnect/features/auth/presentation/login_page.dart';
import 'package:uniconnect/features/auth/providers/auth_provider.dart';
import 'package:uniconnect/features/auth/services/api_auth_service.dart';
import 'package:uniconnect/main.dart';

import 'fakes/fake_session_storage.dart';

class _InvalidCredentialsAuthService extends ApiAuthService {
  _InvalidCredentialsAuthService() : super(ApiClient());

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) {
    throw const ApiException('Credenciais inválidas.', statusCode: 401);
  }
}

void main() {
  testWidgets('renders UniConnect login', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionStorageProvider.overrideWithValue(FakeSessionStorage()),
        ],
        child: const UniConnectApp(),
      ),
    );

    expect(find.text('UniConnect'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });

  testWidgets('shows invalid credentials message inline', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiAuthServiceProvider.overrideWithValue(
            _InvalidCredentialsAuthService(),
          ),
          sessionStorageProvider.overrideWithValue(FakeSessionStorage()),
        ],
        child: const MaterialApp(home: LoginPage()),
      ),
    );

    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'E-mail ou senha incorretos. Confira os dados e tente novamente.',
      ),
      findsOneWidget,
    );
  });
}
