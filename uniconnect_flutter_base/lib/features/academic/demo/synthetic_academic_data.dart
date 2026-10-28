import '../../activities/models/academic_activity.dart';
import '../../grades/models/subject_grade.dart';

class SyntheticAcademicData {
  const SyntheticAcademicData(
      {required this.referenceTime,
      required this.currentPeriodLabel,
      required this.currentSubjects,
      required this.activities,
      required this.grades});

  static const assetPath = 'assets/demo/synthetic-academic-data.json';
  final DateTime referenceTime;
  final String currentPeriodLabel;
  final List<String> currentSubjects;
  final List<AcademicActivity> activities;
  final List<SubjectGrade> grades;

  factory SyntheticAcademicData.fromJson(Map<String, dynamic> json) {
    void require(bool condition) {
      if (!condition) {
        throw const FormatException('Base demonstrativa inválida.');
      }
    }

    require(json['schemaVersion'] == '1.0.0' &&
        json['metadata']['synthetic'] == true &&
        json['institution']['slug'] == 'edukmais' &&
        json['metadata']['timeZone'] == 'America/Rio_Branco');
    final reference =
        DateTime.parse(json['metadata']['referenceDateTime'] as String);
    final ids = <String>{json['institution']['id'] as String};
    Map<String, Map<String, dynamic>> index(String key) {
      final result = <String, Map<String, dynamic>>{};
      for (final raw in json[key] as List) {
        final row = Map<String, dynamic>.from(raw as Map);
        final id = row['id'] as String;
        require(id.startsWith('demo-edukmais-') && ids.add(id));
        result[id] = row;
      }
      return result;
    }

    final courses = index('courses');
    final periods = index('periods');
    final teachers = index('teachers');
    final subjects = index('subjects');
    final rawActivities = index('activities');
    final evaluations = index('evaluations');
    Map<String, dynamic> resolve(
        Map<String, Map<String, dynamic>> source, Object? id) {
      final row = source[id];
      if (row == null) {
        throw const FormatException('Vínculo demonstrativo inválido.');
      }
      return row;
    }

    require(courses.length == 1);
    final course = courses.values.single;
    final current = resolve(periods, course['currentPeriodId']);
    require(
        current['isCurrent'] == true && current['courseId'] == course['id']);
    require(course['institutionId'] == json['institution']['id']);
    for (final period in periods.values) {
      require(period['courseId'] == course['id']);
    }
    for (final teacher in teachers.values) {
      require(teacher['institutionId'] == json['institution']['id']);
    }
    for (final subject in subjects.values) {
      resolve(periods, subject['periodId']);
      resolve(teachers, subject['teacherId']);
      require(subject['courseId'] == course['id']);
      require((subject['offeringId'] as String).startsWith('demo-edukmais-') &&
          ids.add(subject['offeringId'] as String));
    }
    final activities = <AcademicActivity>[];
    for (final row in rawActivities.values) {
      final subject = resolve(subjects, row['subjectId']);
      final teacher = resolve(teachers, row['teacherId']);
      require(row['periodId'] == subject['periodId'] &&
          row['offeringId'] == subject['offeringId'] &&
          row['teacherId'] == subject['teacherId']);
      final due = row['dueDate'] == null
          ? null
          : DateTime.parse(row['dueDate'] as String);
      activities.add(AcademicActivity(
        id: row['id'] as String,
        subject: subject['name'] as String,
        title: row['title'] as String,
        description: row['description'] as String,
        teacher: teacher['displayName'] as String,
        dueDate: due,
        dueLabel: _dueLabel(due, reference),
        demoReferenceTime: reference,
        priority: ActivityPriority.values.byName(row['priority'] as String),
        status: ActivityStatus.values.byName(row['status'] as String),
        criteria: List<String>.from(row['criteria'] as List),
        attachments: List<String>.from(row['attachments'] as List),
      ));
    }
    activities.sort((a, b) {
      if (a.dueDate == null) {
        return b.dueDate == null ? a.id.compareTo(b.id) : 1;
      }
      if (b.dueDate == null) {
        return -1;
      }
      return a.dueDate!.compareTo(b.dueDate!);
    });
    final grades = <SubjectGrade>[];
    for (final row in evaluations.values) {
      final subject = resolve(subjects, row['subjectId']);
      final period = resolve(periods, row['periodId']);
      require(row['periodId'] == subject['periodId']);
      if (row['activityId'] != null) {
        final activity = resolve(rawActivities, row['activityId']);
        require(activity['subjectId'] == row['subjectId'] &&
            activity['periodId'] == row['periodId']);
      }
      final grade = row['grade'];
      require(grade is num &&
          grade.isFinite &&
          grade >= 0 &&
          grade <= 10 &&
          row['maxGrade'] == 10);
      final value = (grade as num).toDouble();
      grades.add(SubjectGrade(
        id: row['id'] as String,
        activityId: row['activityId'] as String?,
        subject: row['title'] as String,
        code: row['code'] as String,
        teacher:
            resolve(teachers, subject['teacherId'])['displayName'] as String,
        disciplineName: subject['name'] as String,
        periodLabel: period['label'] as String,
        isHistorical: period['id'] != current['id'],
        feedback: row['feedback'] as String,
        p1: value,
        p2: value,
        work: value,
        status: '',
      ));
    }
    return SyntheticAcademicData(
        referenceTime: reference,
        currentPeriodLabel: current['label'] as String,
        currentSubjects: List.unmodifiable(subjects.values
            .where((s) => s['periodId'] == current['id'])
            .map((s) => s['name'] as String)),
        activities: List.unmodifiable(activities),
        grades: List.unmodifiable(grades));
  }

  static String _dueLabel(DateTime? due, DateTime reference) {
    if (due == null) {
      return 'Prazo não informado';
    }
    final remaining = due.difference(reference);
    if (remaining.isNegative) {
      return 'Prazo encerrado';
    }
    if (remaining.inHours < 1) {
      return 'Vence em menos de 1 hora';
    }
    if (remaining <= const Duration(hours: 24)) {
      return 'Vence em ${remaining.inHours} h';
    }
    return remaining.inDays == 1
        ? 'Vence em 1 dia'
        : 'Vence em ${remaining.inDays} dias';
  }
}
