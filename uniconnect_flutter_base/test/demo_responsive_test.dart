import 'package:uniconnect/features/academic/demo/synthetic_academic_providers.dart';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniconnect/core/theme/app_theme.dart';
import 'package:uniconnect/features/activities/presentation/activities_page.dart';
import 'package:uniconnect/features/activities/presentation/activity_detail_page.dart';
import 'package:uniconnect/features/activities/providers/activity_provider.dart';
import 'package:uniconnect/features/auth/presentation/login_page.dart';
import 'package:uniconnect/features/auth/providers/auth_provider.dart';
import 'package:uniconnect/features/chat/presentation/chat_page.dart';
import 'package:uniconnect/features/grades/models/subject_grade.dart';
import 'package:uniconnect/features/grades/presentation/grades_page.dart';
import 'package:uniconnect/features/grades/providers/grades_provider.dart';
import 'package:uniconnect/features/profile/presentation/profile_page.dart';
import 'package:uniconnect/features/student/presentation/student_dashboard_page.dart';
import 'package:uniconnect/features/teacher/presentation/create_activity_page.dart';
import 'package:uniconnect/features/teacher/presentation/teacher_dashboard_page.dart';
import 'package:uniconnect/features/teacher/presentation/teacher_grades_page.dart';

import 'demo_day_test.dart' show demoActivity;
import 'fakes/fake_auth_service.dart';

void main() {
  testWidgets('API error remains usable on a short landscape screen',
      (tester) async {
    tester.view.physicalSize = const Size(640, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
      retry: (_, __) => null,
      overrides: [
        syntheticDemoRequestedProvider.overrideWithValue(false),
        activitiesProvider
            .overrideWith((ref) async => throw Exception('offline'))
      ],
      child:
          MaterialApp(theme: AppTheme.lightTheme, home: const ActivitiesPage()),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Tentar Novamente'));
    expect(find.text('Tentar Novamente'), findsOneWidget);
  });
  setUpAll(() async {
    final inter = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter/Inter-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Inter/Inter-Medium.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Inter/Inter-Bold.ttf'));
    await inter.load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });

  for (final width in [320.0, 375.0, 430.0, 768.0, 1024.0, 1440.0]) {
    for (final scale in width == 375 ? [1.0, 1.5] : [1.0]) {
      testWidgets('demo screens at width $width and text scale $scale',
          (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final pages = <String, Widget>{
          'login': const LoginPage(),
          'student': const StudentDashboardPage(),
          'teacher': const TeacherDashboardPage(),
          'activities': const ActivitiesPage(),
          'activity': const ActivityDetailPage(activityId: 'activity-1'),
          'grades': const GradesPage(),
          'profile': const ProfilePage(),
          'chat': const ChatPage(),
          'teacher-create': const CreateActivityPage(),
          'teacher-grades': const TeacherGradesPage(),
        };
        for (final entry in pages.entries) {
          final captureKey = GlobalKey();
          await tester.pumpWidget(ProviderScope(
            key: UniqueKey(),
            retry: (_, __) => null,
            overrides: [
              currentUserProvider.overrideWithValue(
                  entry.key.startsWith('teacher') ? fakeTeacher : fakeStudent),
              activitiesProvider.overrideWith((ref) async => [demoActivity]),
              subjectGradesProvider.overrideWith((ref) async => const [
                    SubjectGrade(
                      subject: 'Pesquisa aplicada',
                      code: 'ATV001',
                      teacher: 'Professor da turma',
                      p1: 8.5,
                      p2: 8.5,
                      work: 8.5,
                      status: 'Em curso',
                    ),
                  ]),
            ],
            child: RepaintBoundary(
              key: captureKey,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.lightTheme,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: entry.value,
              ),
            ),
          ));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull,
              reason: '${entry.key} at $width / $scale');
          if (const bool.fromEnvironment('CAPTURE_DEMO') &&
              (width == 375 || width == 1440) &&
              scale == 1) {
            await tester.runAsync(() async {
              final boundary = captureKey.currentContext!.findRenderObject()
                  as RenderRepaintBoundary;
              final screenshot = await boundary.toImage(pixelRatio: 1);
              final data =
                  await screenshot.toByteData(format: ui.ImageByteFormat.png);
              final file =
                  File('build/demo-day-qa/${entry.key}-${width.toInt()}.png');
              await file.parent.create(recursive: true);
              await file.writeAsBytes(data!.buffer.asUint8List());
              screenshot.dispose();
            });
          }
          final verticalScroll = find.byWidgetPredicate((widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down);
          if (verticalScroll.evaluate().isNotEmpty) {
            await tester.drag(verticalScroll.first, const Offset(0, -1800));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull,
                reason: '${entry.key} after scroll at $width / $scale');
          }
        }
      });
    }
  }
}
