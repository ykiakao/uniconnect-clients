import '../../../core/network/api_client.dart';
import '../../activities/models/academic_activity.dart';
import '../../grades/models/subject_grade.dart';

class AcademicApiService {
  const AcademicApiService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<AcademicActivity>> listActivities({
    required String accessToken,
    required String tenantSlug,
  }) async {
    final courses = await _listCourses(
      accessToken: accessToken,
      tenantSlug: tenantSlug,
    );
    final activities = <AcademicActivity>[];

    for (final course in courses) {
      final classes = await _listClasses(
        accessToken: accessToken,
        tenantSlug: tenantSlug,
        courseId: course.id,
      );

      for (final classItem in classes) {
        activities.addAll(
          await _listClassActivities(
            accessToken: accessToken,
            tenantSlug: tenantSlug,
            classId: classItem.id,
            subject: classItem.name,
          ),
        );
      }
    }

    activities.sort((left, right) => left.dueDate.compareTo(right.dueDate));
    return activities;
  }

  Future<List<SubjectGrade>> listStudentGrades({
    required String accessToken,
    required String tenantSlug,
    required String studentId,
  }) async {
    final response = await _apiClient.get(
      '/tenants/$tenantSlug/students/$studentId/grades',
      accessToken: accessToken,
      tenantSlug: tenantSlug,
    );
    final data = response['data'];
    if (data is! List) return const [];

    return data.whereType<Map<String, dynamic>>().map((json) {
      final grade = _toDouble(json['grade']);
      final title = json['title'] as String? ?? 'Atividade';
      final activityId = json['activityId'] as String? ?? 'ATV000';

      return SubjectGrade(
        subject: title,
        code: _shortCode(activityId),
        teacher: 'Professor da turma',
        p1: grade,
        p2: grade,
        work: grade,
        status: grade >= 7 ? 'Aprovado' : 'Em curso',
      );
    }).toList();
  }

  Future<List<_ApiCourse>> _listCourses({
    required String accessToken,
    required String tenantSlug,
  }) async {
    final response = await _apiClient.get(
      '/tenants/$tenantSlug/courses',
      accessToken: accessToken,
      tenantSlug: tenantSlug,
    );
    final data = response['data'];
    if (data is! List) return const [];

    return data
        .whereType<Map<String, dynamic>>()
        .map(_ApiCourse.fromJson)
        .toList();
  }

  Future<List<_ApiClass>> _listClasses({
    required String accessToken,
    required String tenantSlug,
    required String courseId,
  }) async {
    final response = await _apiClient.get(
      '/tenants/$tenantSlug/courses/$courseId/classes',
      accessToken: accessToken,
      tenantSlug: tenantSlug,
    );
    final data = response['data'];
    if (data is! List) return const [];

    return data
        .whereType<Map<String, dynamic>>()
        .map(_ApiClass.fromJson)
        .toList();
  }

  Future<List<AcademicActivity>> _listClassActivities({
    required String accessToken,
    required String tenantSlug,
    required String classId,
    required String subject,
  }) async {
    final response = await _apiClient.get(
      '/tenants/$tenantSlug/classes/$classId/activities',
      accessToken: accessToken,
      tenantSlug: tenantSlug,
    );
    final data = response['data'];
    if (data is! List) return const [];

    return data.whereType<Map<String, dynamic>>().map((json) {
      final dueDate = DateTime.tryParse(json['dueDate'] as String? ?? '') ??
          DateTime.now().add(const Duration(days: 30));

      return AcademicActivity(
        id: json['id'] as String,
        subject: subject,
        title: json['title'] as String? ?? 'Atividade',
        description: json['description'] as String? ?? '',
        dueLabel: _dueLabel(dueDate),
        dueDate: dueDate,
        teacher: 'Professor da turma',
        priority: _priorityFor(dueDate),
        status: ActivityStatus.pending,
        criteria: const [],
        attachments: const [],
      );
    }).toList();
  }

  static ActivityPriority _priorityFor(DateTime dueDate) {
    final remaining = dueDate.difference(DateTime.now());
    if (remaining.inHours <= 24) return ActivityPriority.critical;
    if (remaining.inDays <= 7) return ActivityPriority.medium;
    return ActivityPriority.low;
  }

  static String _dueLabel(DateTime dueDate) {
    final remaining = dueDate.difference(DateTime.now());
    if (remaining.inHours <= 0) return 'Prazo encerrado';
    if (remaining.inHours <= 24) return 'Vence hoje';
    if (remaining.inDays == 1) return 'Vence amanha';
    return 'Vence em ${remaining.inDays} dias';
  }

  static double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  static String _shortCode(String value) {
    final normalized = value.replaceAll('-', '').toUpperCase();
    if (normalized.length <= 6) return normalized;
    return normalized.substring(0, 6);
  }
}

class _ApiCourse {
  const _ApiCourse({required this.id});

  final String id;

  factory _ApiCourse.fromJson(Map<String, dynamic> json) {
    return _ApiCourse(id: json['id'] as String);
  }
}

class _ApiClass {
  const _ApiClass({required this.id, required this.name});

  final String id;
  final String name;

  factory _ApiClass.fromJson(Map<String, dynamic> json) {
    return _ApiClass(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Turma',
    );
  }
}
