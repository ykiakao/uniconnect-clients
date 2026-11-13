import 'package:flutter_test/flutter_test.dart';
import 'package:uniconnect/features/activities/models/academic_activity.dart';
import 'package:uniconnect/features/activities/widgets/activity_card.dart';

AcademicActivity _activity({bool workflow = true, String? category}) =>
    AcademicActivity(
      id: 'a',
      subject: 'Banco de Dados',
      title: 'Atividade',
      description: '',
      dueDate: null,
      teacher: '',
      status: ActivityStatus.pending,
      criteria: const [],
      attachments: const [],
      workflowEnabled: workflow,
      assessmentCategory: category,
    );

void main() {
  test('activity kind is told in words, not only by color', () {
    expect(activityKind(_activity()).$2, 'Atividade • entrega digital');
    expect(activityKind(_activity(category: 'exam')).$2,
        'Prova • sem entrega digital');
    expect(activityKind(_activity(workflow: false)).$2,
        'Avaliação presencial • sem entrega digital');
  });
}
