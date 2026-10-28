import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:uniconnect/core/constants/app_routes.dart';
import 'package:uniconnect/features/activities/presentation/activities_page.dart';
import 'package:uniconnect/core/router/app_route_transition_page.dart';
import 'package:uniconnect/core/theme/app_theme.dart';
import 'package:uniconnect/features/activities/providers/activity_provider.dart';
import 'package:uniconnect/features/activities/models/academic_activity.dart';
import 'package:uniconnect/features/auth/providers/auth_provider.dart';
import 'package:uniconnect/features/auth/services/api_auth_service.dart';
import 'package:uniconnect/features/grades/providers/grades_provider.dart';
import 'package:uniconnect/main.dart';
import 'package:uniconnect/shared/widgets/bottom_nav.dart';

import 'demo_day_test.dart' show demoActivity;
import 'fakes/fake_auth_service.dart';
import 'fakes/fake_session_storage.dart';
import 'layout_quality_test.dart' show captureLayout;

NavigationBar nav(WidgetTester tester) =>
    tester.widget<NavigationBar>(find.byType(NavigationBar));

double activeScale(WidgetTester tester, IconData icon) {
  final transform =
      find.ancestor(of: find.byIcon(icon), matching: find.byType(Transform));
  expect(transform, findsWidgets);
  return tester.widget<Transform>(transform.first).transform.storage[0];
}

