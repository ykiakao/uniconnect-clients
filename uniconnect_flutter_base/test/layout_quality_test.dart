import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniconnect/core/theme/app_theme.dart';
import 'package:uniconnect/features/activities/presentation/activities_page.dart';
import 'package:uniconnect/features/activities/providers/activity_provider.dart';
import 'package:uniconnect/features/auth/models/app_user.dart';
import 'package:uniconnect/features/auth/providers/auth_provider.dart';
import 'package:uniconnect/features/grades/models/subject_grade.dart';
import 'package:uniconnect/features/grades/presentation/grades_page.dart';
import 'package:uniconnect/features/grades/providers/grades_provider.dart';
import 'package:uniconnect/features/profile/presentation/profile_page.dart';
import 'package:uniconnect/features/student/presentation/student_dashboard_page.dart';
import 'package:uniconnect/features/teacher/presentation/create_activity_page.dart';
import 'package:uniconnect/features/teacher/presentation/teacher_dashboard_page.dart';
import 'package:uniconnect/features/teacher/presentation/teacher_grades_page.dart';
import 'package:uniconnect/shared/widgets/app_card.dart';
import 'package:uniconnect/shared/widgets/bottom_nav.dart';
import 'package:uniconnect/shared/widgets/section_header.dart';

import 'demo_day_test.dart' show demoActivity;
import 'fakes/fake_auth_service.dart';
import 'fakes/fake_session_storage.dart';

Finder get verticalScroll => find
    .byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
    .first;

Future<GlobalKey> pumpLayout(WidgetTester tester, Widget page,
    {double width = 390,
    double height = 900,
    double scale = 1,
    bool teacher = false,
    bool longText = false}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final source = teacher ? fakeTeacher : fakeStudent;
  final user = longText
      ? AppUser(
          id: source.id,
          name: List.filled(4, source.name).join(' '),
          email: source.email,
          role: source.role,
          tenant: source.tenant,
          course: List.filled(4, 'Engenharia de Software').join(' '),
        )
      : source;
  final key = GlobalKey();
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    retry: (_, __) => null,
    overrides: [
      currentUserProvider.overrideWithValue(user),
      sessionStorageProvider.overrideWithValue(FakeSessionStorage()),
      activitiesProvider.overrideWith((ref) async => [demoActivity]),
      subjectGradesProvider.overrideWith((ref) async => const [
            SubjectGrade(
                activityId: 'activity-1',
                subject: 'Pesquisa aplicada',
                code: 'ATV001',
                teacher: '',
                p1: 8.5,
                p2: 8.5,
                work: 8.5,
                status: ''),
          ]),
    ],
    child: RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!),
          home: page,
        )),
  ));
  await tester.pumpAndSettle();
  return key;
}

Future<void> captureLayout(
    WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_LAYOUT')) return;
  await tester.runAsync(() async {
    final render =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final frame = await render.toImage(pixelRatio: 1);
    final bytes = await frame.toByteData(format: ui.ImageByteFormat.png);
    const stage = String.fromEnvironment('LAYOUT_STAGE', defaultValue: 'after');
    final output = File('build/layout-qa/$stage/$name.png');
    await output.parent.create(recursive: true);
    await output.writeAsBytes(bytes!.buffer.asUint8List());
    frame.dispose();
  });
}

