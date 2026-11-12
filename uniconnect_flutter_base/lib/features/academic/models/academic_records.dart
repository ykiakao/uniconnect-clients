import '../../../core/network/api_client.dart';

/// Academic period as returned by `/academic/periods`.
class AcademicPeriodRef {
  const AcademicPeriodRef({required this.id, this.name});

  final String id;
  final String? name;

  String get label =>
      name == null || name!.trim().isEmpty ? 'Período $id' : name!.trim();

  factory AcademicPeriodRef.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const ApiException('A API retornou um período inválido.');
    }
    final id = _id(json['id']);
    if (id == null) {
      throw const ApiException('A API retornou um período sem identificador.');
    }
    return AcademicPeriodRef(id: id, name: json['name'] as String?);
  }
}

class AcademicTermDates {
  const AcademicTermDates({required this.period, this.startDate, this.endDate});

  final AcademicPeriodRef period;
  final DateTime? startDate;
  final DateTime? endDate;

  factory AcademicTermDates.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const ApiException('A API retornou datas de período inválidas.');
    }
    final start = _date(json['startDate']);
    final end = _date(json['endDate']);
    if (start != null && end != null && end.isBefore(start)) {
      throw const ApiException('A API retornou datas de período inválidas.');
    }
    return AcademicTermDates(
      period: AcademicPeriodRef.fromJson(json),
      startDate: start,
      endDate: end,
    );
  }

  static DateTime? _date(Object? value) {
    if (value == null) return null;
    if (value is String && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null &&
          parsed.year > 0 &&
          parsed.year == int.parse(value.substring(0, 4)) &&
          parsed.month == int.parse(value.substring(5, 7)) &&
          parsed.day == int.parse(value.substring(8, 10))) {
        return parsed;
      }
    }
    throw const ApiException('A API retornou datas de período inválidas.');
  }
}

/// One graded (or not yet graded) activity of a subject.
class AcademicAssessmentRecord {
  const AcademicAssessmentRecord({
    required this.activityId,
    this.title,
    this.grade,
    this.feedback,
  });

  final String activityId;
  final String? title;
  final double? grade;
  final String? feedback;

  factory AcademicAssessmentRecord.fromJson(Map<String, dynamic> json) =>
      AcademicAssessmentRecord(
        activityId: _id(json['activityId']) ?? '',
        title: json['title'] as String?,
        grade: _number(json['grade']),
        feedback: json['feedback'] as String?,
      );
}

/// A subject (offering) of the student in one period.
class AcademicSubjectRecord {
  const AcademicSubjectRecord({
    required this.id,
    this.name,
    this.status,
    this.statusLabel,
    this.activityCount = 0,
    this.activitiesComplete = true,
    this.assessments = const [],
    this.finalAverage,
    this.absences,
    this.absencePercentage,
  });

  final String id;
  final String? name;
  final String? status;
  final String? statusLabel;
  final int activityCount;
  final bool activitiesComplete;
  final List<AcademicAssessmentRecord> assessments;
  final double? finalAverage;
  final double? absences;
  final double? absencePercentage;

  String get title =>
      name == null || name!.trim().isEmpty ? 'Disciplina' : name!.trim();

  int get gradedCount => assessments.where((row) => row.grade != null).length;

  factory AcademicSubjectRecord.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const ApiException('A API retornou uma disciplina inválida.');
    }
    final id = _id(json['id']);
    if (id == null) {
      throw const ApiException(
          'A API retornou uma disciplina sem identificador.');
    }
    final grades = json['grades'];
    final attendance = json['attendance'];
    final activities = json['activities'];
    final assessments = json['assessments'];
    return AcademicSubjectRecord(
      id: id,
      name: json['name'] as String?,
      status: json['status'] as String?,
      statusLabel: json['statusLabel'] as String?,
      activityCount: activities is List ? activities.length : 0,
      activitiesComplete: json['activitiesComplete'] != false,
      assessments: assessments is List
          ? List.unmodifiable(assessments
              .whereType<Map<String, dynamic>>()
              .map(AcademicAssessmentRecord.fromJson))
          : const [],
      finalAverage: grades is Map<String, dynamic>
          ? _number(grades['finalAverage']) ?? _number(grades['average'])
          : null,
      absences: attendance is Map<String, dynamic>
          ? _number(attendance['absences'])
          : null,
      absencePercentage: attendance is Map<String, dynamic>
          ? _number(attendance['absencePercentage'])
          : null,
    );
  }
}

/// Subjects of one period, plus the notes the API attaches to the data.
class AcademicOverviewRecord {
  const AcademicOverviewRecord({
    required this.period,
    required this.subjects,
    this.complete = true,
    this.warnings = const [],
  });

  final AcademicPeriodRef period;
  final List<AcademicSubjectRecord> subjects;
  final bool complete;

  /// Distinct, human readable messages sent by the API.
  final List<String> warnings;

  factory AcademicOverviewRecord.fromJson(Object? json) {
    if (json is! Map<String, dynamic> || json['subjects'] is! List) {
      throw const ApiException('A API retornou um resumo acadêmico inválido.');
    }
    return AcademicOverviewRecord(
      period: AcademicPeriodRef.fromJson(json['period']),
      subjects: List.unmodifiable(
          (json['subjects'] as List).map(AcademicSubjectRecord.fromJson)),
      complete: json['complete'] != false,
      warnings: warningMessages(json['warnings']),
    );
  }
}

/// Every period of the student, oldest data included.
class AcademicHistoryRecord {
  const AcademicHistoryRecord(
      {required this.periods, this.warnings = const []});

  final List<AcademicOverviewRecord> periods;
  final List<String> warnings;

  factory AcademicHistoryRecord.fromJson(Map<String, dynamic> json) {
    final periods = json['periods'];
    if (periods is! List) {
      throw const ApiException('A API retornou um histórico inválido.');
    }
    return AcademicHistoryRecord(
      periods: List.unmodifiable(periods.map(AcademicOverviewRecord.fromJson)),
      warnings: warningMessages(json['warnings']),
    );
  }
}

List<String> warningMessages(Object? json) {
  if (json is! List) return const [];
  final messages = <String>{};
  for (final row in json.whereType<Map<String, dynamic>>()) {
    final message = row['message'];
    if (message is String && message.trim().isNotEmpty) {
      messages.add(message.trim());
    }
  }
  return List.unmodifiable(messages);
}

String? _id(Object? value) => switch (value) {
      final String text when text.isNotEmpty => text,
      final int number => '$number',
      _ => null,
    };

double? _number(Object? value) => value is num ? value.toDouble() : null;
