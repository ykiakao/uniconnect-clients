import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uniconnect/core/network/api_client.dart';
import 'package:uniconnect/features/academic/services/academic_api_service.dart';

const activityId = '00000000-0000-4000-8000-000000000001';
Map<String, dynamic> activityJson(
        {String state = 'published', bool allowLate = false}) =>
    {
      'id': activityId,
      'classId': 'class-1',
      'title': 'Pesquisa',
      'description': 'Contexto',
      'instructions': 'Responda em texto',
      'evaluationCriteria': 'Clareza',
      'state': state,
      'allowLate': allowLate,
      'workflowEnabled': true,
      'revision': 2,
      'priority': 'medium',
      'type': 'assignment',
    };
Map<String, dynamic> listJson(List<Object?> rows, {int page = 1, int? total}) =>
    {
      'data': rows,
      'meta': {'page': page, 'limit': 100, 'total': total ?? rows.length},
    };
http.Response response(Object value, [int status = 200]) =>
    http.Response(jsonEncode(value), status);

void main() {
  test(
      'individual detail uses authorized endpoint and preserves instructions and closing state',
      () async {
    final service =
        AcademicApiService(ApiClient(httpClient: MockClient((r) async {
      expect(r.headers['Authorization'], 'Bearer token');
      expect(r.headers['x-tenant-slug'], 'campus');
      return r.url.path.endsWith('/classes/class-1')
          ? response({'id': 'class-1', 'name': 'Métodos'})
          : response(activityJson(state: 'closed'));
    })));
    final detail = await service.getActivity(
        accessToken: 'token', tenantSlug: 'campus', id: activityId);
    expect(detail.subject, 'Métodos');
    expect(detail.instructions, 'Responda em texto');
    expect(detail.publicationState, 'closed');
  });
  test(
      'authorized historical activity remains readable when class metadata is denied',
      () async {
    final service = AcademicApiService(ApiClient(
        httpClient:
            MockClient((r) async => r.url.path.endsWith('/classes/class-1')
                ? response({
                    'error': {'message': 'Vínculo histórico'}
                  }, 404)
                : response(activityJson(state: 'closed')))));
    final detail = await service.getActivity(
        accessToken: 'token', tenantSlug: 'campus', id: activityId);
    expect(detail.subject, contains('Disciplina indisponível'));
    expect(detail.title, 'Pesquisa');
  });
  test(
      'all activity pages are read and malformed lists or drafts never become successful visible records',
      () async {
    var pages = 0;
    final service =
        AcademicApiService(ApiClient(httpClient: MockClient((r) async {
      if (r.url.path.endsWith('/courses')) {
        return response(listJson([
          {'id': 'course-1'}
        ]));
      }
      if (r.url.path.endsWith('/classes')) {
        return response(listJson([
          {'id': 'class-1', 'name': 'Métodos'}
        ]));
      }
      pages++;
      return response(listJson(
          List.generate(pages == 1 ? 100 : 1,
              (i) => {...activityJson(), 'id': 'a-$pages-$i'}),
          page: pages,
          total: 101));
    })));
    expect(
        await service.listActivities(
            accessToken: 'token', tenantSlug: 'campus'),
        hasLength(101));
    expect(pages, 2);
    for (final payload in [
      {},
      listJson([activityJson(state: 'draft')])
    ]) {
      final invalid =
          AcademicApiService(ApiClient(httpClient: MockClient((r) async {
        if (r.url.path.endsWith('/courses')) {
          return response(listJson([
            {'id': 'course-1'}
          ]));
        }
        if (r.url.path.endsWith('/classes')) {
          return response(listJson([
            {'id': 'class-1', 'name': 'Métodos'}
          ]));
        }
        return response(payload);
      })));
      await expectLater(
          invalid.listActivities(accessToken: 'token', tenantSlug: 'campus'),
          throwsA(isA<ApiException>()));
    }
  });
  test('student activity list retains real evaluation criteria', () async {
    final service =
        AcademicApiService(ApiClient(httpClient: MockClient((r) async {
      if (r.url.path.endsWith('/courses')) {
        return response(listJson([
          {'id': 'course-1'}
        ]));
      }
      if (r.url.path.endsWith('/classes')) {
        return response(listJson([
          {'id': 'class-1', 'name': 'Métodos'}
        ]));
      }
      return response(listJson([activityJson()]));
    })));
    final result = await service.listActivities(
        accessToken: 'token', tenantSlug: 'campus');
    expect(result.single.criteria, ['Clareza']);
  });
}