void main() {
  setUpAll(() async {
    await (FontLoader('Inter')
          ..addFont(rootBundle.load('assets/fonts/Inter/Inter-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Inter/Inter-Bold.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });

  testWidgets(
      'active navigation slides in 350 ms without changing layout or replay',
      (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final index = ValueNotifier(0);
    final redraw = ValueNotifier(0);
    addTearDown(redraw.dispose);
    addTearDown(index.dispose);
    final frame = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
        key: frame,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          debugShowCheckedModeBanner: false,
          home: ListenableBuilder(
              listenable: Listenable.merge([index, redraw]),
              builder: (context, child) => Scaffold(
                  bottomNavigationBar:
                      UniBottomNav(currentIndex: index.value))),
        )));
    expect(nav(tester).animationDuration, const Duration(milliseconds: 350));
    expect(activeScale(tester, Icons.dashboard_outlined), closeTo(1, .001));
    final bounds = tester.getRect(find.byType(NavigationBar));
    index.value = 1;
    await tester.pump();
    expect(activeScale(tester, Icons.checklist_outlined), closeTo(.96, .001));
    await tester.pump(const Duration(milliseconds: 80));
    expect(activeScale(tester, Icons.checklist_outlined),
        inExclusiveRange(.96, 1));
    expect(nav(tester).indicatorColor, Colors.transparent);
    final selected =
        nav(tester).labelTextStyle!.resolve({WidgetState.selected})!;
    expect(selected.color, isNot(AppTheme.lightTheme.colorScheme.primary));
    await captureLayout(tester, frame, 'motion-navigation-mid');
    await tester.pumpAndSettle();
    expect(activeScale(tester, Icons.checklist_outlined), closeTo(1, .001));
    expect(nav(tester).labelTextStyle!.resolve({WidgetState.selected})!.color,
        AppTheme.lightTheme.colorScheme.primary);
    expect(tester.getRect(find.byType(NavigationBar)), bounds);
    await captureLayout(tester, frame, 'motion-navigation-selected');
    redraw.value++;
    await tester.pump();
    expect(activeScale(tester, Icons.checklist_outlined), closeTo(1, .001));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  for (final accessibleNavigation in [false, true]) {
    testWidgets(
        'motion preference skips nav and page effects: $accessibleNavigation',
        (tester) async {
      final page = AppRouteTransitionPage.slideFromRight(
          key: const ValueKey('page'), child: const Text('Page content'));
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme,
          home: MediaQuery(
            data: MediaQueryData(
                disableAnimations: !accessibleNavigation,
                accessibleNavigation: accessibleNavigation),
            child: Builder(
                builder: (context) => Scaffold(
                      body: KeyedSubtree(
                        key: const ValueKey('motion-body'),
                        child: Column(children: [
                          for (final route in [
                            page,
                            AppRouteTransitionPage.slideFromBottom(
                                key: const ValueKey('bottom'),
                                child: const Text('Bottom content')),
                            AppRouteTransitionPage.fade(
                                key: const ValueKey('fade'),
                                child: const Text('Fade content')),
                          ])
                            route.transitionsBuilder(
                                context,
                                const AlwaysStoppedAnimation(.25),
                                const AlwaysStoppedAnimation(0),
                                route.child),
                        ]),
                      ),
                      bottomNavigationBar: const UniBottomNav(currentIndex: 1),
                    )),
          )));
      expect(nav(tester).animationDuration, Duration.zero);
      expect(activeScale(tester, Icons.checklist_outlined), closeTo(1, .001));
      expect(nav(tester).indicatorColor, Colors.transparent);
      final indicator = tester.widget<DecoratedBox>(
          find.byKey(const ValueKey('nav-sliding-indicator')));
      expect((indicator.decoration as BoxDecoration).color,
          AppTheme.lightTheme.colorScheme.primary.withValues(alpha: .10));
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('motion-body')),
              matching: find.byType(SlideTransition)),
          findsNothing);
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('motion-body')),
              matching: find.byType(FadeTransition)),
          findsNothing);
      final context = tester.element(find.byType(UniBottomNav));
      final fade = AppRouteTransitionPage.fade(
          key: const ValueKey('fade'), child: const Text('Fade content'));
      final transition = fade.transitionsBuilder(
          context,
          const AlwaysStoppedAnimation(.25),
          const AlwaysStoppedAnimation(0),
          fade.child);
      expect(transition, same(fade.child));
    });
  }

  testWidgets('page transitions are brief and use small offsets',
      (tester) async {
    final page = AppRouteTransitionPage.slideFromRight(
        key: const ValueKey('page'), child: const Text('Page content'));
    expect(page.transitionDuration, const Duration(milliseconds: 220));
    expect(page.reverseTransitionDuration, const Duration(milliseconds: 180));
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => page.transitionsBuilder(
                context,
                const AlwaysStoppedAnimation(0),
                const AlwaysStoppedAnimation(0),
                page.child))));
    final slide = tester.widget<SlideTransition>(find
        .ancestor(
            of: find.text('Page content'),
            matching: find.byType(SlideTransition))
        .first);
    expect(slide.position.value, const Offset(.02, 0));
    expect(
        tester
            .widget<FadeTransition>(find
                .ancestor(
                    of: find.text('Page content'),
                    matching: find.byType(FadeTransition))
                .first)
            .opacity
            .value,
        0);
  });

  testWidgets(
      'real router preserves filters on return and reuses academic data',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final storage = FakeSessionStorage();
    await storage.save(const AuthSession(
        accessToken: 'test-token',
        refreshToken: 'test-refresh',
        expiresAt: 4102444800,
        user: fakeStudent));
    var activityCalls = 0;
    var gradeCalls = 0;
    await tester.pumpWidget(ProviderScope(overrides: [
      apiAuthServiceProvider.overrideWithValue(FakeAuthService()),
      sessionStorageProvider.overrideWithValue(storage),
      activitiesProvider.overrideWith((ref) async {
        activityCalls++;
        return [demoActivity];
      }),
      subjectGradesProvider.overrideWith((ref) async {
        gradeCalls++;
        return [];
      }),
    ], child: const UniConnectApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(NavigationBar), matching: find.text('Atividades')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final input = find.byType(TextField).first;
    await tester.tap(input);
    await tester.enterText(input, 'Pesquisa');
    await tester.pumpAndSettle();
    final filter = tester.widget<SegmentedButton<ActivityPriority?>>(
        find.byType(SegmentedButton<ActivityPriority?>));
    filter.onSelectionChanged!({ActivityPriority.medium});
    await tester.pumpAndSettle();
    final pageState = tester.state(find.byType(ActivitiesPage));
    await tester.scrollUntilVisible(
        find.text('Pesquisa aplicada').hitTestable(), 150,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Pesquisa aplicada'));
    await tester.pumpAndSettle();
    expect(find.text('Detalhes da atividade'), findsOneWidget);
    await tester.tap(find.byTooltip('Retornar'));
    await tester.pumpAndSettle();
    expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'Pesquisa');
    expect(
        tester
            .widget<SegmentedButton<ActivityPriority?>>(
                find.byType(SegmentedButton<ActivityPriority?>))
            .selected,
        {ActivityPriority.medium});
    expect(tester.state(find.byType(ActivitiesPage)), same(pageState));
    final router = GoRouter.of(tester.element(find.byType(UniBottomNav)));
    for (final route in [
      AppRoutes.grades,
      AppRoutes.activities,
      AppRoutes.studentDashboard,
      AppRoutes.activities
    ]) {
      router.go(route);
      await tester.pumpAndSettle();
    }
    expect(activityCalls, 1);
    expect(gradeCalls, 1);
    expect(tester.takeException(), isNull);
  });
}
