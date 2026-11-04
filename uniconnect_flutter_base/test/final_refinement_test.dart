import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniconnect/features/activities/models/academic_activity.dart';
import 'package:uniconnect/features/activities/presentation/activities_page.dart';
import 'package:uniconnect/features/activities/providers/activity_provider.dart';
import 'package:uniconnect/features/grades/models/subject_grade.dart';
import 'package:uniconnect/features/grades/providers/grades_provider.dart';
import 'package:uniconnect/features/student/presentation/student_dashboard_page.dart';
import 'package:uniconnect/features/teacher/presentation/teacher_dashboard_page.dart';
import 'package:uniconnect/features/chat/presentation/chat_page.dart';

import 'demo_day_test.dart' show pumpDemoPage;
import 'fakes/fake_auth_service.dart';

AcademicActivity activity(String id, String title, DateTime? dueDate) =>
    AcademicActivity(
      id: id,
      subject: 'Métodos Quantitativos',
      title: title,
      description: '',
      dueDate: dueDate,
      teacher: 'Professor da turma',
      status: ActivityStatus.pending,
      criteria: const [],
      attachments: const [],
    );

const grades = [
  SubjectGrade(
    subject: 'Avaliação A',
    code: 'A',
    teacher: '',
    grade: 8,
  ),
  SubjectGrade(
    subject: 'Avaliação B',
    code: 'B',
    teacher: '',
    grade: 6,
  ),
];

void main() {
  testWidgets(
      'student panorama calculates metrics and separates deadline situations',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final now = DateTime.now();
    final items = [
      activity(
          'past', 'Avaliação encerrada', now.subtract(const Duration(days: 2))),
      activity('soon', 'Avaliação próxima', now.add(const Duration(hours: 3))),
      activity('future', 'Avaliação futura', now.add(const Duration(days: 5))),
      activity('undated', 'Pesquisa sem prazo', null),
    ];
    await pumpDemoPage(tester, const StudentDashboardPage(), overrides: [
      activitiesProvider.overrideWith((ref) async => items),
      subjectGradesProvider.overrideWith((ref) async => grades),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Média simples'), findsNothing);
    expect(find.text('7.0'), findsNothing);
    expect(find.bySemanticsLabel('Atividades disponíveis: 4'), findsOneWidget);
    expect(
        find.bySemanticsLabel('Disciplinas nas atividades: 1'), findsOneWidget);
    semantics.dispose();
    await tester.scrollUntilVisible(find.text('Quadro de prazos'), 250,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Prazo próximo (24h)'), findsOneWidget);
    expect(find.text('Prazo encerrado'), findsWidgets);
    expect(find.text('Sem prazo informado'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Avaliação encerrada'), 250,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Atividades acadêmicas'), findsOneWidget);
    expect(find.text('Atividades Pendentes'), findsNothing);
    expect(find.text('GPA'), findsNothing);
  });

  testWidgets(
      'failed grade request is not turned into a zero in student panorama',
      (tester) async {
    await pumpDemoPage(tester, const StudentDashboardPage(), overrides: [
      activitiesProvider.overrideWith((ref) async => []),
      subjectGradesProvider
          .overrideWith((ref) async => throw Exception('offline')),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Notas indisponíveis'), findsOneWidget);
    expect(find.text('0.0'), findsNothing);
    expect(find.text('Ver notas'), findsOneWidget);
  });

  testWidgets(
      'teacher workspace exposes offer-scoped shortcuts without invented metrics',
      (tester) async {
    await pumpDemoPage(tester, const TeacherDashboardPage(), user: fakeTeacher);
    await tester.scrollUntilVisible(find.text('Turmas e disciplinas'), 250,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Turmas e disciplinas'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Ver trabalhos e entregas'), 150,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Ver trabalhos e entregas'), findsOneWidget);
    expect(
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Criar atividade')).onPressed,
        isNull);
    expect(find.text('Aguardando correção na consulta: 0'), findsNothing);
    expect(find.text('128'), findsNothing);
  });

  testWidgets('expired academic work is grouped separately from future urgency',
      (tester) async {
    await pumpDemoPage(tester, const ActivitiesPage(), overrides: [
      activitiesProvider.overrideWith((ref) async => [
            activity('past', 'Avaliação encerrada',
                DateTime.now().subtract(const Duration(days: 2))),
          ]),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Prazo encerrado (1)'), findsOneWidget);
    expect(find.text('Críticas (1)'), findsNothing);
    expect(find.text('EXPIRADA'), findsOneWidget);
  });

  testWidgets(
      'illustrative chat retains its appearance without enabling sending',
      (tester) async {
    await pumpDemoPage(tester, const ChatPage());
    expect(find.textContaining('Dados de demonstração'), findsOneWidget);
    expect(find.text('ONLINE AGORA'), findsNothing);
    expect(
        tester
            .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.send))
            .onPressed,
        isNull);
    expect(
        tester
            .widget<IconButton>(
                find.widgetWithIcon(IconButton, Icons.attach_file))
            .onPressed,
        isNull);
    expect(
        tester
            .widgetList<TextField>(find.byType(TextField))
            .every((field) => field.enabled == false),
        isTrue);
  });

}
