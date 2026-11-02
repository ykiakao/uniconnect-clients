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

    activities.sort((left, right) {
      if (left.dueDate == null) return right.dueDate == null ? 0 : 1;
      if (right.dueDate == null) return -1;
      return left.dueDate!.compareTo(right.dueDate!);
    });
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
    if (data is! List) {
      throw const ApiException('A API retornou uma lista de notas inválida.');
    }
    return data.map((row) {
      if (row is! Map<String, dynamic> ||
          row['activityId'] is! String ||
          (row['activityId'] as String).isEmpty ||
          row['title'] is! String ||
          !row.containsKey('grade') ||
          (row['feedback'] != null && row['feedback'] is! String)) {
        throw const ApiException('A API retornou uma avaliação inválida.');
      }
      final activityId = row['activityId'] as String;
      return SubjectGrade(
        activityId: activityId,
        feedback: row['feedback'] as String?,
        subject: row['title'] as String,
        code: activityId,
        teacher: '',
        grade: row['grade'] == null ? null : _toDouble(row['grade']),
      );
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _list(
      String path, String accessToken, String tenantSlug) async {
    final rows = <Map<String, dynamic>>[];
    for (var page = 1; page <= 100000; page++) {
      final result = await _apiClient.get(path,
          accessToken: accessToken,
          tenantSlug: tenantSlug,
          queryParams: {'page': '$page', 'limit': '100'});
      final data = result['data'];
      final meta = result['meta'];
      if (data is! List ||
          data.any((r) => r is! Map<String, dynamic>) ||
          meta is! Map<String, dynamic> ||
          meta['page'] != page ||
          meta['limit'] != 100 ||
          meta['total'] is! int ||
          (meta['total'] as int) < 0) {
        throw const ApiException(
            'A API retornou uma lista acadêmica inválida.');
      }
      rows.addAll(data.cast<Map<String, dynamic>>());
      if (rows.length >= (meta['total'] as int)) return rows;
      if (data.isEmpty) {
        throw const ApiException(
            'A lista acadêmica está incompleta. Atualize.');
      }
    }
    throw const ApiException('Limite de paginação excedido.');
  }

  Future<List<_ApiCourse>> _listCourses(
      {required String accessToken, required String tenantSlug}) async {
    return (await _list(
            '/tenants/$tenantSlug/courses', accessToken, tenantSlug))
        .map(_ApiCourse.fromJson)
        .toList();
  }

  Future<List<_ApiClass>> _listClasses(
      {required String accessToken,
      required String tenantSlug,
      required String courseId}) async {
    return (await _list('/tenants/$tenantSlug/courses/$courseId/classes',
            accessToken, tenantSlug))
        .map(_ApiClass.fromJson)
        .toList();
  }

  Future<List<AcademicActivity>> _listClassActivities(
      {required String accessToken,
      required String tenantSlug,
      required String classId,
      required String subject}) async {
    return (await _list('/tenants/$tenantSlug/classes/$classId/activities',
            accessToken, tenantSlug))
        .map((row) {
      if (row['classId'] != classId) {
        throw const ApiException(
            'A API retornou uma atividade de outra oferta.');
      }
      return _activity(row, subject);
    }).toList();
  }

  Future<AcademicActivity> getActivity(
      {required String accessToken,
      required String tenantSlug,
      required String id}) async {
    final row = await _apiClient.get(
        '/tenants/$tenantSlug/activities/${Uri.encodeComponent(id)}',
        accessToken: accessToken,
        tenantSlug: tenantSlug);
    if (row['id'] != id || row['classId'] is! String) {
      throw const ApiException('A API retornou uma atividade inválida.');
    }
    _activity(row, '');
    try {
      final offering = await _apiClient.get(
          '/tenants/$tenantSlug/classes/${Uri.encodeComponent(row['classId'] as String)}',
          accessToken: accessToken,
          tenantSlug: tenantSlug);
      if (offering['id'] != row['classId'] || offering['name'] is! String) {
        throw const ApiException('A API retornou uma oferta inválida.');
      }
      return _activity(row, offering['name'] as String);
    } on ApiException catch (error) {
      if (error.statusCode != 403 && error.statusCode != 404) rethrow;
      return _activity(
          row, 'Disciplina indisponível • Oferta: ${row['classId']}');
    }
  }

  static AcademicActivity _activity(Map<String, dynamic> row, String subject) {
    if (row['id'] is! String ||
        row['title'] is! String ||
        !['published', 'closed'].contains(row['state']) ||
        row['allowLate'] is! bool ||
        (row['description'] != null && row['description'] is! String) ||
        (row['instructions'] != null && row['instructions'] is! String) ||
        (row['evaluationCriteria'] != null &&
            row['evaluationCriteria'] is! String) ||
        (row['dueDate'] != null &&
            (row['dueDate'] is! String ||
                DateTime.tryParse(row['dueDate'] as String) == null))) {
      throw const ApiException(
          'A API retornou uma atividade indisponível ou inválida.');
    }
    final due = row['dueDate'] == null
        ? null
        : DateTime.parse(row['dueDate'] as String);
    return AcademicActivity(
        id: row['id'] as String,
        subject: subject,
        title: row['title'] as String,
        description: row['description'] as String? ?? '',
        instructions: row['instructions'] as String? ?? '',
        publicationState: row['state'] as String,
        allowLate: row['allowLate'] as bool,
        dueDate: due,
        dueLabel: due == null ? 'Prazo não informado' : _dueLabel(due),
        teacher: 'Professor da turma',
        priority: due == null ? ActivityPriority.low : _priorityFor(due),
        status: ActivityStatus.pending,
        criteria: row['evaluationCriteria'] == null ||
                (row['evaluationCriteria'] as String).isEmpty
            ? const []
            : [row['evaluationCriteria'] as String],
        attachments: const []);
  }

  static ActivityPriority _priorityFor(DateTime dueDate) {
    final remaining = dueDate.difference(DateTime.now());
    if (remaining.inHours <= 24) return ActivityPriority.critical;
    if (remaining.inDays <= 7) return ActivityPriority.medium;
    return ActivityPriority.low;
  }

  static String _dueLabel(DateTime dueDate) {
    final remaining = dueDate.difference(DateTime.now());
    if (remaining.isNegative) return 'Prazo encerrado';
    if (remaining.inHours < 1) return 'Vence em menos de 1 hora';
    if (remaining.inHours <= 24) return 'Vence em ${remaining.inHours} h';
    if (remaining.inDays == 1) return 'Vence em 1 dia';
    return 'Vence em ${remaining.inDays} dias';
  }

  static double _toDouble(Object? value) {
    final parsed = value is num
        ? value.toDouble()
        : value is String
            ? double.tryParse(value)
            : null;
    if (parsed == null || !parsed.isFinite) {
      throw const ApiException('A API não informou uma nota válida.');
    }
    return parsed;
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
