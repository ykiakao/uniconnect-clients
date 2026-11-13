import '../../../core/network/api_client.dart';

const invalidStudentReport = ApiException(
  'A API retornou dados de boletim inválidos.',
  code: 'INVALID_REPORT_CARD_RESPONSE',
);

class StudentReportOffering {
  const StudentReportOffering({required this.id, required this.name});

  final String id;
  final String name;

  factory StudentReportOffering.fromJson(
      Map<String, dynamic> row, String tenantId) {
    final id = row['id'];
    final name = row['name'];
    final tenant = row['tenantId'];
    if (id is! String ||
        id.trim().isEmpty ||
        name is! String ||
        name.trim().isEmpty ||
        tenant is! String ||
        tenant.isEmpty ||
        (tenantId.isNotEmpty && tenant != tenantId)) {
      throw invalidStudentReport;
    }
    return StudentReportOffering(id: id, name: name);
  }
}

enum ReportStageStatus { pending, partial, definitive }

enum ReportCardStatus { partial, approved, finalExamEligible, belowMinimum }

class StudentReportStage {
  const StudentReportStage._({
    required this.examPoints,
    required this.activityPoints,
    required this.total,
    required this.pendingCount,
    required this.closed,
    required this.applies,
    required this.status,
  });

  final String? examPoints;
  final String? activityPoints;
  final String? total;
  final int pendingCount;
  final bool closed;
  final bool applies;
  final ReportStageStatus status;

  bool get hasResultsOrPending => total != null || pendingCount > 0;

  factory StudentReportStage._fromJson(Object? value) {
    if (value is! Map<String, dynamic>) throw invalidStudentReport;
    final closure = value['closure'];
    final applies = value['applies'];
    final pending = value['pendingCount'];
    if (closure is! Map<String, dynamic> ||
        !['open', 'closed'].contains(closure['state']) ||
        applies is! bool ||
        pending is! int ||
        pending < 0) {
      throw invalidStudentReport;
    }
    final closed = closure['state'] == 'closed';
    final exam = _decimal(value, 'examPoints');
    final activity = _decimal(value, 'activityPoints');
    final total = _decimal(value, 'total');
    final status = switch (value['status']) {
      'pending' => ReportStageStatus.pending,
      'partial' => ReportStageStatus.partial,
      'definitive' => ReportStageStatus.definitive,
      _ => throw invalidStudentReport,
    };
    if ((!applies &&
            (exam != null ||
                activity != null ||
                total != null ||
                pending != 0)) ||
        (status == ReportStageStatus.definitive &&
            (!closed || !applies || pending != 0 || total == null))) {
      throw invalidStudentReport;
    }
    return StudentReportStage._(
      examPoints: exam,
      activityPoints: activity,
      total: total,
      pendingCount: pending,
      closed: closed,
      applies: applies,
      status: status,
    );
  }
}

class StudentReportCard {
  const StudentReportCard._({
    required this.n1,
    required this.n2,
    required this.average,
    required this.status,
  });

  final StudentReportStage n1;
  final StudentReportStage n2;
  final String? average;
  final ReportCardStatus status;

  bool get hasAssessments =>
      n1.closed ||
      n2.closed ||
      n1.hasResultsOrPending ||
      n2.hasResultsOrPending;

  factory StudentReportCard.fromJson(Map<String, dynamic> row,
      {required String classId, required String studentId}) {
    final stages = row['stages'];
    if (row['classId'] != classId ||
        row['studentId'] != studentId ||
        stages is! Map<String, dynamic>) {
      throw invalidStudentReport;
    }
    final n1 = StudentReportStage._fromJson(stages['N1']);
    final n2 = StudentReportStage._fromJson(stages['N2']);
    final average = _decimal(row, 'average');
    final status = switch (row['status']) {
      'partial' => ReportCardStatus.partial,
      'approved' => ReportCardStatus.approved,
      'final_exam_eligible' => ReportCardStatus.finalExamEligible,
      'below_minimum' => ReportCardStatus.belowMinimum,
      _ => throw invalidStudentReport,
    };
    if (status == ReportCardStatus.partial
        ? average != null
        : average == null ||
            n1.status != ReportStageStatus.definitive ||
            n2.status != ReportStageStatus.definitive) {
      throw invalidStudentReport;
    }
    return StudentReportCard._(
        n1: n1, n2: n2, average: average, status: status);
  }
}

final _pointsPattern = RegExp(r'^(?:[0-9](?:\.\d{1,6})?|10(?:\.0{1,6})?)$');

String? _decimal(Map<String, dynamic> row, String key) {
  final value = row[key];
  if (value == null && row.containsKey(key)) return null;
  if (value is String && _pointsPattern.hasMatch(value)) return value;
  throw invalidStudentReport;
}
