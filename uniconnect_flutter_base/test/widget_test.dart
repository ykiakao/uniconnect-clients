import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uniconnect/core/router/app_router.dart';
import 'package:uniconnect/core/network/api_client.dart';
import 'package:uniconnect/features/auth/presentation/login_page.dart';
import 'package:uniconnect/features/auth/providers/auth_provider.dart';
import 'package:uniconnect/features/auth/services/api_auth_service.dart';

import 'fakes/fake_auth_service.dart';
import 'fakes/fake_session_storage.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  Future<void> pumpLoginPage(
    WidgetTester tester, {
    required List<Override> overrides,
  }) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: const MaterialApp(home: LoginPage()),
      ),
    );
  }

  void pressLoginButton(WidgetTester tester) {
    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Entrar'),
    );
    button.onPressed!();
  }

  testWidgets('renders UniConnect login without prefilled credentials',
      (tester) async {
    await pumpLoginPage(
      tester,
      overrides: [
        sessionStorageProvider.overrideWithValue(FakeSessionStorage()),
      ],
    );

    expect(find.text('UniConnect'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('aluno@uni.com'), findsNothing);

    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(fields.first.controller?.text, isEmpty);
    expect(fields.last.controller?.text, isEmpty);
    expect(fields.last.obscureText, isTrue);
  });

  testWidgets('shows invalid credentials message inline', (tester) async {
    await pumpLoginPage(
      tester,
      overrides: [
        apiAuthServiceProvider.overrideWithValue(
          FakeAuthService(
            loginError:
                const ApiException('Credenciais inválidas.', statusCode: 401),
          ),
        ),
        sessionStorageProvider.overrideWithValue(FakeSessionStorage()),
      ],
    );

    await tester.enterText(find.byType(TextField).first, 'aluno@uni.com');
    await tester.enterText(find.byType(TextField).last, 'senha-errada');
    pressLoginButton(tester);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'E-mail ou senha incorretos. Confira os dados e tente novamente.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('disables login button and shows loading while authenticating',
      (tester) async {
    final completer = Completer<AuthSession>();

    await pumpLoginPage(
      tester,
      overrides: [
        apiAuthServiceProvider.overrideWithValue(
          FakeAuthService(loginCompleter: completer),
        ),
        sessionStorageProvider.overrideWithValue(FakeSessionStorage()),
      ],
    );

    await tester.enterText(find.byType(TextField).first, 'aluno@uni.com');
    await tester.enterText(find.byType(TextField).last, '123456');
    pressLoginButton(tester);
    await tester.pump();

    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Entrando...'),
    );
    expect(button.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('toggles password visibility', (tester) async {
    await pumpLoginPage(
      tester,
      overrides: [
        sessionStorageProvider.overrideWithValue(FakeSessionStorage()),
      ],
    );

    TextField passwordField() => tester
        .widgetList<TextField>(
          find.byType(TextField),
        )
        .last;

    expect(passwordField().obscureText, isTrue);
    await tester.tap(find.byTooltip('Mostrar senha'));
    await tester.pump();
    expect(passwordField().obscureText, isFalse);
    await tester.tap(find.byTooltip('Ocultar senha'));
    await tester.pump();
    expect(passwordField().obscureText, isTrue);
  });

  testWidgets('clears previous error when editing email or password',
      (tester) async {
    await pumpLoginPage(
      tester,
      overrides: [
        apiAuthServiceProvider.overrideWithValue(
          FakeAuthService(
            loginError:
                const ApiException('Credenciais inválidas.', statusCode: 401),
          ),
        ),
        sessionStorageProvider.overrideWithValue(FakeSessionStorage()),
      ],
    );

    await tester.enterText(find.byType(TextField).first, 'aluno@uni.com');
    await tester.enterText(find.byType(TextField).last, 'senha-errada');
    pressLoginButton(tester);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'E-mail ou senha incorretos. Confira os dados e tente novamente.',
      ),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField).last, '123456');
    await tester.pump();
    expect(
      find.text(
        'E-mail ou senha incorretos. Confira os dados e tente novamente.',
      ),
      findsNothing,
    );
  });

  testWidgets('validates empty email and password before calling API',
      (tester) async {
    final authService = FakeAuthService();

    await pumpLoginPage(
      tester,
      overrides: [
        apiAuthServiceProvider.overrideWithValue(authService),
        sessionStorageProvider.overrideWithValue(FakeSessionStorage()),
      ],
    );

    pressLoginButton(tester);
    await tester.pump();

    expect(find.text('Informe seu e-mail.'), findsOneWidget);
    expect(find.text('Informe sua senha.'), findsOneWidget);
    expect(authService.loginCalls, 0);
  });

  testWidgets('restores valid session without showing login first',
      (tester) async {
    final storage = FakeSessionStorage();
    await storage.save(
      const AuthSession(
        accessToken: 'saved-token',
        refreshToken: 'saved-refresh',
        expiresAt: 4102444800,
        user: fakeStudent,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiAuthServiceProvider.overrideWithValue(FakeAuthService()),
          sessionStorageProvider.overrideWithValue(storage),
        ],
        child: Consumer(
          builder: (context, ref, child) {
            return MaterialApp.router(
              routerConfig: ref.watch(appRouterProvider),
            );
          },
        ),
      ),
    );

    expect(find.text('Entrar'), findsNothing);

    await tester.pumpAndSettle();

    expect(find.text('Aluno'), findsOneWidget);
    expect(find.text('Entrar'), findsNothing);
  });
}
