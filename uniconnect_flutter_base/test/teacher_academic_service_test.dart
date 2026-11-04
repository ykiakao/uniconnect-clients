import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniconnect/core/network/api_client.dart';
import 'package:uniconnect/features/teacher/services/teacher_academic_service.dart';
import 'package:uniconnect/features/teacher/services/teacher_activity_service.dart';
import 'package:uniconnect/features/teacher/services/teacher_assessment.dart';
import 'teacher_activity_service_test.dart'
    show activityRow, jsonResponse, service;

Map<String, dynamic> academicPage(List<Map<String, dynamic>> rows,
        {int number = 1, int? total}) =>
    {
      'data': rows,
      'meta': {'page': number, 'limit': 20, 'total': total ?? rows.length},
    };

Map<String, dynamic> examResult(String points, int revision,
        {bool published = false}) =>
    {
      'points': points,
      'revision': revision,
      'unit': 'exam_points',
      'publicationState': published ? 'published' : 'draft'
    };

Map<String, dynamic> rosterJson(
        {String id = 'exam-1',
        bool opened = true,
        int page = 1,
        int revision = 9,
        int? total,
        List<Map<String, dynamic>>? students}) =>
    {
      'examId': id,
      'stage': 'N1',
      'maxPoints': '7.00',
      'revision': revision,
      'gradingOpenedAt': opened ? '2026-11-03T19:00:00Z' : null,
      ...academicPage(students ?? [], number: page, total: total),
    };

Map<String, dynamic> studentJson(String id, String name,
        [Map<String, dynamic>? grade]) =>
    {'studentId': id, 'studentName': name, 'result': grade};

Map<String, dynamic> stageJson(String classId, String stage,
        {bool closed = false, bool blocked = false, int page = 1}) =>
    {
      'classId': classId,
      'stage': stage,
      'closure': {
        'state': closed ? 'closed' : 'open',
        'closedAt': closed ? '2026-11-03T19:00:00Z' : null
      },
      'eligibleCount': 1,
      'assessmentCount': 2,
      'blockers': blocked ? ['pending_assessments'] : [],
      ...academicPage(
          blocked
              ? [
                  {
                    'studentId': 'student-1',
                    'itemId': 'item-1',
                    'title': 'Prova pendente',
                    'reason': 'draft_grade'
                  },
                ]
              : [],
          number: page),
    };

Map<String, dynamic> reportJson(String id, String name,
        {bool closed = false}) =>
    {
      'studentId': id,
      'studentName': name,
      'status': closed ? 'final_exam_eligible' : 'partial',
      'average': closed ? '6.999995' : null,
      'stages': {
        'N1': {
          'closure': {'state': closed ? 'closed' : 'open'},
          'status': closed ? 'definitive' : 'partial',
          'applies': true,
          'total': '6.99999',
          'examPoints': '6.99',
          'activityPoints': '0.00999',
          'pendingCount': 0
        },
        'N2': {
          'closure': {'state': closed ? 'closed' : 'open'},
          'status': closed ? 'definitive' : 'pending',
          'applies': true,
          'total': closed ? '7.00' : null,
          'pendingCount': closed ? 0 : 1
        },
      },
    };

