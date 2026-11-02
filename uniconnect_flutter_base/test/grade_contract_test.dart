import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uniconnect/core/network/api_client.dart';
import 'package:uniconnect/features/academic/services/academic_api_service.dart';
import 'package:uniconnect/features/grades/models/subject_grade.dart';

void main() {
  Future<List<SubjectGrade>> query(Object payload, {int status = 200}) {
    final client = ApiClient(
        httpClient: MockClient((request) async {
          expect(request.url.path,
              '/api/v1/tenants/campus/students/student/grades');
          expect(request.headers['Authorization'], 'Bearer token');
          expect(request.headers['x-tenant-slug'], 'campus');
          return http.Response(jsonEncode(payload), status);
        }),
        baseUrl: 'https://fixture.invalid/api/v1');
    return AcademicApiService(client).listStudentGrades(
        accessToken: 'token', tenantSlug: 'campus', studentId: 'student');
  }

  test('published nullable assessment is retained rather than rejected',
      () async {
    final result = await query({
      'data': [
        {
          'activityId': 'a',
          'title': 'Pesquisa',
          'grade': null,
          'feedback': 'Revisada'
        }
      ]
    });
    expect(result.single.activityId, 'a');
    expect(result.single.feedback, 'Revisada');
    expect(result.single.grade, isNull);
  });
  test('invalid list envelope is an error rather than empty success', () async {
    await expectLater(query({'data': {}}), throwsA(isA<ApiException>()));
  });
  test('published individual assessments preserve precision, zero and identity',
      () async {
    final result = await query({
      'data': [
        {
          'activityId': 'a',
          'title': 'Pesquisa',
          'grade': 8.567,
          'feedback': 'Bom'
        },
        {'activityId': 'b', 'title': 'Revisão', 'grade': 0},
      ]
    });
    expect(result.map((g) => g.grade), [8.567, 0]);
    expect(result.map((g) => g.activityId), ['a', 'b']);
    expect(result.map((g) => g.subject), ['Pesquisa', 'Revisão']);
    expect(result.first.feedback, 'Bom');
  });
  test('empty published list stays empty', () async {
    expect(await query({'data': []}), isEmpty);
  });
  for (final status in [401, 403, 429, 503]) {
    test('HTTP $status is propagated rather than empty success', () async {
      await expectLater(
          query({
            'error': {'message': 'Falha'}
          }, status: status),
          throwsA(isA<ApiException>()
              .having((e) => e.statusCode, 'status', status)));
    });
  }
  for (final row in [
    null,
    {},
    {'activityId': 'a', 'title': 'T'},
    {'activityId': 'a', 'title': 'T', 'grade': 'inválida'}
  ]) {
    test('invalid assessment $row is rejected', () async {
      await expectLater(
          query({
            'data': [row]
          }),
          throwsA(isA<ApiException>()));
    });
  }
}
