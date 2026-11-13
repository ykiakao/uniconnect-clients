import '../../activities/models/academic_attachment.dart';
import '../../../core/network/api_client.dart';
import 'grade_precision.dart';

class SubmissionReview {
  const SubmissionReview(
      {required this.grade,
      required this.feedback,
      required this.revision,
      required this.submissionVersion,
      required this.publicationState});
  final double? grade;
  final String? feedback;
  final int revision;
  final int? submissionVersion;
  final String publicationState;
  factory SubmissionReview.fromJson(Map<String, dynamic> row) {
    final grade = row['grade'];
    if (!row.containsKey('grade') ||
        (grade != null &&
            (grade is! num || !grade.isFinite || grade < 0 || grade > 10)) ||
        (row['feedback'] != null && row['feedback'] is! String) ||
        row['revision'] is! int ||
        (row['revision'] as int) < 1 ||
        !['draft', 'published'].contains(row['publicationState']) ||
        (row['submissionVersion'] != null &&
            (row['submissionVersion'] is! int ||
                (row['submissionVersion'] as int) < 1))) {
      throw const ApiException('A API retornou uma avaliação inválida.');
    }
    return SubmissionReview(
        grade: (grade as num?)?.toDouble(),
        feedback: row['feedback'] as String?,
        revision: row['revision'] as int,
        submissionVersion: row['submissionVersion'] as int?,
        publicationState: row['publicationState'] as String);
  }
}

class TeacherSubmission {
  const TeacherSubmission(
      {required this.id,
      required this.activityId,
      required this.studentId,
      required this.answer,
      required this.version,
      required this.status,
      required this.submittedAt,
      required this.isLate,
      required this.result,
      this.attachments = const []});
  final String id, activityId, studentId, answer, status;

  /// Files of the version being reviewed; empty when the API sends none.
  final List<AcademicAttachment> attachments;
  final int version;
  final DateTime submittedAt;
  final bool isLate;
  final SubmissionReview? result;

  bool get awaitingPublication => result?.publicationState == 'draft';
  bool get awaitingReview =>
      result == null && ['submitted', 'late', 'in_review'].contains(status);

  String get statusLabel {
    if (result?.publicationState == 'published') return 'Avaliação publicada';
    if (awaitingPublication) return 'Avaliação salva — não publicada';
    return switch (status) {
      'submitted' => 'Entregue • Aguardando correção',
      'late' => 'Entregue com atraso • Aguardando correção',
      'in_review' => 'Em correção',
      'corrected' => 'Corrigida',
      _ => 'Resultado indisponível',
    };
  }

  factory TeacherSubmission.fromJson(
      Map<String, dynamic> row, String activityId) {
    if (row['id'] is! String ||
        row['studentId'] is! String ||
        (row['studentId'] as String).isEmpty ||
        row['activityId'] != activityId ||
        row['answer'] is! String ||
        row['version'] is! int ||
        (row['version'] as int) < 1 ||
        row['submittedAt'] is! String ||
        DateTime.tryParse(row['submittedAt'] as String) == null ||
        row['isLate'] is! bool ||
        !['submitted', 'late', 'in_review', 'corrected', 'result_published']
            .contains(row['status']) ||
        !row.containsKey('result') ||
        (row['result'] != null && row['result'] is! Map<String, dynamic>)) {
      throw const ApiException('A API retornou uma entrega inválida.');
    }
    return TeacherSubmission(
        id: row['id'] as String,
        activityId: activityId,
        studentId: row['studentId'] as String,
        answer: row['answer'] as String,
        version: row['version'] as int,
        status: row['status'] as String,
        submittedAt: DateTime.parse(row['submittedAt'] as String),
        isLate: row['isLate'] as bool,
        result: row['result'] == null
            ? null
            : SubmissionReview.fromJson(row['result'] as Map<String, dynamic>),
        attachments: AcademicAttachment.listFrom(row['attachments']));
  }
}

class TeacherReviewService {
  const TeacherReviewService(this.client,
      {required this.accessToken, required this.tenantSlug});
  final ApiClient client;
  final String accessToken, tenantSlug;
  String get _base => '/tenants/${Uri.encodeComponent(tenantSlug)}';

