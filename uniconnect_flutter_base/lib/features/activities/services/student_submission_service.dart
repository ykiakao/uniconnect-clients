import '../../../core/network/api_client.dart';

class PublishedSubmissionResult {
  const PublishedSubmissionResult({this.grade, this.feedback});

  final double? grade;
  final String? feedback;
}

class StudentSubmission {
  const StudentSubmission(
      {required this.id,
      required this.activityId,
      required this.version,
      required this.answer,
      required this.submittedAt,
      required this.isLate,
      required this.status,
      this.result});
  final String id;
  final String activityId;
  final int version;
  final String answer;
  final DateTime submittedAt;
  final bool isLate;
  final String status;
  final PublishedSubmissionResult? result;
  bool get canRevise =>
      ['submitted', 'late'].contains(status) && version <= 2147483646;
  String get statusLabel => switch (status) {
        'submitted' => 'Resposta enviada',
        'late' => 'Resposta enviada com atraso',
        'in_review' || 'corrected' => 'Em avaliação',
        _ => result == null ? 'Resultado indisponível' : 'Resultado publicado',
      };
}

class StudentSubmissionService {
  const StudentSubmissionService(this.client,
      {required this.accessToken,
      required this.tenantSlug,
      required this.studentId});
  final ApiClient client;
  final String accessToken;
  final String tenantSlug;
  final String studentId;
  String _path(String id) =>
      '/tenants/${Uri.encodeComponent(tenantSlug)}/activities/${Uri.encodeComponent(id)}/submissions';

  StudentSubmission _receipt(Map<String, dynamic> row, String activityId) {
    if (row['id'] is! String ||
        (row['id'] as String).isEmpty ||
        row['activityId'] != activityId ||
        row['studentId'] != studentId ||
        row['version'] is! int ||
        (row['version'] as int) < 1 ||
        row['answer'] is! String ||
        row['submittedAt'] is! String ||
        DateTime.tryParse(row['submittedAt'] as String) == null ||
        row['isLate'] is! bool ||
        !['submitted', 'late', 'in_review', 'corrected', 'result_published']
            .contains(row['status'])) {
      throw const ApiException(
          'A API retornou uma entrega inválida. Atualize antes de tentar novamente.');
    }
    return StudentSubmission(
        id: row['id'] as String,
        activityId: activityId,
        version: row['version'] as int,
        answer: row['answer'] as String,
        submittedAt: DateTime.parse(row['submittedAt'] as String),
        isLate: row['isLate'] as bool,
        status: row['status'] as String,
        result: row['status'] == 'result_published'
            ? _publishedResult(row['result'])
            : null);
  }

  PublishedSubmissionResult? _publishedResult(Object? row) {
    if (row is! Map<String, dynamic> ||
        row['publicationState'] != 'published' ||
        !row.containsKey('grade')) {
      return null;
    }
    final grade = row['grade'];
    final feedback = row['feedback'];
    if ((grade != null &&
            (grade is! num || !grade.isFinite || grade < 0 || grade > 10)) ||
        (feedback != null && feedback is! String)) {
      return null;
    }
    return PublishedSubmissionResult(
      grade: (grade as num?)?.toDouble(),
      feedback: feedback as String?,
    );
  }

  Future<StudentSubmission?> own(String activityId) async {
    final row = await client.get('${_path(activityId)}/me',
        accessToken: accessToken, tenantSlug: tenantSlug);
    if (row['status'] == 'not_submitted' &&
        row.containsKey('submission') &&
        row['submission'] == null) {
      return null;
    }
    return _receipt(row, activityId);
  }

  Future<StudentSubmission> submit(String activityId,
      {required String answer, required int expectedVersion}) async {
    final text = answer.trim();
    if (text.isEmpty ||
        text.length > 20000 ||
        expectedVersion < 0 ||
        expectedVersion > 2147483646) {
      throw const ApiException(
          'Informe uma resposta de 1 a 20000 caracteres e uma versão válida.');
    }
    final row = await client.post(
        _path(activityId), {'answer': text, 'expectedVersion': expectedVersion},
        accessToken: accessToken, tenantSlug: tenantSlug);
    final result = _receipt(row, activityId);
    if (result.version != expectedVersion + 1 ||
        result.answer != text ||
        !['submitted', 'late'].contains(result.status)) {
      throw const ApiException(
          'A API não confirmou o envio esperado. Consulte sua entrega antes de repetir.');
    }
    return result;
  }
}
