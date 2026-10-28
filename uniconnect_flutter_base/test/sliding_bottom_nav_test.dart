import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:uniconnect/core/theme/app_theme.dart';
import 'package:uniconnect/shared/widgets/bottom_nav.dart';

import 'layout_quality_test.dart' show captureLayout;

Finder get capsule => find.byKey(const ValueKey('nav-sliding-indicator'));

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
      'capsule uses theme primary and slides through intermediate positions',
      (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    final frame = GlobalKey();
    final theme = AppTheme.lightTheme;
    const primary = Color(0xFF176B52);
    await tester.pumpWidget(RepaintBoundary(
        key: frame,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme.copyWith(
              colorScheme: theme.colorScheme.copyWith(primary: primary)),
          home: ValueListenableBuilder<int>(
              valueListenable: selected,
              builder: (context, value, _) => Scaffold(
                  bottomNavigationBar: UniBottomNav(currentIndex: value))),
        )));
    await tester.pumpAndSettle();
    expect(capsule, findsOneWidget);
    final decoration =
        tester.widget<DecoratedBox>(capsule).decoration as BoxDecoration;
    expect(decoration.color, primary.withValues(alpha: .10));
    final start = tester.getRect(capsule);
    selected.value = 4;
    await tester.pump();
    expect(tester.getRect(capsule).left, closeTo(start.left, .1));
    await tester.pump(const Duration(milliseconds: 140));
    final middle = tester.getRect(capsule);
    expect(middle.left, greaterThan(start.left));
    expect(middle.right,
        lessThan(tester.getRect(find.byType(NavigationBar)).right));
    await captureLayout(tester, frame, 'sliding-nav-middle');
    await tester.pump(const Duration(milliseconds: 210));
    final end = tester.getRect(capsule);
    expect(
        end.center.dx,
        closeTo(
            tester.getRect(find.byIcon(Icons.person_outline)).center.dx, .5));
    expect(
        end.center.dy,
        closeTo(
            tester.getRect(find.byIcon(Icons.person_outline)).center.dy, .5));
    await captureLayout(tester, frame, 'sliding-nav-final');
    expect(tester.takeException(), isNull);
  });

  testWidgets('rapid selections retarget from the current painted position',
      (tester) async {
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: ValueListenableBuilder<int>(
            valueListenable: selected,
            builder: (context, value, _) => Scaffold(
                bottomNavigationBar: UniBottomNav(currentIndex: value)))));
    await tester.pumpAndSettle();
    for (final index in [4, 1, 3, 0, 2]) {
      final before = tester.getRect(capsule);
      selected.value = index;
      await tester.pump();
      expect(tester.getRect(capsule).left, closeTo(before.left, .1));
      await tester.pump(const Duration(milliseconds: 55));
    }
    await tester.pumpAndSettle();
    expect(
        tester.getRect(capsule).center.dx,
        closeTo(
            tester.getRect(find.byIcon(Icons.chat_bubble_outline)).center.dx,
            .5));
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'real route replacement hands off the in-flight capsule without changing URLs',
      (tester) async {
    final router = GoRouter(initialLocation: '/aluno', routes: [
      for (final (index, path) in [
        (0, '/aluno'),
        (1, '/atividades'),
        (2, '/chat'),
        (3, '/notas'),
        (4, '/perfil')
      ])
        GoRoute(
            path: path,
            pageBuilder: (context, state) => CustomTransitionPage(
                key: state.pageKey,
                child: Scaffold(
                    body: Text(path),
                    bottomNavigationBar: UniBottomNav(currentIndex: index)),
                transitionDuration: const Duration(milliseconds: 220),
                transitionsBuilder: (context, animation, secondary, child) =>
                    FadeTransition(opacity: animation, child: child))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router));
    await tester.pumpAndSettle();
    final start = tester.getRect(capsule).center.dx;
    await tester.tap(find.text('Perfil'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    final inFlight = tester.getRect(capsule.last).center.dx;
    expect(inFlight, greaterThan(start));
    final bar = find.byType(NavigationBar).last;
    await tester
        .tap(find.descendant(of: bar, matching: find.text('Atividades')));
    await tester.pump();
    expect(tester.getRect(capsule.last).center.dx, closeTo(inFlight, .5));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/atividades');
    expect(
        tester.getRect(capsule).center.dx,
        closeTo(tester.getRect(find.byIcon(Icons.checklist_outlined)).center.dx,
            .5));
    router.push('/perfil');
    await tester.pumpAndSettle();
    router.pop();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/atividades');
    expect(
        tester.getRect(capsule).center.dx,
        closeTo(tester.getRect(find.byIcon(Icons.checklist_outlined)).center.dx,
            .5));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'enabling reduced motion stops an in-flight slide at the selected tab',
      (tester) async {
    final selected = ValueNotifier(0);
    final reduced = ValueNotifier(false);
    addTearDown(selected.dispose);
    addTearDown(reduced.dispose);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: ListenableBuilder(
            listenable: Listenable.merge([selected, reduced]),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(disableAnimations: reduced.value),
                child: Scaffold(
                    bottomNavigationBar:
                        UniBottomNav(currentIndex: selected.value))))));
    await tester.pumpAndSettle();
    selected.value = 4;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    reduced.value = true;
    await tester.pumpAndSettle();
    expect(
        tester.getRect(capsule).center.dx,
        closeTo(
            tester.getRect(find.byIcon(Icons.person_outline)).center.dx, .5));
    expect(
        tester
            .widget<NavigationBar>(find.byType(NavigationBar))
            .animationDuration,
        Duration.zero);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  for (final rtl in [false, true]) {
    testWidgets('capsule aligns with safe areas and large labels, rtl=$rtl',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme,
          home: Directionality(
              textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
              child: MediaQuery(
                  data: const MediaQueryData(
                      padding: EdgeInsets.fromLTRB(16, 0, 20, 24),
                      textScaler: TextScaler.linear(2),
                      disableAnimations: true),
                  child: const Scaffold(
                      bottomNavigationBar: UniBottomNav(currentIndex: 4))))));
      await tester.pumpAndSettle();
      final rect = tester.getRect(capsule);
      final icon = tester.getRect(find.byIcon(Icons.person_outline));
      expect(rect.center.dx, closeTo(icon.center.dx, .5));
      expect(rect.center.dy, closeTo(icon.center.dy, .5));
      expect(rect.left, greaterThanOrEqualTo(16));
      expect(rect.right, lessThanOrEqualTo(340));
      expect(rect.bottom, lessThanOrEqualTo(776));
      expect(tester.takeException(), isNull);
    });
  }
}
