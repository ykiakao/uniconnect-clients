import '../../../core/network/api_client.dart';

int? academicPointsInCents(String raw) {
  final value = raw.trim().replaceAll(',', '.');
  final match = RegExp(r'^(\d)(?:\.(\d{1,2}))?$').firstMatch(value);
  if (match == null) return null;
  return int.parse(match[1]!) * 100 +
      int.parse((match[2] ?? '').padRight(2, '0'));
}

String? academicPointsError(String raw, String maximum) {
  final cents = academicPointsInCents(raw);
  final max = academicPointsInCents(maximum);
  if (cents == null) return 'Informe pontos com até duas casas decimais.';
  if (max == null || cents > max) return 'Informe de 0 a $maximum pontos.';
  return null;
}

/// Stage cap per category: 3 points of activities and 7 of exams.
String academicCategoryMaximum(String category) =>
    category == 'exam' ? '7,00' : '3,00';

/// Points already planned in the offering for [stage] and [category]. The
/// API counts every linked activity, drafts and closed ones included.
int allocatedPointsInCents(
    Iterable<TeacherAssessment> plan, String stage, String category) {
  return plan
      .where((item) => item.stage == stage && item.category == category)
      .fold(
          0, (sum, item) => sum + (academicPointsInCents(item.maxPoints) ?? 0));
}

/// Points still available for a new item, never below zero.
int remainingPointsInCents(
    Iterable<TeacherAssessment> plan, String stage, String category) {
  final cap = academicPointsInCents(academicCategoryMaximum(category)) ?? 0;
  final left = cap - allocatedPointsInCents(plan, stage, category);
  return left < 0 ? 0 : left;
}

String formatPointsCents(int cents) =>
    '${cents ~/ 100},${(cents % 100).toString().padLeft(2, '0')}';

String academicPointsPayload(String raw, String maximum) {
  final error = academicPointsError(raw, maximum);
  if (error != null) throw ApiException(error);
  return raw.trim().replaceAll(',', '.');
}

class TeacherAssessment {
  const TeacherAssessment({
    required this.stage,
    required this.category,
    required this.maxPoints,
  });

  final String stage;
  final String category;
  final String maxPoints;

  bool get isExam => category == 'exam';
  String get label =>
      '$stage • ${isExam ? 'Prova' : 'Atividade'} • $maxPoints pts';

  factory TeacherAssessment.fromJson(Object? value) {
    if (value is! Map<String, dynamic> || value['maxPoints'] is! String) {
      throw const ApiException('A API retornou uma avaliação inválida.');
    }
    if (!['N1', 'N2'].contains(value['stage']) ||
        !['exam', 'activity'].contains(value['category'])) {
      throw const ApiException('A API retornou uma avaliação inválida.');
    }
    final result = TeacherAssessment(
      stage: value['stage'] as String,
      category: value['category'] as String,
      maxPoints: value['maxPoints'] as String,
    );
    result.toJson();
    return result;
  }

  Map<String, dynamic> toJson() {
    if (!['N1', 'N2'].contains(stage) ||
        !['exam', 'activity'].contains(category)) {
      throw const ApiException('Confira a etapa e a categoria da avaliação.');
    }
    return {
      'stage': stage,
      'category': category,
      'maxPoints': academicPointsPayload(maxPoints, isExam ? '7,00' : '3,00'),
    };
  }
}
