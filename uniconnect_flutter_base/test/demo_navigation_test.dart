import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:uniconnect/core/constants/app_routes.dart';
import 'package:uniconnect/features/activities/providers/activity_provider.dart';
import 'package:uniconnect/features/auth/models/app_user.dart';
import 'package:uniconnect/features/auth/providers/auth_provider.dart';
import 'package:uniconnect/features/auth/services/api_auth_service.dart';
import 'package:uniconnect/features/grades/providers/grades_provider.dart';
import 'package:uniconnect/main.dart';

import 'demo_day_test.dart' show demoActivity;
import 'fakes/fake_auth_service.dart';
import 'fakes/fake_session_storage.dart';

void main() {
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
        expect(find.text('Nenhuma nota disponível'), findsOneWidget);
        await tester.tap(find.text('Perfil'));
        await tester.pumpAndSettle();
      } else {
        expect(currentLocation(), AppRoutes.teacherDashboard);
        router.go('/atividades/activity-1');
        await tester.pumpAndSettle();
        expect(currentLocation(), AppRoutes.teacherDashboard);
        final prototypeRoutes = [
          AppRoutes.teacherCreateActivity,
          AppRoutes.teacherGrades
        ];
        final prototypeTitles = [
          'Atividades acadêmicas',
          'Lançamento de notas'
        ];
        for (var index = 0; index < prototypeRoutes.length; index++) {
          await tester.scrollUntilVisible(
              find.text(prototypeTitles[index]).hitTestable(), 200,
              scrollable: find.byType(Scrollable).first);
          final card = find
              .ancestor(
                  of: find.text(prototypeTitles[index]),
                  matching: find.byType(Card))
              .first;
          final link = find.descendant(
              of: card,
              matching: find.widgetWithText(TextButton, 'Ver protótipo'));
          await tester.scrollUntilVisible(link.hitTestable(), 100,
              scrollable: find.byType(Scrollable).first);
          await tester.pumpAndSettle();
          await tester.tap(link);
          await tester.pumpAndSettle();
          expect(currentLocation(), prototypeRoutes[index]);
          await tester.tap(find.byTooltip('Retornar'));
          await tester.pumpAndSettle();
          expect(currentLocation(), AppRoutes.teacherDashboard);
        }
        await tester.scrollUntilVisible(
            find.text('Ver perfil').hitTestable(), -200,
            scrollable: find.byType(Scrollable).first);
        await tester.tap(find.text('Ver perfil'));
        await tester.pumpAndSettle();
        expect(find.byType(NavigationBar), findsNothing);
        await tester.tap(find.byTooltip('Retornar'));
        await tester.pumpAndSettle();
        expect(currentLocation(), AppRoutes.teacherDashboard);
        await tester.tap(find.text('Ver perfil'));
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
