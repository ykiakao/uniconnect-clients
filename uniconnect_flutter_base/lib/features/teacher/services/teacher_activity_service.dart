import '../../../core/network/api_client.dart';
import 'teacher_assessment.dart';

class TeacherOffering {
  const TeacherOffering({required this.id, required this.name, String? label})
      : label = label ?? name;
  final String id;
  final String name;
  final String label;
}

class TeacherActivity {
  const TeacherActivity(
      {required this.id,
      required this.classId,
      required this.title,
      required this.state,
      required this.revision,
      required this.workflowEnabled,
      this.assessment,
      this.examGradingOpenedAt,
      this.dueDate,
      this.description = '',
      this.type = 'assignment',
      this.instructions = '',
      this.evaluationCriteria = '',
      this.allowLate = false});
  final String id;
  final String classId;
  final String title;
  final String state;
  final int revision;
  final bool workflowEnabled;
  final TeacherAssessment? assessment;
  final String? examGradingOpenedAt;
  final DateTime? dueDate;
  final String description, type, instructions, evaluationCriteria;
  final bool allowLate;

  bool get isWorkDraft =>
      !isExam && canEditAssessment && revision <= 2147483646;
  bool get canCloseWork =>
      !isExam &&
      workflowEnabled &&
      state == 'published' &&
      revision <= 2147483646;
  bool get hasSubmissions => !isExam && state != 'draft';
  bool get isExam => assessment?.isExam ?? false;
  bool get canEditAssessment =>
      state == 'draft' && workflowEnabled && examGradingOpenedAt == null;
  factory TeacherActivity.fromJson(Map<String, dynamic> row) {
    final deadline = row['dueDate'];
    final fields = [
      'description',
      'type',
      'instructions',
      'evaluationCriteria'
    ];
    if ((deadline != null &&
            (deadline is! String || DateTime.tryParse(deadline) == null)) ||
        fields.any((name) => row[name] != null && row[name] is! String) ||
        (row['allowLate'] != null && row['allowLate'] is! bool) ||
        row['id'] is! String ||
        row['classId'] is! String ||
        row['title'] is! String ||
        !['draft', 'published', 'closed'].contains(row['state']) ||
        row['revision'] is! int ||
        (row['revision'] as int) < 1 ||
        row['workflowEnabled'] is! bool ||
        (row['examGradingOpenedAt'] != null &&
            row['examGradingOpenedAt'] is! String)) {
      throw const ApiException('A API retornou uma atividade inválida.');
    }
    return TeacherActivity(
        id: row['id'] as String,
        classId: row['classId'] as String,
        title: row['title'] as String,
        state: row['state'] as String,
        revision: row['revision'] as int,
        workflowEnabled: row['workflowEnabled'] as bool,
        assessment: row['assessment'] == null
            ? null
            : TeacherAssessment.fromJson(row['assessment']),
        examGradingOpenedAt: row['examGradingOpenedAt'] as String?,
        dueDate: deadline is String ? DateTime.parse(deadline) : null,
        description: row['description'] as String? ?? '',
        type: row['type'] as String? ?? 'assignment',
        instructions: row['instructions'] as String? ?? '',
        evaluationCriteria: row['evaluationCriteria'] as String? ?? '',
        allowLate: row['allowLate'] == true);
  }
  String get stateLabel => examGradingOpenedAt != null
      ? 'Pauta aberta'
      : switch (state) {
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

  Future<({List<Map<String, dynamic>> rows, int total})> _page(
      String path, int page, int limit,
      {Map<String, String> filters = const {}}) async {
    final response = await client.get(
      path,
      accessToken: accessToken,
      tenantSlug: tenantSlug,
      queryParams: {...filters, 'page': '$page', 'limit': '$limit'},
    );
    final data = response['data'];
    final meta = response['meta'];
    if (data is! List ||
        data.any((r) => r is! Map<String, dynamic>) ||
        meta is! Map<String, dynamic> ||
        meta['total'] is! int ||
        (meta['total'] as int) < 0 ||
        meta['page'] != page ||
        meta['limit'] != limit) {
      throw const ApiException('A API retornou uma lista inválida.');
    }
    return (
      rows: data.cast<Map<String, dynamic>>(),
      total: meta['total'] as int
    );
  }

  Future<List<Map<String, dynamic>>> _list(String path,
      {Map<String, String> filters = const {}}) async {
    final rows = <Map<String, dynamic>>[];
    for (var page = 1; page <= 100000; page++) {
      final result = await _page(path, page, 100, filters: filters);
      rows.addAll(result.rows);
      if (rows.length >= result.total) return rows;
      if (result.rows.isEmpty) {
        throw const ApiException('A API retornou uma lista incompleta.');
      }
    }
    throw const ApiException('Limite de paginação excedido.');
  }

  Future<List<TeacherOffering>> offerings() async {
    final rows = await _list('$_base/offerings', filters: {'status': 'active'});
    final names = <String, int>{};
    final ids = <String>{};
    for (final r in rows) {
      if (r['id'] is! String ||
          (r['id'] as String).isEmpty ||
          !ids.add(r['id'] as String) ||
          r['name'] is! String ||
          (r['name'] as String).trim().isEmpty ||
          (r['periodId'] != null && r['periodId'] is! String) ||
          r['status'] != 'active') {
        throw const ApiException('A API retornou uma oferta inválida.');
      }
      final name = (r['name'] as String).trim().toLowerCase();
      names[name] = (names[name] ?? 0) + 1;
    }
    final periodIds = {
      for (final row in rows)
        if (names[(row['name'] as String).trim().toLowerCase()]! > 1 &&
            row['periodId'] is String &&
            (row['periodId'] as String).isNotEmpty)
          row['periodId'] as String,
    };
    final periods = Map.fromEntries(await Future.wait(periodIds.map(
      (id) async => MapEntry(id, await _periodLabel(id)),
    )));
    final labels = <String>[];
    final labelCounts = <String, int>{};
    for (final row in rows) {
      final name = (row['name'] as String).trim();
      final period =
          names[name.toLowerCase()]! > 1 ? periods[row['periodId']] : null;
      final label = period == null ? name : '$name • $period';
      labels.add(label);
      final key = label.toLowerCase();
      labelCounts[key] = (labelCounts[key] ?? 0) + 1;
    }
    final used = <String>{};
    return List.generate(rows.length, (index) {
      final row = rows[index];
      final id = row['id'] as String;
      final name = (row['name'] as String).trim();
      var label = labels[index];
      if (labelCounts[label.toLowerCase()]! > 1) {
        final shortId = id.length > 8 ? id.substring(id.length - 8) : id;
        label = '$label • Turma $shortId';
      }
      final baseLabel = label;
      for (var suffix = 2; !used.add(label.toLowerCase()); suffix++) {
        label = '$baseLabel ($suffix)';
      }
      return TeacherOffering(id: id, name: name, label: label);
    });
  }

  Future<String?> _periodLabel(String id) async {
    try {
      final row = await client.get(
        '$_base/academic-periods/${Uri.encodeComponent(id)}',
        accessToken: accessToken,
        tenantSlug: tenantSlug,
      );
      if (row['id'] != id) return null;
      final name = row['name'] is String ? (row['name'] as String).trim() : '';
      final code = row['code'] is String ? (row['code'] as String).trim() : '';
      if (name.isEmpty) return code.isEmpty ? null : code;
      return code.isEmpty || code == name ? name : '$name ($code)';
    } on ApiException catch (error) {
      if (error.statusCode == 401) rethrow;
      return null;
    }
  }

  Future<List<TeacherActivity>> activities(String classId) async {
    final rows = await _list(
        '$_base/classes/${Uri.encodeComponent(classId)}/activities');
    return rows.map((row) => _scoped(row, classId)).toList();
  }

  Future<({List<TeacherActivity> rows, int total})> activityPreview(
      String classId) async {
    final result = await _page(
        '$_base/classes/${Uri.encodeComponent(classId)}/activities', 1, 20);
    return (
      rows: result.rows.map((row) => _scoped(row, classId)).toList(),
      total: result.total,
    );
  }

  Future<List<String>> enrolledStudents(String classId, String tenantId) async {
    final rows = await _list('$_base/enrollments', filters: {
      'classId': classId,
      'status': 'active',
    });
    final students = <String>{};
    for (final row in rows) {
      final studentId = row['studentId'];
      if (row['classId'] != classId ||
          row['tenantId'] != tenantId ||
          row['status'] != 'active' ||
          studentId is! String ||
          studentId.isEmpty ||
          !students.add(studentId)) {
        throw const ApiException('A API retornou uma matrícula inválida.');
      }
    }
    return students.toList();
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
      TeacherAssessment? assessment,
      bool allowLate = false}) async {
    final texts = [title, description, type, instructions, evaluationCriteria];
    if (title.trim().isEmpty ||
        type.trim().isEmpty ||
        texts.any((s) => s.trim().length > 102400)) {
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
          'allowLate': allowLate,
          'state': 'draft',
          if (assessment != null) 'assessment': assessment.toJson(),
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
    if (activity.isExam ||
        activity.state != 'draft' ||
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

  Future<TeacherActivity> updateWorkDraft(TeacherActivity activity,
      {required String title,
      required String description,
      required String type,
      required String instructions,
      required String evaluationCriteria,
      required bool allowLate,
      DateTime? dueDate}) async {
    final fields = {
      'title': title.trim(),
      'description': description.trim(),
      'type': type.trim(),
      'instructions': instructions.trim(),
      'evaluationCriteria': evaluationCriteria.trim(),
    };
    if (!activity.isWorkDraft ||
        fields['title']!.isEmpty ||
        fields['type']!.isEmpty ||
        fields.values.any((text) => text.length > 102400)) {
      throw const ApiException('Confira os campos e o estado do rascunho.');
    }
    final response = await client.put(
      '$_base/activities/${Uri.encodeComponent(activity.id)}',
      {
        ...fields,
        'expectedVersion': activity.revision,
        'allowLate': allowLate,
        if (dueDate != null) 'dueDate': dueDate.toUtc().toIso8601String(),
      },
      accessToken: accessToken,
      tenantSlug: tenantSlug,
    );
    final result = _scoped(response, activity.classId);
    if (result.id != activity.id ||
        result.state != 'draft' ||
        result.isExam ||
        result.revision != activity.revision + 1 ||
        result.title != fields['title'] ||
        result.description != fields['description'] ||
        result.type != fields['type'] ||
        result.instructions != fields['instructions'] ||
        result.evaluationCriteria != fields['evaluationCriteria'] ||
        result.allowLate != allowLate ||
        (dueDate != null &&
            result.dueDate?.isAtSameMomentAs(dueDate) != true)) {
      throw const ApiException('A API não confirmou a edição do rascunho.');
    }
    return result;
  }

  Future<TeacherActivity> closeWork(TeacherActivity activity) async {
    if (!activity.canCloseWork) {
      throw const ApiException('Este trabalho não pode ser encerrado.');
    }
    final response = await client.post(
      '$_base/activities/${Uri.encodeComponent(activity.id)}/close',
      {'expectedVersion': activity.revision},
      accessToken: accessToken,
      tenantSlug: tenantSlug,
    );
    final result = _scoped(response, activity.classId);
    if (result.id != activity.id ||
        result.state != 'closed' ||
        result.isExam ||
        result.revision != activity.revision + 1) {
      throw const ApiException('A API não confirmou o encerramento.');
    }
    return result;
  }

  Future<TeacherActivity> updateAssessment(
      TeacherActivity activity, TeacherAssessment? assessment) async {
    if (!activity.canEditAssessment) {
      throw const ApiException(
          'Os dados acadêmicos desta avaliação estão fixos.');
    }
    final response = await client.put(
      '$_base/activities/${Uri.encodeComponent(activity.id)}',
      {
        'expectedVersion': activity.revision,
        'assessment': assessment?.toJson()
      },
      accessToken: accessToken,
      tenantSlug: tenantSlug,
    );
    final result = _scoped(response, activity.classId);
    if (result.id != activity.id ||
        result.revision != activity.revision + 1 ||
        !result.canEditAssessment ||
        result.assessment?.stage != assessment?.stage ||
        result.assessment?.category != assessment?.category ||
        (assessment != null &&
            academicPointsInCents(result.assessment!.maxPoints) !=
                academicPointsInCents(assessment.maxPoints))) {
      throw const ApiException(
          'A API não confirmou a alteração. Atualize a lista.');
    }
    return result;
  }
}
