import '../../../core/network/api_client.dart';
import 'teacher_activity_service.dart';
import 'teacher_assessment.dart';

Map<String, dynamic> _object(Object? value) {
  if (value is Map<String, dynamic>) return value;
  throw const ApiException('A API retornou dados acadêmicos inválidos.');
}

String _string(Object? value) {
  if (value is String && value.isNotEmpty) return value;
  throw const ApiException('A API retornou dados acadêmicos inválidos.');
}

int _count(Object? value) {
  if (value is int && value >= 0) return value;
  throw const ApiException('A API retornou dados acadêmicos inválidos.');
}

bool _flag(Object? value) {
  if (value is bool) return value;
  throw const ApiException('A API retornou dados acadêmicos inválidos.');
}

String _choice(Object? value, List<String> choices) {
  if (value is String && choices.contains(value)) return value;
  throw const ApiException('A API retornou um estado acadêmico inválido.');
}

class AcademicPage<T> {
  const AcademicPage(this.rows, this.page, this.total);
  static const limit = 20;
  final List<T> rows;
  final int page;
  final int total;
  bool get hasNext => page * limit < total;

  static AcademicPage<T> read<T>(Map<String, dynamic> row, int page,
      T Function(Map<String, dynamic>) decode) {
    final meta = _object(row['meta']);
    final total = _count(meta['total']);
    final data = row['data'];
    if (meta['page'] != page ||
        meta['limit'] != limit ||
        data is! List ||
        data.length > limit) {
      throw const ApiException('A API retornou uma página acadêmica inválida.');
    }
    return AcademicPage(
        data.map((item) => decode(_object(item))).toList(), page, total);
  }
}

class ExamGrade {
  ExamGrade.fromJson(Map<String, dynamic> row)
      : points = _string(row['points']),
        revision = _count(row['revision']),
        published = _choice(row['publicationState'], ['draft', 'published']) ==
            'published' {
    if (row['unit'] != 'exam_points' ||
        revision < 1 ||
        academicPointsInCents(points) == null) {
      throw const ApiException('A API retornou uma nota de prova inválida.');
    }
  }
  final String points;
  final int revision;
  final bool published;
}

class ExamStudent {
  ExamStudent.fromJson(Map<String, dynamic> row)
      : id = _string(row['studentId']),
        name = _string(row['studentName']),
        grade = row['result'] == null
            ? null
            : ExamGrade.fromJson(_object(row['result']));
  final String id;
  final String name;
  final ExamGrade? grade;
}

class ExamRoster {
  ExamRoster.fromJson(this.examId, Map<String, dynamic> row, int page)
      : stage = _choice(row['stage'], ['N1', 'N2']),
        maxPoints = _string(row['maxPoints']),
        revision = _count(row['revision']),
        opened = row['gradingOpenedAt'] == null
            ? false
            : _string(row['gradingOpenedAt']).isNotEmpty,
        students = AcademicPage.read(row, page, ExamStudent.fromJson) {
    if (row['examId'] != examId ||
        revision < 1 ||
        academicPointsError(maxPoints, '7.00') != null ||
        students.rows.any((student) =>
            student.grade != null &&
            (!opened ||
                academicPointsError(student.grade!.points, maxPoints) !=
                    null))) {
      throw const ApiException('A API retornou uma pauta de prova inválida.');
    }
  }
  final String examId;
  final String stage;
  final String maxPoints;
  final int revision;
  final bool opened;
  final AcademicPage<ExamStudent> students;
}

class ReportStage {
  ReportStage.fromJson(Map<String, dynamic> row)
      : examPoints =
            row['examPoints'] == null ? null : _string(row['examPoints']),
        activityPoints = row['activityPoints'] == null
            ? null
            : _string(row['activityPoints']),
        total = row['total'] == null ? null : _string(row['total']),
        status = _choice(row['status'], ['pending', 'partial', 'definitive']),
        applies = _flag(row['applies']),
        pendingCount = _count(row['pendingCount']),
        closed =
            _choice(_object(row['closure'])['state'], ['open', 'closed']) ==
                'closed';
  final String? examPoints;
  final String? activityPoints;
  final String? total;
  final String status;
  final bool applies;
  final bool closed;
  final int pendingCount;
}

class TeacherReportCard {
  TeacherReportCard.fromJson(Map<String, dynamic> row)
      : studentId = _string(row['studentId']),
        studentName = _string(row['studentName']),
        average = row['average'] == null ? null : _string(row['average']),
        status = _choice(row['status'],
            ['partial', 'approved', 'final_exam_eligible', 'below_minimum']),
        n1 = ReportStage.fromJson(_object(_object(row['stages'])['N1'])),
        n2 = ReportStage.fromJson(_object(_object(row['stages'])['N2']));
  final String studentId;
  final String studentName;
  final String? average;
  final String status;
  final ReportStage n1;
  final ReportStage n2;

  String get statusLabel => switch (status) {
        'approved' => 'Aprovado por média',
        'final_exam_eligible' => 'Elegível à prova final',
        'below_minimum' => 'Abaixo do mínimo',
        _ => 'Resultado parcial',
      };
}

class ClosureIssue {
  ClosureIssue.fromJson(Map<String, dynamic> row)
      : studentId = _string(row['studentId']),
        title = _string(row['title']),
        reason = _choice(row['reason'],
            ['assessment_unavailable', 'draft_grade', 'missing_grade']);
  final String studentId;
  final String title;
  final String reason;
}

