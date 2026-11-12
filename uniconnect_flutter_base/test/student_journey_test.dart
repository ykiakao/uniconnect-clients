import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniconnect/features/activities/models/academic_activity.dart';
import 'package:uniconnect/features/activities/presentation/activities_page.dart';
import 'package:uniconnect/features/activities/providers/activity_provider.dart';
import 'package:uniconnect/features/activities/providers/student_submission_provider.dart';
import 'package:uniconnect/features/activities/services/student_submission_service.dart';
import 'package:uniconnect/features/auth/models/app_user.dart';
import 'package:uniconnect/features/grades/providers/grades_provider.dart';
import 'package:uniconnect/features/student/presentation/student_academic_page.dart';
import 'package:uniconnect/features/student/presentation/student_dashboard_page.dart';

import 'demo_day_test.dart' show pumpDemoPage;
import 'fakes/fake_auth_service.dart';

AcademicActivity _activity(
  String id,
  String title,
  String subject,
  DateTime? dueDate, {
  String state = 'published',
  bool workflow = true,
}) =>
    AcademicActivity(
      id: id,
      title: title,
      subject: subject,
      dueDate: dueDate,
      publicationState: state,
      workflowEnabled: workflow,
      description: '',
      teacher: '',
      status: ActivityStatus.pending,
      criteria: const [],
      attachments: const [],
    );

void main() {
  testWidgets(
      'Academic shows missing session fields and unavailable integrations',
      (tester) async {
    await pumpDemoPage(tester, const StudentAcademicPage());
    expect(find.text('Instituição: Instituicao Teste'), findsOneWidget);
    expect(find.text('Matrícula: Não informado'), findsOneWidget);
    expect(find.text('Curso: Não informado'), findsOneWidget);
    expect(find.text('Semestre do curso: Não informado'), findsOneWidget);
    expect(find.text('Horários e calendário acadêmico ainda indisponíveis.'),
        findsOneWidget);
    expect(find.byTooltip('Meu perfil'), findsOneWidget);
  });

  testWidgets('Academic displays real institutional fields from the session',
      (tester) async {
    await pumpDemoPage(
      tester,
      const StudentAcademicPage(),
      user: const AppUser(
        id: 'student-enrolled',
        name: 'Ana',
        email: 'ana@example.invalid',
        role: UserRole.student,
        tenant: fakeTenant,
        registration: '202601',
        course: 'Sistemas de Informação',
        semester: 2,
      ),
    );
    expect(find.text('Matrícula: 202601'), findsOneWidget);
    expect(find.text('Curso: Sistemas de Informação'), findsOneWidget);
    expect(find.text('Semestre do curso: 2º semestre'), findsOneWidget);
  });

  testWidgets(
      'Home verifies pending receipts and treats lookup failure as unknown',
      (tester) async {
    final now = DateTime(2026, 11, 4);
    final tomorrow = now.add(const Duration(days: 1));
    final checks = <String>{};
    var failed = true;
    await pumpDemoPage(tester, const StudentDashboardPage(), overrides: [
      activityClockProvider.overrideWithValue(now),
      subjectGradesProvider.overrideWith((ref) async => []),
      activitiesProvider.overrideWith((ref) async => [
            _activity('pending', 'Trabalho sem entrega', 'Cálculo', tomorrow),
            _activity('sent', 'Trabalho entregue', 'Cálculo', tomorrow),
            _activity('unknown', 'Trabalho sem consulta', 'Cálculo', tomorrow),
            _activity('closed', 'Trabalho encerrado', 'Cálculo', tomorrow,
                state: 'closed'),
            _activity('legacy', 'Trabalho legado', 'Cálculo', tomorrow,
                workflow: false),
          ]),
      ownSubmissionProvider.overrideWith((ref, id) async {
        checks.add(id);
        if (id == 'pending' || (id == 'unknown' && !failed)) return null;
        if (id == 'unknown') throw StateError('offline');
        return StudentSubmission(
            id: 'receipt',
            activityId: id,
            version: 1,
            answer: 'Resposta',
            submittedAt: now,
            isLate: false,
            status: 'submitted');
      }),
    ]);
    await tester.scrollUntilVisible(
        find.text('Algumas entregas não puderam ser consultadas'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(checks, {'pending', 'sent', 'unknown'});
    expect(find.text('Nenhuma pendência nas atividades consultadas.'),
        findsNothing);
    failed = false;
    tester
        .widget<TextButton>(find.widgetWithText(TextButton, 'Tentar novamente'))
        .onPressed!();
    await tester.pumpAndSettle();
    expect(find.text('Algumas entregas não puderam ser consultadas'),
        findsNothing);
    expect(find.text('Trabalho sem consulta'), findsWidgets);
    expect(find.text('Entregas pendentes'), findsOneWidget);
  });

  testWidgets(
      'search combines with deadline, discipline and publication filters',
      (tester) async {
    final now = DateTime(2026, 11, 4);
    final tomorrow = now.add(const Duration(days: 1));
    await pumpDemoPage(tester, const ActivitiesPage(), overrides: [
      activityClockProvider.overrideWithValue(now),
      activitiesProvider.overrideWith((ref) async => [
            _activity('a', 'Pesquisa de História', 'História', tomorrow),
            _activity('b', 'Pesquisa de Cálculo', 'Cálculo', tomorrow),
            _activity('c', 'Pesquisa antiga', 'História', tomorrow,
                state: 'closed'),
            _activity('d', 'Pesquisa atrasada', 'História',
                now.subtract(const Duration(days: 1))),
            _activity('e', 'Exercício de História', 'História', tomorrow),
          ]),
    ]);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Pesquisa');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Críticas').first);
    await tester.tap(find.text('Mais filtros'));
    await tester.pumpAndSettle();
    final selectors = find.byType(DropdownButtonFormField<String>);
    Future<void> select(int index, String label) async {
      await tester.ensureVisible(selectors.at(index));
      await tester.tap(selectors.at(index));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    await select(0, 'História');
    await select(1, 'Publicada');
    expect(find.text('Exibindo 1 de 5 atividade(s)'), findsOneWidget);
    expect(find.text('Pesquisa de História'), findsOneWidget);
    expect(find.text('Pesquisa de Cálculo'), findsNothing);
    // The selectors scrolled the list; bring the search field back first.
    await tester.ensureVisible(find.byType(TextField, skipOffstage: false));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'sem correspondência');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Limpar filtros'));
    // ensureVisible scrolls without a frame; settle before tapping.
    await tester.pumpAndSettle();
    await tester.tap(find.text('Limpar filtros'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.textContaining('Exibindo'));
    await tester.pumpAndSettle();
    expect(find.text('Exibindo 5 de 5 atividade(s)'), findsOneWidget);
  });
}
