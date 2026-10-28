import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uniconnect/core/network/api_client.dart';
import 'package:uniconnect/features/academic/services/academic_api_service.dart';

void main() {
  test('grade consultation retains activity identity and feedback from the API',
      () async {
    final service = AcademicApiService(ApiClient(
        httpClient: MockClient((_) async => http.Response(
            jsonEncode({
              'data': [
                {
                  'activityId': 'activity-1',
                  'title': 'Pesquisa aplicada',
                  'grade': 8.5,
                  'feedback': 'Argumentação consistente.'
                }
              ]
            }),
            200))));
    final result = await service.listStudentGrades(
        accessToken: 'test', tenantSlug: 'test', studentId: 'student');
    expect(result.single.activityId, 'activity-1');
    expect(result.single.feedback, 'Argumentação consistente.');
    expect(result.single.p1, 8.5);
  });
  test('missing grade is not silently converted to a real zero', () async {
    final service = AcademicApiService(ApiClient(
      httpClient: MockClient((_) async => http.Response(
          jsonEncode({
            'data': [
              {'activityId': 'a', 'title': 'Pesquisa'}
            ]
          }),
          200)),
    ));
    await expectLater(
        service.listStudentGrades(
            accessToken: 'test', tenantSlug: 'test', studentId: 'student'),
        throwsA(isA<ApiException>()));
  });
  test('activities without due date do not acquire an invented deadline',
      () async {
    final service = AcademicApiService(ApiClient(
      httpClient: MockClient((request) async {
        final path = request.url.path;
        final data = path.endsWith('/courses')
            ? [
                {'id': 'course-1'},
              ]
            : path.endsWith('/classes')
                ? [
                    {'id': 'class-1', 'name': 'Métodos Quantitativos'},
                  ]
                : [
                    {'id': 'no-deadline', 'title': 'Pesquisa'},
                    {
                      'id': 'dated',
                      'title': 'Entrega',
                      'dueDate': '2026-12-01T19:00:00Z',
                    },
                  ];
        return http.Response(jsonEncode({'data': data}), 200);
      }),
    ));
    final activities = await service.listActivities(
      accessToken: 'test-token',
      tenantSlug: 'test-tenant',
    );
    final undated = activities.singleWhere((a) => a.id == 'no-deadline');
    expect(undated.dueDate, isNull);
    expect(undated.dueLabel, 'Prazo não informado');
    expect(activities.last.id, 'no-deadline');
  });
}
