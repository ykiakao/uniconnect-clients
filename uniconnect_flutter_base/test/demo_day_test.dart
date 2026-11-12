import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniconnect/core/theme/app_theme.dart';
import 'package:uniconnect/features/activities/models/academic_activity.dart';
import 'package:uniconnect/features/activities/presentation/activities_page.dart';
import 'package:uniconnect/features/activities/providers/activity_provider.dart';
import 'package:uniconnect/features/auth/providers/auth_provider.dart';
import 'package:uniconnect/features/auth/models/app_user.dart';
import 'package:uniconnect/features/profile/presentation/profile_page.dart';
import 'package:uniconnect/features/student/presentation/student_dashboard_page.dart';
import 'package:uniconnect/features/teacher/presentation/create_activity_page.dart';
import 'package:uniconnect/features/teacher/presentation/teacher_dashboard_page.dart';
import 'package:uniconnect/features/teacher/presentation/teacher_grades_page.dart';

import 'fakes/fake_auth_service.dart';
import 'fakes/fake_session_storage.dart';

final demoActivity = AcademicActivity(
  id: 'activity-1',
  subject: 'Métodos Quantitativos',
  title: 'Pesquisa aplicada',
  description: 'Analise os dados disponibilizados para a turma.',
  dueDate: DateTime.now().add(const Duration(days: 3)),
  teacher: 'Profa. Ana Lima',
  status: ActivityStatus.pending,
  criteria: const [],
  attachments: const [],
);

Future<void> pumpDemoPage(
  WidgetTester tester,
  Widget page, {
  List<Override> overrides = const [],
  AppUser user = fakeStudent,
}) async {
  tester.view.physicalSize = const Size(375, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, __) => null,
      overrides: [
        sessionStorageProvider.overrideWithValue(FakeSessionStorage()),
        currentUserProvider.overrideWithValue(user),
        ...overrides,
      ],
      child: MaterialApp(theme: AppTheme.lightTheme, home: page),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('unknown deadlines do not appear as low priority',
      (tester) async {
    final undated = AcademicActivity(
      id: 'undated',
      subject: 'Métodos',
      title: 'Pesquisa sem prazo',
      description: '',
      dueDate: null,
      teacher: 'Professor da turma',
      status: ActivityStatus.pending,
      criteria: const [],
      attachments: const [],
    );
    await pumpDemoPage(tester, const ActivitiesPage(), overrides: [
      activitiesProvider.overrideWith((ref) async => [undated]),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Prazo não informado (1)'), findsOneWidget);
    expect(find.text('Baixa prioridade (1)'), findsNothing);
    await tester.ensureVisible(find.text('Baixas'));
    await tester.tap(find.text('Baixas'));
    await tester.pumpAndSettle();
    expect(find.text('Pesquisa sem prazo'), findsNothing);
  });
  testWidgets('priority filter moves activities when the clock advances',
      (tester) async {
    var now = demoActivity.dueDate!.subtract(
      const Duration(days: 3, seconds: 1),
    );
    await pumpDemoPage(tester, const ActivitiesPage(), overrides: [
      activitiesProvider.overrideWith((ref) async => [demoActivity]),
      activityClockProvider.overrideWith((ref) => now),
    ]);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Médias'));
    await tester.tap(find.text('Médias'));
    await tester.pumpAndSettle();
    expect(find.text('Pesquisa aplicada'), findsOneWidget);
    expect(find.text('Média'), findsOneWidget);

    now = now.add(const Duration(seconds: 1));
    ProviderScope.containerOf(tester.element(find.byType(ActivitiesPage)))
        .invalidate(activityClockProvider);
    await tester.pumpAndSettle();
    expect(find.text('Pesquisa aplicada'), findsNothing);
    await tester.ensureVisible(find.text('Críticas'));
    await tester.tap(find.text('Críticas'));
    await tester.pumpAndSettle();
    expect(find.text('Pesquisa aplicada'), findsOneWidget);
    expect(find.text('Crítica'), findsOneWidget);
  });
  testWidgets('student dashboard uses session and API agenda without fixed GPA',
      (tester) async {
    await pumpDemoPage(tester, const StudentDashboardPage(), overrides: [
      activitiesProvider.overrideWith((ref) async => [demoActivity]),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Aluno'), findsOneWidget);
    expect(find.text('8.7'), findsNothing);
    expect(find.text(fakeTenant.name), findsOneWidget);
    expect(find.text('Entrega Projeto Final - IA'), findsNothing);
    expect(find.text('Ver notas'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Pesquisa aplicada'), 180,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Pesquisa aplicada'), findsOneWidget);
  });

  testWidgets('student dashboard explains empty agenda', (tester) async {
    await pumpDemoPage(tester, const StudentDashboardPage(), overrides: [
      activitiesProvider.overrideWith((ref) async => []),
    ]);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Nenhuma atividade disponível'), 180,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Nenhuma atividade disponível'), findsOneWidget);
    expect(find.text('Segurança Digital'), findsNothing);
  });

  testWidgets('student dashboard keeps loading distinct from empty',
      (tester) async {
    final pending = Completer<List<AcademicActivity>>();
    await pumpDemoPage(tester, const StudentDashboardPage(), overrides: [
      activitiesProvider.overrideWith((ref) => pending.future),
    ]);
    expect(find.text('Carregando atividades...'), findsOneWidget);
    expect(find.text('Nenhuma atividade disponível'), findsNothing);
  });

  testWidgets('student dashboard retries failed academic request',
      (tester) async {
    var requests = 0;
    await pumpDemoPage(tester, const StudentDashboardPage(), overrides: [
      activitiesProvider.overrideWith((ref) async {
        if (requests++ == 0) throw Exception('API indisponível');
        return [demoActivity];
      }),
    ]);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.text('Tentar novamente').hitTestable(), 150,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.text('Pesquisa aplicada').hitTestable(), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Pesquisa aplicada'), findsOneWidget);
    expect(requests, 2);
  });

  testWidgets('teacher explains missing academic links and offers real profile',
      (tester) async {
    await pumpDemoPage(tester, const TeacherDashboardPage(), user: fakeTeacher);
    expect(find.text('Professor Teste'), findsOneWidget);
    expect(find.byTooltip('Meu perfil'), findsOneWidget);
    expect(find.text('Vínculo acadêmico não informado'), findsOneWidget);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -1800));
    await tester.pumpAndSettle();
    expect(find.text('Sobre este ambiente'), findsNothing);
    expect(find.textContaining('A gestão docente de turmas'), findsNothing);
    expect(find.text('Ver trabalhos e entregas'), findsOneWidget);
  });

  testWidgets('profile does not invent missing academic data', (tester) async {
    await pumpDemoPage(tester, const ProfilePage());
    expect(find.text('Engenharia de Software'), findsNothing);
    expect(find.text('2024021845'), findsNothing);
    expect(find.text('Não informado'), findsNWidgets(3));
  });

  testWidgets('student cannot access teacher activity creation',
      (tester) async {
    await pumpDemoPage(tester, const CreateActivityPage());
    expect(find.text('Área exclusiva do professor'), findsOneWidget);
    expect(find.text('Salvar rascunho'), findsNothing);
  });

  testWidgets('student cannot access teacher reviews', (tester) async {
    await pumpDemoPage(tester, const TeacherGradesPage());
    expect(find.text('Área exclusiva do professor'), findsOneWidget);
    expect(find.text('Publicar avaliação'), findsNothing);
  });
}