void main() {
  setUpAll(() async {
    await (FontLoader('Inter')
          ..addFont(rootBundle.load('assets/fonts/Inter/Inter-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Inter/Inter-Medium.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Inter/Inter-Bold.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });

  testWidgets('short content cards occupy the available column width',
      (tester) async {
    await pumpLayout(
        tester,
        const Scaffold(
            body: Center(
                child: SizedBox(
          width: 280,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AppCard(child: Text('UniConnect')),
          ]),
        ))));
    expect(tester.getSize(find.byType(AppCard)).width, closeTo(280, .5));
  });

  testWidgets(
      'teacher card rows share edges and align action icons with descriptions',
      (tester) async {
    final key = await pumpLayout(tester, const TeacherDashboardPage(),
        width: 768, teacher: true);
    await tester.scrollUntilVisible(
        find.text('Turmas e disciplinas').hitTestable(), 200,
        scrollable: verticalScroll);
    await captureLayout(tester, key, 'teacher-workspace-768');
    final titles = [
      'Turmas e disciplinas',
      'Atividades acadêmicas',
      'Lançamento de notas',
      'Comunicação com alunos'
    ];
    final cards = [
      for (final title in titles)
        find
            .ancestor(of: find.text(title), matching: find.byType(AppCard))
            .first
    ];
    final rects = [for (final card in cards) tester.getRect(card)];
    expect(rects[0].top, closeTo(rects[1].top, .5));
    expect(rects[0].bottom, closeTo(rects[1].bottom, .5));
    expect(rects[2].top, closeTo(rects[3].top, .5));
    expect(rects[2].bottom, closeTo(rects[3].bottom, .5));
    expect(rects[0].width, closeTo(rects[1].width, .5));
    final description =
        find.textContaining('Conheça o formulário demonstrativo.');
    final actionIcon = find.descendant(
        of: cards[1], matching: find.byIcon(Icons.visibility_outlined));
    expect(tester.getRect(actionIcon).left,
        closeTo(tester.getRect(description).left, .5));
    final headerIcon = find.descendant(
        of: cards[0], matching: find.byIcon(Icons.groups_outlined));
    expect(tester.getRect(headerIcon).center.dy,
        closeTo(tester.getRect(find.text(titles[0])).center.dy, .5));
  });

  testWidgets(
      'teacher grade table announces scrolling and exposes the last column',
      (tester) async {
    final key = await pumpLayout(tester, const TeacherGradesPage(),
        width: 320, scale: 2, teacher: true);
    await tester.scrollUntilVisible(find.byType(Scrollbar).hitTestable(), 200,
        scrollable: verticalScroll);
    await captureLayout(tester, key, 'teacher-table-320-text200');
    expect(find.text('Deslize para ver todas as colunas'), findsOneWidget);
    final horizontal = find.byWidgetPredicate((w) =>
        w is SingleChildScrollView && w.scrollDirection == Axis.horizontal);
    expect(horizontal, findsOneWidget);
    await tester.drag(horizontal, const Offset(-2400, 0));
    await tester.pumpAndSettle();
    final status = tester.renderObject<RenderParagraph>(find.text('STATUS'));
    final boxes = status.getBoxesForSelection(
        const TextSelection(baseOffset: 0, extentOffset: 6));
    expect(boxes, isNotEmpty);
    for (final box in boxes) {
      expect(status.localToGlobal(Offset(box.left, box.top)).dx,
          greaterThanOrEqualTo(0));
      expect(status.localToGlobal(Offset(box.right, box.bottom)).dx,
          lessThanOrEqualTo(320));
    }
    for (final label in ['CURSANDO', 'ALERTA', 'APROVADO']) {
      for (final element in find.text(label).evaluate()) {
        final paragraph = element.renderObject! as RenderParagraph;
        final boxes = paragraph.getBoxesForSelection(
            TextSelection(baseOffset: 0, extentOffset: label.length));
        expect(paragraph.didExceedMaxLines, isFalse);
        for (final box in boxes) {
          expect(paragraph.localToGlobal(Offset(box.left, box.top)).dx,
              greaterThanOrEqualTo(0),
              reason: label);
          expect(paragraph.localToGlobal(Offset(box.right, box.bottom)).dx,
              lessThanOrEqualTo(320),
              reason: label);
        }
      }
    }
    expect(tester.takeException(), isNull);
    await captureLayout(tester, key, 'teacher-table-last-column-320-text200');
  });

  testWidgets(
      'profile settings remain scrollable with large text on a short screen',
      (tester) async {
    final key = await pumpLayout(tester, const ProfilePage(),
        width: 320, height: 560, scale: 2);
    await tester.scrollUntilVisible(
        find.text('Configurações').hitTestable(), 200,
        scrollable: verticalScroll);
    await tester.tap(find.text('Configurações'));
    await tester.pumpAndSettle();
    await captureLayout(tester, key, 'profile-settings-320-text200');
    expect(tester.takeException(), isNull);
    final sheetScroll = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down));
    expect(sheetScroll, findsOneWidget);
    await tester.scrollUntilVisible(find.text('Concluir').hitTestable(), 100,
        scrollable: sheetScroll);
    expect(tester.getRect(find.text('Concluir')).bottom, lessThan(560));
    await tester.tap(find.text('Concluir'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('long section headings retain their width beside an action',
      (tester) async {
    await pumpLayout(
        tester,
        Scaffold(
            body: Padding(
                padding: const EdgeInsets.all(24),
                child: SectionHeader(
                    title: 'Atividades acadêmicas e próximos prazos',
                    actionLabel: 'Ver todas',
                    onAction: () {}))),
        width: 320,
        scale: 2);
    final heading =
        tester.getRect(find.text('Atividades acadêmicas e próximos prazos'));
    expect(heading.width, greaterThanOrEqualTo(240));
    expect(tester.takeException(), isNull);
  });

  testWidgets('navigation icons share a baseline with enlarged text on 320 px',
      (tester) async {
    for (var index = 0; index < 5; index++) {
      final key = await pumpLayout(tester,
          Scaffold(bottomNavigationBar: UniBottomNav(currentIndex: index)),
          width: 320, scale: 2);
      final icons = find.descendant(
          of: find.byType(NavigationBar), matching: find.byType(Icon));
      final centers = [
        for (final icon in icons.evaluate())
          tester
              .getRect(find.byElementPredicate((element) => element == icon))
              .center
              .dy
      ];
      expect(centers.length, 5);
      for (final center in centers) {
        expect(center, closeTo(centers.first, .5),
            reason: 'selected index $index');
      }
      for (final label in find
          .descendant(
              of: find.byType(NavigationBar), matching: find.byType(Text))
          .evaluate()) {
        final paragraph = label.renderObject! as RenderParagraph;
        final boxes = paragraph.getBoxesForSelection(TextSelection(
            baseOffset: 0, extentOffset: paragraph.text.toPlainText().length));
        expect(boxes.map((box) => box.top).toSet().length, 1,
            reason: 'selected index $index');
      }
      await captureLayout(tester, key, 'navigation-320-text200-index$index');
    }
  });

  testWidgets('prototype field labels wrap fully and field widths remain equal',
      (tester) async {
    await pumpLayout(tester, const CreateActivityPage(),
        width: 320, scale: 2, teacher: true);
    final widths = <double>[];
    for (final label in [
      'Selecione a Disciplina',
      'Título da Atividade',
      'Descrição e Instruções',
      'Data de Entrega',
      'Valor da Atividade (Pontos)'
    ]) {
      await tester.scrollUntilVisible(find.text(label).hitTestable(), 180,
          scrollable: verticalScroll);
      final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
      expect(paragraph.didExceedMaxLines, isFalse, reason: label);
    }
    for (final field in find.byType(TextField).evaluate()) {
      widths.add(tester
          .getSize(find.byElementPredicate((element) => element == field))
          .width);
    }
    expect(widths.length, 5);
    for (final width in widths) {
      expect(width, closeTo(widths.first, .5));
    }
    expect(
        tester
            .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Publicar Atividade'))
            .onPressed,
        isNull);
  });

  for (final width in [320.0, 360.0, 390.0, 430.0, 768.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets(
          'cards and navigation remain inside $width px at text scale $scale',
          (tester) async {
        final pages = <String, Widget>{
          'student': const StudentDashboardPage(),
          'activities': const ActivitiesPage(),
          'grades': const GradesPage(),
          'teacher': const TeacherDashboardPage(),
          'teacher-create': const CreateActivityPage(),
          'teacher-grades': const TeacherGradesPage(),
          'profile': const ProfilePage(),
        };
        for (final entry in pages.entries) {
          final key = await pumpLayout(tester, entry.value,
              width: width,
              scale: scale,
              teacher: entry.key.startsWith('teacher'),
              longText: true);
          if ((width == 320 || width == 390 || width == 768) && scale != 1.5) {
            await captureLayout(tester, key,
                '${entry.key}-${width.toInt()}-text${(scale * 100).toInt()}');
          }
          expect(tester.takeException(), isNull,
              reason: '${entry.key} at $width / $scale');
          final scroll = find.byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down);
          if (scroll.evaluate().isNotEmpty) {
            await tester.drag(scroll.first, const Offset(0, -1600));
            await tester.pumpAndSettle();
          }
          if (entry.key == 'grades') {
            await tester.scrollUntilVisible(
                find.text('Média prevista: 0.0').hitTestable(), 200,
                scrollable: verticalScroll);
            for (final label in ['P1', 'P2', 'Trab.']) {
              final paragraph =
                  tester.renderObject<RenderParagraph>(find.text(label));
              expect(paragraph.didExceedMaxLines, isFalse,
                  reason: '$label at $width / $scale');
            }
            await tester.ensureVisible(find.text('Média prevista: 0.0'));
            await tester.pumpAndSettle();
            final result = tester.getRect(find.text('Média prevista: 0.0'));
            expect(
                result.bottom,
                lessThanOrEqualTo(
                    tester.getRect(find.byType(NavigationBar)).top));
          }
          for (final element in find.byType(AppCard).evaluate()) {
            final card =
                find.byElementPredicate((candidate) => candidate == element);
            final insideHorizontal = find.ancestor(
                of: card,
                matching: find.byWidgetPredicate((w) =>
                    w is SingleChildScrollView &&
                    w.scrollDirection == Axis.horizontal));
            if (insideHorizontal.evaluate().isNotEmpty) continue;
            final rect = tester.getRect(card);
            expect(rect.left, greaterThanOrEqualTo(0), reason: entry.key);
            expect(rect.right, lessThanOrEqualTo(width + .5),
                reason: entry.key);
          }
          final nav = find.byType(NavigationBar);
          if (nav.evaluate().isNotEmpty) {
            final navRect = tester.getRect(nav);
            final labels =
                find.descendant(of: nav, matching: find.byType(Text));
            for (final label in labels.evaluate()) {
              final rect = tester.getRect(
                  find.byElementPredicate((candidate) => candidate == label));
              expect(rect.left, greaterThanOrEqualTo(0));
              expect(rect.right, lessThanOrEqualTo(width + .5));
              expect(rect.bottom, lessThanOrEqualTo(navRect.bottom + .5));
            }
          }
          if ((width == 320 || width == 390 || width == 768) && scale != 1.5) {
            await captureLayout(tester, key,
                '${entry.key}-${width.toInt()}-text${(scale * 100).toInt()}-scrolled');
          }
          expect(tester.takeException(), isNull,
              reason: '${entry.key} after scrolling');
        }
      });
    }
  }
}