  Future<({List<TeacherSubmission> rows, int total})> _page(
      String activityId, int page, int limit) async {
    final response = await client.get(
      '$_base/activities/${Uri.encodeComponent(activityId)}/submissions',
      accessToken: accessToken,
      tenantSlug: tenantSlug,
      queryParams: {'page': '$page', 'limit': '$limit'},
    );
    final data = response['data'];
    final meta = response['meta'];
    if (data is! List ||
        data.any((r) => r is! Map<String, dynamic>) ||
        meta is! Map<String, dynamic> ||
        meta['page'] != page ||
        meta['limit'] != limit ||
        meta['total'] is! int ||
        (meta['total'] as int) < 0) {
      throw const ApiException(
          'A API retornou uma lista de entregas inválida.');
    }
    return (
      rows: data
          .cast<Map<String, dynamic>>()
          .map((row) => TeacherSubmission.fromJson(row, activityId))
          .toList(),
      total: meta['total'] as int,
    );
  }

  Future<({List<TeacherSubmission> rows, int total})> preview(
          String activityId) =>
      _page(activityId, 1, 20);

  Future<List<TeacherSubmission>> list(String activityId) async {
    final rows = <TeacherSubmission>[];
    for (var page = 1; page <= 100000; page++) {
      final result = await _page(activityId, page, 100);
      rows.addAll(result.rows);
      if (rows.length >= result.total) return rows;
      if (result.rows.isEmpty) {
        throw const ApiException(
            'A lista de entregas está incompleta. Atualize.');
      }
    }
    throw const ApiException('Limite de paginação excedido.');
  }

  Future<TeacherSubmission> find(String id, String activityId) async {
    final row = await client.get(
        '$_base/submissions/${Uri.encodeComponent(id)}',
        accessToken: accessToken,
        tenantSlug: tenantSlug);
    final result = TeacherSubmission.fromJson(row, activityId);
    if (result.id != id) {
      throw const ApiException('A API retornou outra entrega.');
    }
    return result;
  }

  Future<SubmissionReview> save(TeacherSubmission submission,
      {required double? grade, required String? feedback}) async {
    final revision = submission.result?.revision ?? 0;
    if (grade != null && !hasGradePrecision(grade.toString())) {
      throw const ApiException(
          'A nota deve ter no máximo duas casas decimais.');
    }
    if ((grade != null && (!grade.isFinite || grade < 0 || grade > 10)) ||
        (feedback?.trim().length ?? 0) > 20000 ||
        revision > 2147483646 ||
        submission.version > 2147483646 ||
        submission.result?.publicationState == 'published') {
      throw const ApiException('Confira nota, feedback e estado da avaliação.');
    }
    final row = await client.put(
        '$_base/submissions/${Uri.encodeComponent(submission.id)}/review',
        {
          'expectedRevision': revision,
          'submissionVersion': submission.version,
          'grade': grade,
          'feedback': feedback?.trim(),
          'publish': false,
        },
        accessToken: accessToken,
        tenantSlug: tenantSlug);
    final result = SubmissionReview.fromJson(row);
    if (result.revision != revision + 1 ||
        result.submissionVersion != submission.version ||
        result.publicationState != 'draft' ||
        result.grade != grade ||
        result.feedback != feedback?.trim()) {
      throw const ApiException(
          'A API não confirmou a correção esperada. Atualize antes de repetir.');
    }
    return result;
  }

  Future<SubmissionReview> publish(TeacherSubmission submission) async {
    final previous = submission.result;
    if (previous == null ||
        previous.publicationState != 'draft' ||
        previous.revision > 2147483646 ||
        previous.submissionVersion != submission.version) {
      throw const ApiException(
          'Consulte uma avaliação salva e atualizada antes de publicar.');
    }
    final row = await client.post(
        '$_base/submissions/${Uri.encodeComponent(submission.id)}/review/publish',
        {'expectedRevision': previous.revision},
        accessToken: accessToken,
        tenantSlug: tenantSlug);
    final result = SubmissionReview.fromJson(row);
    if (result.revision != previous.revision + 1 ||
        result.submissionVersion != submission.version ||
        result.publicationState != 'published' ||
        result.grade != previous.grade ||
        result.feedback != previous.feedback) {
      throw const ApiException(
          'A API não confirmou a publicação esperada. Atualize antes de repetir.');
    }
    return result;
  }
}
