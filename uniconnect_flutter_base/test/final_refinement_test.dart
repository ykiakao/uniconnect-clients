import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniconnect/features/activities/models/academic_activity.dart';
import 'package:uniconnect/features/activities/presentation/activities_page.dart';
import 'package:uniconnect/features/activities/providers/activity_provider.dart';
import 'package:uniconnect/features/grades/models/subject_grade.dart';
import 'package:uniconnect/features/grades/presentation/grades_page.dart';
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
      dueLabel: dueDate == null ? 'Prazo não informado' : 'Prazo da avaliação',
      dueDate: dueDate,
      teacher: 'Professor da turma',
      priority: ActivityPriority.critical,
      status: ActivityStatus.pending,
      criteria: const [],
      attachments: const [],
    );

const grades = [
  SubjectGrade(
      subject: 'Avaliação A',
      code: 'A',
      teacher: '',
      p1: 8,
      p2: 8,
      work: 8,
      status: ''),
  SubjectGrade(
      subject: 'Avaliação B',
      code: 'B',
      teacher: '',
      p1: 6,
      p2: 6,
      work: 6,
      status: ''),
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
    expect(find.text('Média simples'), findsOneWidget);
    expect(find.text('7.0'), findsOneWidget);
    expect(find.bySemanticsLabel('Atividades disponíveis: 4'), findsOneWidget);
    expect(
        find.bySemanticsLabel('Disciplinas nas atividades: 1'), findsOneWidget);
    semantics.dispose();
    await tester.scrollUntilVisible(find.text('Quadro de prazos'), 250,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Prazo próximo (24h)'), findsOneWidget);
    expect(find.text('Prazo encerrado'), findsOneWidget);
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
    expect(find.text('Média indisponível'), findsOneWidget);
    expect(find.text('0.0'), findsNothing);
    expect(find.text('Ver notas'), findsOneWidget);
  });

  testWidgets(
      'teacher workspace exposes existing prototypes with explicit limits',
      (tester) async {
    await pumpDemoPage(tester, const TeacherDashboardPage(), user: fakeTeacher);
    await tester.scrollUntilVisible(find.text('Turmas e disciplinas'), 250,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Turmas e disciplinas'), findsOneWidget);
    expect(find.text('Atividades acadêmicas'), findsOneWidget);
    expect(find.text('Lançamento de notas'), findsOneWidget);
    expect(find.text('Comunicação com alunos'), findsOneWidget);
    expect(find.text('Ver protótipo'), findsNWidgets(2));
    expect(find.text('Publicar atividade'), findsNothing);
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
    expect(find.text('Encerrado'), findsOneWidget);
  });

  testWidgets(
      'grades retain mean and evaluation count without official coefficient',
      (tester) async {
    await pumpDemoPage(tester, const GradesPage(), overrides: [
      subjectGradesProvider.overrideWith((ref) async => grades),
      activitiesProvider.overrideWith((ref) async => []),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('7.0'), findsOneWidget);
    expect(find.text('2 avaliações disponíveis'), findsOneWidget);
    expect(find.textContaining('coeficiente oficial'), findsOneWidget);
    expect(find.text('APROVADO'), findsNothing);
  });

  testWidgets(
      'grades show API feedback and only identify a discipline through its exact activity ID',
      (tester) async {
    await pumpDemoPage(tester, const GradesPage(), overrides: [
      subjectGradesProvider.overrideWith((ref) async => const [
            SubjectGrade(
                activityId: 'matched',
                feedback: 'Argumentação consistente.',
                subject: 'Pesquisa aplicada',
                code: 'A',
                teacher: '',
                p1: 8,
                p2: 8,
                work: 8,
                status: ''),
            SubjectGrade(
                activityId: 'missing',
                subject: 'Outra avaliação',
                code: 'B',
                teacher: '',
                p1: 6,
                p2: 6,
                work: 6,
                status: ''),
          ]),
      activitiesProvider.overrideWith(
          (ref) async => [activity('matched', 'Pesquisa aplicada', null)]),
    ]);
    await tester.pumpAndSettle();
    expect(
        find.text('Disciplina/turma: Métodos Quantitativos'), findsOneWidget);
    expect(find.text('Argumentação consistente.'), findsOneWidget);
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

  testWidgets(
      'refreshing grades also recovers discipline context after an activity API failure',
      (tester) async {
    var activityRequests = 0;
    await pumpDemoPage(tester, const GradesPage(), overrides: [
      subjectGradesProvider.overrideWith((ref) async => const [
            SubjectGrade(
                activityId: 'matched',
                subject: 'Pesquisa aplicada',
                code: 'A',
                teacher: '',
                p1: 8,
                p2: 8,
                work: 8,
                status: ''),
          ]),
      activitiesProvider.overrideWith((ref) async {
        if (activityRequests++ == 0) throw Exception('offline');
        return [activity('matched', 'Pesquisa aplicada', null)];
      }),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('8.0'), findsWidgets);
    expect(find.text('Disciplina/turma: Métodos Quantitativos'), findsNothing);
    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pumpAndSettle();
    expect(activityRequests, 2);
    expect(
        find.text('Disciplina/turma: Métodos Quantitativos'), findsOneWidget);
  });
}
