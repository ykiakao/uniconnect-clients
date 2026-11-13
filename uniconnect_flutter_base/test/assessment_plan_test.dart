import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniconnect/features/teacher/services/teacher_assessment.dart';
import 'package:uniconnect/features/teacher/widgets/assessment_fields.dart';

const _plan = [
  TeacherAssessment(stage: 'N1', category: 'activity', maxPoints: '1.00'),
  TeacherAssessment(stage: 'N1', category: 'activity', maxPoints: '0.50'),
  TeacherAssessment(stage: 'N1', category: 'exam', maxPoints: '7.00'),
  TeacherAssessment(stage: 'N2', category: 'activity', maxPoints: '3.00'),
];

Future<GlobalKey<FormState>> _pump(WidgetTester tester,
    {List<TeacherAssessment>? plan, TeacherAssessment? initial}) async {
  final form = GlobalKey<FormState>();
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: Form(
          key: form,
          child: AssessmentFields(
            initial: initial ??
                const TeacherAssessment(
                    stage: 'N1', category: 'activity', maxPoints: ''),
            plan: plan,
            enabled: true,
            onChanged: (_) {},
          ),
        ),
      ),
    ),
  ));
  return form;
}

void main() {
  group('remaining points', () {
    test('subtracts every planned item of the same stage and category', () {
      expect(remainingPointsInCents(_plan, 'N1', 'activity'), 150);
      expect(remainingPointsInCents(_plan, 'N1', 'exam'), 0);
      expect(remainingPointsInCents(_plan, 'N2', 'exam'), 700);
      expect(remainingPointsInCents(_plan, 'N2', 'activity'), 0);
    });

    test('never goes below zero', () {
      const over = [
        TeacherAssessment(stage: 'N1', category: 'activity', maxPoints: '3.00'),
        TeacherAssessment(stage: 'N1', category: 'activity', maxPoints: '1.00'),
      ];
      expect(remainingPointsInCents(over, 'N1', 'activity'), 0);
    });

    test('formats cents with a comma', () {
      expect(formatPointsCents(150), '1,50');
      expect(formatPointsCents(700), '7,00');
    });
  });

  testWidgets('shows the points still available in the stage', (tester) async {
    await _pump(tester, plan: _plan);
    expect(find.text('Disponível para atividades na N1: 1,50 de 3,00 pontos'),
        findsOneWidget);
  });

  testWidgets('rejects points above what is left', (tester) async {
    final form = await _pump(tester, plan: _plan);
    await tester.enterText(
        find.byKey(const ValueKey('assessment-max-points')), '2');
    expect(form.currentState!.validate(), isFalse);
    await tester.pump();
    expect(
        find.text('Restam 1,50 pontos para atividades na N1.'), findsOneWidget);

    await tester.enterText(
        find.byKey(const ValueKey('assessment-max-points')), '1,5');
    expect(form.currentState!.validate(), isTrue);
  });

  testWidgets('says when the stage has no points left', (tester) async {
    await _pump(tester,
        plan: _plan,
        initial: const TeacherAssessment(
            stage: 'N2', category: 'activity', maxPoints: ''));
    expect(
        find.text('Não há pontos disponíveis para atividades na N2 '
            '(limite de 3,00).'),
        findsOneWidget);
  });

  testWidgets('falls back to the stage cap while the plan is unknown',
      (tester) async {
    await _pump(tester);
    expect(find.text('Até 3,00 pontos por item'), findsOneWidget);
  });
}
