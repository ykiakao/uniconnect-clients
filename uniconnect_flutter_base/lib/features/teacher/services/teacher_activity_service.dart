import '../../../core/network/api_client.dart';

class TeacherOffering {
  const TeacherOffering({required this.id, required this.name});
  final String id;
  final String name;
}

class TeacherActivity {
  const TeacherActivity(
      {required this.id,
      required this.classId,
      required this.title,
      required this.state,
      required this.revision,
      required this.workflowEnabled});
  final String id;
  final String classId;
  final String title;
  final String state;
  final int revision;
  final bool workflowEnabled;
  factory TeacherActivity.fromJson(Map<String, dynamic> row) {
    if (row['id'] is! String ||
        row['classId'] is! String ||
        row['title'] is! String ||
        !['draft', 'published', 'closed'].contains(row['state']) ||
        row['revision'] is! int ||
        (row['revision'] as int) < 1 ||
        row['workflowEnabled'] is! bool) {
      throw const ApiException('A API retornou uma atividade inválida.');
    }
    return TeacherActivity(
        id: row['id'] as String,
        classId: row['classId'] as String,
        title: row['title'] as String,
        state: row['state'] as String,
        revision: row['revision'] as int,
        workflowEnabled: row['workflowEnabled'] as bool);
  }
  String get stateLabel => switch (state) {
        'draft' => 'Rascunho',
        'published' => 'Publicada',
        _ => 'Encerrada',
      };
}

class TeacherActivityService {
  const TeacherActivityService(this.client,
      {required this.accessToken, required this.tenantSlug});
  final ApiClient client;
  final String accessToken;
  final String tenantSlug;
  String get _base => '/tenants/${Uri.encodeComponent(tenantSlug)}';

  Future<List<Map<String, dynamic>>> _list(String path,
      {Map<String, String> filters = const {}}) async {
    final rows = <Map<String, dynamic>>[];
    for (var page = 1; page <= 100000; page++) {
      final response = await client.get(path,
          accessToken: accessToken,
          tenantSlug: tenantSlug,
          queryParams: {...filters, 'page': '$page', 'limit': '100'});
      final data = response['data'];
      final meta = response['meta'];
      if (data is! List ||
          data.any((r) => r is! Map<String, dynamic>) ||
          meta is! Map<String, dynamic> ||
          meta['total'] is! int ||
          (meta['total'] as int) < 0 ||
          meta['page'] != page ||
          meta['limit'] != 100) {
        throw const ApiException('A API retornou uma lista inválida.');
      }
      rows.addAll(data.cast<Map<String, dynamic>>());
      if (rows.length >= (meta['total'] as int)) return rows;
      if (data.isEmpty) {
        throw const ApiException(
            'A lista de atividades está incompleta. Atualize.');
      }
    }
    throw const ApiException('Limite de paginação excedido.');
  }

  Future<List<TeacherOffering>> offerings() async {
    final rows = await _list('$_base/offerings', filters: {'status': 'active'});
    return rows.map((r) {
      if (r['id'] is! String ||
          r['name'] is! String ||
          r['status'] != 'active') {
        throw const ApiException('A API retornou uma oferta inválida.');
      }
      return TeacherOffering(id: r['id'] as String, name: r['name'] as String);
    }).toList();
  }

  Future<List<TeacherActivity>> activities(String classId) async {
    final rows = await _list(
        '$_base/classes/${Uri.encodeComponent(classId)}/activities');
    return rows.map((row) => _scoped(row, classId)).toList();
  }

  TeacherActivity _scoped(Map<String, dynamic> row, String classId) {
    final activity = TeacherActivity.fromJson(row);
    if (activity.classId != classId) {
      throw const ApiException('A API retornou uma atividade de outra oferta.');
    }
    return activity;
  }

  Future<TeacherActivity> create(String classId,
      {required String title,
      String description = '',
      String type = 'assignment',
      String instructions = '',
      String evaluationCriteria = '',
      DateTime? dueDate,
      String priority = 'medium',
      bool allowLate = false}) async {
    final texts = [title, description, type, instructions, evaluationCriteria];
    if (title.trim().isEmpty ||
        type.trim().isEmpty ||
        texts.any((s) => s.trim().length > 102400) ||
        !['low', 'medium', 'high'].contains(priority)) {
      throw const ApiException('Confira os campos da atividade.');
    }
    final response = await client.post(
        '$_base/classes/${Uri.encodeComponent(classId)}/activities',
        {
          'title': title.trim(),
          'description': description.trim(),
          'type': type.trim(),
          'instructions': instructions.trim(),
          'evaluationCriteria': evaluationCriteria.trim(),
          if (dueDate != null) 'dueDate': dueDate.toUtc().toIso8601String(),
          'priority': priority,
          'allowLate': allowLate,
          'state': 'draft',
        },
        accessToken: accessToken,
        tenantSlug: tenantSlug);
    final result = _scoped(response, classId);
    if (result.state != 'draft') {
      throw const ApiException(
          'A API não confirmou o rascunho. Atualize a lista.');
    }
    return result;
  }

  Future<TeacherActivity> publish(TeacherActivity activity) async {
    if (activity.state != 'draft' ||
        !activity.workflowEnabled ||
        activity.revision > 2147483646) {
      throw const ApiException(
          'Esta atividade não pode ser publicada por este fluxo.');
    }
    final response = await client.post(
        '$_base/activities/${Uri.encodeComponent(activity.id)}/publish',
        {'expectedVersion': activity.revision},
        accessToken: accessToken,
        tenantSlug: tenantSlug);
    final result = _scoped(response, activity.classId);
    if (result.id != activity.id ||
        result.state != 'published' ||
        result.revision <= activity.revision) {
      throw const ApiException(
          'A API não confirmou a publicação. Atualize a lista.');
    }
    return result;
  }
}