class AcademicStageStatus {
  AcademicStageStatus.fromJson(
      String classId, this.stage, Map<String, dynamic> row, int page)
      : closed =
            _choice(_object(row['closure'])['state'], ['open', 'closed']) ==
                'closed',
        eligibleCount = _count(row['eligibleCount']),
        assessmentCount = _count(row['assessmentCount']),
        blockers = _readBlockers(row['blockers']),
        issues = AcademicPage.read(row, page, ClosureIssue.fromJson) {
    if (row['classId'] != classId || row['stage'] != stage) {
      throw const ApiException(
          'A API retornou o estado de outra etapa ou oferta.');
    }
  }
  final String stage;
  final bool closed;
  final int eligibleCount;
  final int assessmentCount;
  final List<String> blockers;
  final AcademicPage<ClosureIssue> issues;
  bool get canClose => !closed && blockers.isEmpty && issues.total == 0;

  static List<String> _readBlockers(Object? value) {
    if (value is! List) {
      throw const ApiException('A API retornou bloqueios inválidos.');
    }
    return value
        .map((item) => _choice(item,
            ['no_assessments', 'no_eligible_students', 'pending_assessments']))
        .toList();
  }
}

class TeacherAcademicService {
  const TeacherAcademicService(this.session);
  final TeacherActivityService session;

  String get _base => '/tenants/${Uri.encodeComponent(session.tenantSlug)}';
  String _exam(String id) =>
      '$_base/activities/${Uri.encodeComponent(id)}/exam';
  String _report(String id) =>
      '$_base/classes/${Uri.encodeComponent(id)}/report-card';

  Future<Map<String, dynamic>> _get(String path, {int? page}) =>
      session.client.get(
        path,
        accessToken: session.accessToken,
        tenantSlug: session.tenantSlug,
        queryParams: page == null
            ? null
            : {'page': '$page', 'limit': '${AcademicPage.limit}'},
      );

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) =>
      session.client.post(path, body,
          accessToken: session.accessToken, tenantSlug: session.tenantSlug);

  Future<ExamRoster> roster(String examId, {int page = 1}) async =>
      ExamRoster.fromJson(
          examId, await _get('${_exam(examId)}/grades', page: page), page);

  Future<void> activate(ExamRoster roster) async {
    final row = await _post('${_exam(roster.examId)}/activate',
        {'expectedVersion': roster.revision});
    if (row['examId'] != roster.examId ||
        row['revision'] != roster.revision + 1 ||
        row['gradingOpenedAt'] is! String) {
      throw const ApiException('A API não confirmou a abertura da pauta.');
    }
  }

  Future<void> save(
      ExamRoster roster, ExamStudent student, String points) async {
    final previous = student.grade;
    if (!roster.opened || previous?.published == true) {
      throw const ApiException('Esta nota não aceita um rascunho.');
    }
    final revision = previous?.revision ?? 0;
    final row = await session.client.put(
      '${_exam(roster.examId)}/grades/${Uri.encodeComponent(student.id)}',
      {
        'expectedRevision': revision,
        'points': academicPointsPayload(points, roster.maxPoints)
      },
      accessToken: session.accessToken,
      tenantSlug: session.tenantSlug,
    );
    _verifyGrade(row, revision, false);
  }

  Future<void> publish(ExamRoster roster, ExamStudent student,
      {String? points}) async {
    final previous = student.grade;
    if (!roster.opened ||
        previous == null ||
        previous.published != (points != null)) {
      throw const ApiException('Confira o estado da nota antes de publicar.');
    }
    final row = await _post(
      '${_exam(roster.examId)}/grades/${Uri.encodeComponent(student.id)}/publish',
      {
        'expectedRevision': previous.revision,
        if (points != null)
          'points': academicPointsPayload(points, roster.maxPoints)
      },
    );
    _verifyGrade(row, previous.revision, true);
  }

  void _verifyGrade(Map<String, dynamic> row, int revision, bool published) {
    final grade = ExamGrade.fromJson(row);
    if (grade.revision != revision + 1 || grade.published != published) {
      throw const ApiException('A API não confirmou a alteração da nota.');
    }
  }

  Future<AcademicPage<TeacherReportCard>> summary(String classId,
      {int page = 1}) async {
    final row = await _get(_report(classId), page: page);
    if (row['classId'] != classId) {
      throw const ApiException('A API retornou dados de outra oferta.');
    }
    return AcademicPage.read(row, page, TeacherReportCard.fromJson);
  }

  Future<TeacherReportCard> studentReport(
      String classId, String studentId) async {
    final row = await _get(
        '${_report(classId)}/students/${Uri.encodeComponent(studentId)}');
    if (row['classId'] != classId || row['studentId'] != studentId) {
      throw const ApiException(
          'A API retornou o boletim de outro aluno ou oferta.');
    }
    return TeacherReportCard.fromJson(row);
  }

  Future<AcademicStageStatus> stage(String classId, String stage,
          {int page = 1}) async =>
      AcademicStageStatus.fromJson(classId, stage,
          await _get('${_report(classId)}/stages/$stage', page: page), page);

  Future<void> close(String classId, String stage) async {
    final row = await _post('${_report(classId)}/stages/$stage/close', {});
    if (row['classId'] != classId ||
        row['stage'] != stage ||
        _object(row['closure'])['state'] != 'closed') {
      throw const ApiException('A API não confirmou o fechamento.');
    }
  }
}