void main() {
  test('creates and edits scoped academic metadata using current revision',
      () async {
    final assessment = const TeacherAssessment(
        stage: 'N2', category: 'activity', maxPoints: '1,50');
    final json = {'stage': 'N2', 'category': 'activity', 'maxPoints': '1.50'};
    final api = service((r) async {
      expect(r.headers['Authorization'], 'Bearer fixture-token');
      expect(r.headers['x-tenant-slug'], 'campus');
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      if (r.method == 'POST') {
        expect(data['assessment'], json);
        return jsonResponse({...activityRow(revision: 6), 'assessment': json});
      }
      expect(r.method, 'PUT');
      expect(data, {'expectedVersion': 6, 'assessment': null});
      return jsonResponse(activityRow(revision: 7));
    });
    final draft =
        await api.create('class-1', title: 'Trabalho', assessment: assessment);
    expect(draft.assessment!.stage, 'N2');
    expect((await api.updateAssessment(draft, null)).assessment, isNull);
    final opened = TeacherActivity.fromJson({
      ...activityRow(),
      'assessment': {'stage': 'N1', 'category': 'exam', 'maxPoints': '7.00'},
      'examGradingOpenedAt': '2026-11-03T19:00:00Z',
    });
    await expectLater(
        api.updateAssessment(opened, assessment), throwsA(isA<ApiException>()));
    await expectLater(api.publish(opened), throwsA(isA<ApiException>()));
  });

  test(
      'validates item limits and preserves the decimal strings sent to the API',
      () {
    expect(academicPointsPayload('0,00', '7.00'), '0.00');
    expect(academicPointsPayload('5,50', '7.00'), '5.50');
    for (final bad in ['-1', '3,01', '1,234', '1e0', '']) {
      expect(() => academicPointsPayload(bad, '3.00'),
          throwsA(isA<ApiException>()));
    }
  });

  test(
      'reads paginated roster, distinguishes zero from absence and preserves CAS',
      () async {
    final requests = <Object?>[];
    final api = TeacherAcademicService(service((r) async {
      expect(r.headers['Authorization'], 'Bearer fixture-token');
      expect(r.headers['x-tenant-slug'], 'campus');
      expect(r.url.path,
          startsWith('/api/v1/tenants/campus/activities/exam-1/exam'));
      if (r.method == 'GET') {
        expect(r.url.queryParameters, {'page': '2', 'limit': '20'});
        return jsonResponse(rosterJson(page: 2, total: 23, students: [
          studentJson('new', 'Sem nota'),
          studentJson('draft', 'Com nota', examResult('0.00', 6)),
          studentJson(
              'published', 'Publicado', examResult('5.50', 9, published: true)),
        ]));
      }
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      requests.add(data);
      if (r.url.path.endsWith('/activate')) {
        return jsonResponse({
          'examId': 'exam-1',
          'revision': 10,
          'gradingOpenedAt': '2026-11-03T19:00:00Z'
        });
      }
      final revision = data['expectedRevision'] as int;
      return jsonResponse(examResult(
          data['points'] as String? ?? '0.00', revision + 1,
          published: r.method == 'POST'));
    }));
    final roster = await api.roster('exam-1', page: 2);
    expect(roster.students.hasNext, isFalse);
    final [missing, zero, published] = roster.students.rows;
    expect(missing.grade, isNull);
    expect(zero.grade!.points, '0.00');
    await api.activate(roster);
    await api.save(roster, missing, '0,00');
    await api.save(roster, zero, '5,50');
    await api.publish(roster, zero);
    await api.publish(roster, published, points: '0,00');
    expect(requests, [
      {'expectedVersion': 9},
      {'expectedRevision': 0, 'points': '0.00'},
      {'expectedRevision': 6, 'points': '5.50'},
      {'expectedRevision': 6},
      {'expectedRevision': 9, 'points': '0.00'},
    ]);
  });

  test(
      'reads official results, scopes detail and stage state, and preserves 409',
      () async {
    final api = TeacherAcademicService(service((r) async {
      final path = r.url.path;
      if (path.endsWith('/close')) {
        expect(jsonDecode(r.body), {});
        return jsonResponse({
          'error': {'message': 'Etapa com pendências', 'code': 'DATA_CONFLICT'}
        }, 409);
      }
      if (path.endsWith('/stages/N2')) {
        return jsonResponse(stageJson('class-1', 'N2', blocked: true));
      }
      if (path.endsWith('/students/student-1')) {
        return jsonResponse(
            {'classId': 'class-2', ...reportJson('student-1', 'Aluno')});
      }
      return jsonResponse({
        'classId': 'class-1',
        ...academicPage([reportJson('student-1', 'Aluno', closed: true)])
      });
    }));
    final card = (await api.summary('class-1')).rows.single;
    expect(card.average, '6.999995');
    expect(card.statusLabel, 'Elegível à prova final');
    expect(card.n1.activityPoints, '0.00999');
    expect((await api.stage('class-1', 'N2')).canClose, isFalse);
    await expectLater(api.studentReport('class-1', 'student-1'),
        throwsA(isA<ApiException>()));
    await expectLater(
        api.close('class-1', 'N2'),
        throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'status', 409)));
  });
}
