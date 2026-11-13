import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uniconnect/core/network/api_client.dart';
import 'package:uniconnect/features/teacher/services/teacher_activity_service.dart';

Map<String, dynamic> activityRow({String state = 'draft', int revision = 1}) =>
    {
      'id': '00000000-0000-4000-8000-000000000001',
      'classId': 'class-1',
      'title': 'Pesquisa',
      'state': state,
      'revision': revision,
      'workflowEnabled': true,
      'description': 'Descrição',
      'type': 'assignment',
      'priority': 'medium',
      'allowLate': false,
    };
Map<String, dynamic> page(List<Object?> rows, {int page = 1, int? total}) => {
      'data': rows,
      'meta': {'page': page, 'limit': 100, 'total': total ?? rows.length},
    };
TeacherActivityService service(
        Future<http.Response> Function(http.Request) handler) =>
    TeacherActivityService(
        ApiClient(
            baseUrl: 'https://fixture.invalid/api/v1',
            httpClient: MockClient((request) {
              expect(request.headers['Authorization'], 'Bearer fixture-token');
              expect(request.headers['x-tenant-slug'], 'campus');
              return handler(request);
            })),
        accessToken: 'fixture-token',
        tenantSlug: 'campus');
http.Response jsonResponse(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status);

void main() {
  test('create sends only real contract fields and awaits draft confirmation',
      () async {
    final api = service((r) async {
      expect(r.method, 'POST');
      expect(r.url.path, '/api/v1/tenants/campus/classes/class-1/activities');
      expect(jsonDecode(r.body), {
        'title': 'Pesquisa',
        'description': 'Descrição',
        'type': 'assignment',
        'instructions': 'Leia',
        'evaluationCriteria': 'Clareza',
        'allowLate': true,
        'state': 'draft',
        'dueDate': '2026-11-10T18:00:00.000Z',
      });
      return jsonResponse(activityRow(), 201);
    });
    final result = await api.create('class-1',
        title: ' Pesquisa ',
        description: 'Descrição',
        instructions: 'Leia',
        evaluationCriteria: 'Clareza',
        allowLate: true,
        dueDate: DateTime.parse('2026-11-10T13:00:00-05:00'));
    expect(result.state, 'draft');
    expect(result.revision, 1);
  });
  test('publication uses latest observed revision and direct object response',
      () async {
    final api = service((r) async {
      expect(r.url.path.endsWith('/publish'), isTrue);
      expect(jsonDecode(r.body), {'expectedVersion': 4});
      return jsonResponse(activityRow(state: 'published', revision: 5));
    });
    final result =
        await api.publish(TeacherActivity.fromJson(activityRow(revision: 4)));
    expect(result.state, 'published');
    expect(result.revision, 5);
  });
  test('offerings consumes every authorized page with active filter', () async {
    var calls = 0;
    final api = service((r) async {
      calls++;
      expect(r.url.path.endsWith('/offerings'), isTrue);
      expect(r.url.queryParameters['status'], 'active');
      return jsonResponse(page([
        {'id': 'class-$calls', 'name': 'Oferta $calls', 'status': 'active'}
      ], page: calls, total: 2));
    });
    expect((await api.offerings()).map((o) => o.id), ['class-1', 'class-2']);
    expect(calls, 2);
  });
  test('activities retain state and revisions', () async {
    final api = service((r) async => jsonResponse(
        page([activityRow(), activityRow(state: 'published', revision: 2)])));
    final list = await api.activities('class-1');
    expect(list.map((a) => a.state), ['draft', 'published']);
    expect(list.map((a) => a.revision), [1, 2]);
  });
  test('only homonymous disciplines need a period or short identifier',
      () async {
    final periods = <String>[];
    final api = service((request) async {
      final path = request.url.path;
      if (path.endsWith('/offerings')) {
        return jsonResponse(page([
          {
            'id': 'class-unique',
            'name': 'Banco de Dados',
            'status': 'active',
            'periodId': 'unused'
          },
          for (var i = 1; i <= 3; i++)
            {
              'id': '10000000-0000-4000-8000-00000000000$i',
              'name': 'Métodos',
              'status': 'active',
              'periodId': i == 3 ? 'period-b' : 'period-a',
            },
        ]));
      }
      final id = request.url.pathSegments.last;
      periods.add(id);
      return jsonResponse(
          {'id': id, 'name': id == 'period-a' ? '2026.1' : '2026.2'});
    });
    final offerings = await api.offerings();
    expect(periods, unorderedEquals(['period-a', 'period-b']));
    expect(offerings.map((offering) => offering.label), [
      'Banco de Dados',
      'Métodos • 2026.1 • Turma 00000001',
      'Métodos • 2026.1 • Turma 00000002',
      'Métodos • 2026.2',
    ]);
    expect(offerings[3].id, '10000000-0000-4000-8000-000000000003');
  });
  test('invalid form does not write', () async {
    final api = service((_) async => throw StateError('Must not call HTTP'));
    await expectLater(
        api.create('class-1', title: '  '), throwsA(isA<ApiException>()));
    await expectLater(api.create('class-1', title: 'T', type: '  '),
        throwsA(isA<ApiException>()));
    await expectLater(
        api.publish(TeacherActivity.fromJson(activityRow(state: 'closed'))),
        throwsA(isA<ApiException>()));
  });
  for (final status in [400, 401, 403, 404, 409, 429, 503]) {
    test('HTTP $status propagates for creation and publication without retries',
        () async {
      var calls = 0;
      final api = service((_) async {
        calls++;
        return jsonResponse({
          'error': {'message': 'Falha'}
        }, status);
      });
      final failure =
          isA<ApiException>().having((e) => e.statusCode, 'status', status);
      await expectLater(api.create('class-1', title: 'T'), throwsA(failure));
      await expectLater(api.publish(TeacherActivity.fromJson(activityRow())),
          throwsA(failure));
      expect(calls, 2);
    });
  }
  test(
      'invalid list, cross-offering data and unconfirmed publication are rejected',
      () async {
    await expectLater(
        service((_) async => jsonResponse({'data': []})).offerings(),
        throwsA(isA<ApiException>()));
    await expectLater(
        service((_) async => jsonResponse(page([activityRow()])))
            .activities('other'),
        throwsA(isA<ApiException>()));
    await expectLater(
        service((_) async => jsonResponse(activityRow()))
            .publish(TeacherActivity.fromJson(activityRow())),
        throwsA(isA<ApiException>()));
  });
}
