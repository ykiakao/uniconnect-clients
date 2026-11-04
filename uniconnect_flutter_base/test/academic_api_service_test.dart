import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uniconnect/core/network/api_client.dart';
import 'package:uniconnect/features/academic/services/academic_api_service.dart';
import 'package:uniconnect/features/activities/models/academic_activity.dart';

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
    expect(result.single.grade!, 8.5);
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
                    {
                      'id': 'no-deadline',
                      'title': 'Pesquisa',
                      'classId': 'class-1',
                      'state': 'published',
                      'allowLate': false
                    },
                    {
                      'id': 'dated',
                      'classId': 'class-1',
                      'state': 'published',
                      'allowLate': false,
                      'title': 'Entrega',
                      'dueDate': '2026-12-01T14:00:00-05:00',
                      'priority': 'high',
                    },
                  ];
        return http.Response(
            jsonEncode({
              'data': data,
              'meta': {'page': 1, 'limit': 100, 'total': data.length}
            }),
            200);
      }),
    ));
    final activities = await service.listActivities(
      accessToken: 'test-token',
      tenantSlug: 'test-tenant',
    );
    final undated = activities.singleWhere((a) => a.id == 'no-deadline');
    expect(undated.dueDate, isNull);
    final due = DateTime.utc(2026, 12, 1, 19);
    expect(undated.dueLabelAt(due), 'Prazo não informado');
    expect(undated.priorityAt(due), ActivityPriority.noDeadline);
    expect(activities.last.id, 'no-deadline');
    final dated = activities.first;
    expect(dated.dueDate, due);
    for (final (remaining, expected) in [
      (const Duration(days: 3), ActivityPriority.critical),
      (const Duration(days: 3, microseconds: 1), ActivityPriority.medium),
      (const Duration(days: 4), ActivityPriority.medium),
      (const Duration(days: 5), ActivityPriority.medium),
      (const Duration(days: 5, microseconds: 1), ActivityPriority.low),
      (const Duration(days: 6), ActivityPriority.low),
      (Duration.zero, ActivityPriority.critical),
      (const Duration(microseconds: -1), ActivityPriority.expired),
    ]) {
      expect(dated.priorityAt(due.subtract(remaining)), expected,
          reason: 'Tempo restante: $remaining');
    }
  });
}
