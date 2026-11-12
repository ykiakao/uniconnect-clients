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
import 'package:uniconnect/features/teacher/widgets/activity_type_field.dart';

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
              grade: 8.5,
            ),
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

  testWidgets('teacher shortcuts stay inside the content at wide widths',
      (tester) async {
    final key = await pumpLayout(tester, const TeacherDashboardPage(),
        width: 768, teacher: true);
    await tester.scrollUntilVisible(
        find.text('Avisos da turma').hitTestable(), 200,
        scrollable: verticalScroll);
    await captureLayout(tester, key, 'teacher-workspace-768');
    final shortcuts = [
      for (final label in [
        'Criar atividade',
        'Avaliar entregas',
        'Consultar notas',
        'Avisos da turma',
      ])
        find.ancestor(of: find.text(label), matching: find.byType(InkWell)),
    ];
    for (final target in shortcuts) {
      final rect = tester.getRect(target);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(768));
      expect(rect.height, greaterThanOrEqualTo(40));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'teacher review controls remain inside narrow view without synthetic grades',
      (tester) async {
    final key = await pumpLayout(tester, const TeacherGradesPage(),
        width: 320, scale: 2, teacher: true);
    expect(find.text('Disciplina'), findsOneWidget);
    expect(find.text('P1'), findsNothing);
    expect(find.text('APROVADO'), findsNothing);
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    expect(tester.takeException(), isNull);
    await captureLayout(tester, key, 'teacher-reviews-320-text200');
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

  testWidgets(
      'teacher form fields retain equal widths and unavailable session cannot save',
      (tester) async {
    await pumpLayout(tester, const CreateActivityPage(),
        width: 320, scale: 2, teacher: true);
    final widths = <double>[];
    for (final field in [
      ...find.byType(TextField).evaluate(),
      ...find.byType(ActivityTypeField).evaluate(),
    ]) {
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
                find.widgetWithText(ElevatedButton, 'Salvar rascunho'))
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
