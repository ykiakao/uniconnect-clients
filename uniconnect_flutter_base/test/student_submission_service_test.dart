import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';
import 'package:uniconnect/core/network/api_client.dart';
import 'package:uniconnect/features/activities/services/student_submission_service.dart';
import 'student_activity_contract_test.dart' show activityId, response;

Map<String, dynamic> submissionJson(
        {int version = 1,
        String answer = 'Minha resposta',
        String status = 'submitted'}) =>
    {
      'id': '00000000-0000-4000-8000-000000000002',
      'activityId': activityId,
      'studentId': 'student-test',
      'version': version,
      'answer': answer,
      'submittedAt': '2026-11-02T18:00:00Z',
      'isLate': status == 'late',
      'status': status,
      'result': null,
    };
const noSubmission = {'status': 'not_submitted', 'submission': null};
StudentSubmissionService api(
        Future<http.Response> Function(http.Request) handler) =>
    StudentSubmissionService(ApiClient(httpClient: MockClient((r) {
      expect(r.headers['Authorization'], 'Bearer token');
      expect(r.headers['x-tenant-slug'], 'campus');
      return handler(r);
    })), accessToken: 'token', tenantSlug: 'campus', studentId: 'student-test');

void main() {
  test('own absence is explicit and calls only personal endpoint', () async {
    final result = await api((r) async {
      expect(r.url.path.endsWith('/activities/$activityId/submissions/me'),
          isTrue);
      expect(r.method, 'GET');
      return response(noSubmission);
    }).own(activityId);
    expect(result, isNull);
  });
  test('own receipt preserves answer, version, late and review states',
      () async {
    for (final status in [
      'submitted',
      'late',
      'in_review',
      'corrected',
      'result_published'
    ]) {
      final result =
          await api((_) async => response(submissionJson(status: status)))
              .own(activityId);
      expect(result!.version, 1);
      expect(result.answer, 'Minha resposta');
      expect(result.status, status);
      expect(result.canRevise, ['submitted', 'late'].contains(status));
    }
  });
  test('result requires publication in both the receipt and the evaluation',
      () async {
    for (final (status, publicationState) in [
      ('corrected', 'draft'),
      ('result_published', 'draft'),
      ('in_review', 'published'),
    ]) {
      final receipt = await api((_) async => response({
            ...submissionJson(status: status),
            'result': {
              'publicationState': publicationState,
              'grade': 9.75,
              'feedback': 'Comentário do professor.',
            },
          })).own(activityId);
      expect(receipt!.result, isNull);
      expect(receipt.statusLabel, isNot('Resultado publicado'));
      expect(receipt.canRevise, isFalse);
    }
  });
  test('published result preserves zero, decimals, absence and feedback',
      () async {
    for (final grade in [0, 8.75, null]) {
      final receipt = await api((_) async => response({
            ...submissionJson(status: 'result_published'),
            'result': {
              'publicationState': 'published',
              'grade': grade,
              'feedback': 'Boa análise.\nRevise a conclusão.',
            },
          })).own(activityId);
      expect(receipt!.result!.grade, grade);
      expect(receipt.result!.feedback, 'Boa análise.\nRevise a conclusão.');
      expect(receipt.statusLabel, 'Resultado publicado');
    }
  });
  test(
      'initial answer sends version zero and no student or tenant identity in body',
      () async {
    final result = await api((r) async {
      expect(r.method, 'POST');
      expect(
          r.url.path.endsWith('/activities/$activityId/submissions'), isTrue);
      expect(jsonDecode(r.body),
          {'answer': 'Minha resposta', 'expectedVersion': 0});
      return response(submissionJson(), 201);
    }).submit(activityId, answer: ' Minha resposta ', expectedVersion: 0);
    expect(result.version, 1);
  });
  test(
      'revision sends observed submission version rather than activity revision',
      () async {
    final result = await api((r) async {
      expect(jsonDecode(r.body)['expectedVersion'], 3);
      return response(submissionJson(version: 4, answer: 'Revisada'), 201);
    }).submit(activityId, answer: 'Revisada', expectedVersion: 3);
    expect(result.version, 4);
  });
  test('empty, oversized and invalid version never call HTTP', () async {
    final service =
        api((_) async => throw StateError('HTTP must not be called'));
    for (final text in [' ', 'x' * 20001]) {
      await expectLater(
          service.submit(activityId, answer: text, expectedVersion: 0),
          throwsA(isA<ApiException>()));
    }
    await expectLater(
        service.submit(activityId, answer: 'Texto', expectedVersion: -1),
        throwsA(isA<ApiException>()));
  });
  for (final status in [400, 401, 403, 404, 409, 429, 503]) {
    test('HTTP $status is preserved by query and write with no automatic retry',
        () async {
      var calls = 0;
      final service = api((_) async {
        calls++;
        return response({
          'error': {'message': 'Falha'}
        }, status);
      });
      final failure =
          isA<ApiException>().having((e) => e.statusCode, 'status', status);
      await expectLater(service.own(activityId), throwsA(failure));
      await expectLater(
          service.submit(activityId,
              answer: 'Minha resposta', expectedVersion: 0),
          throwsA(failure));
      expect(calls, 2);
    });
  }
  test(
      'invalid receipt, other student or activity and false confirmation are rejected',
      () async {
    for (final row in [
      {},
      {'status': 'not_submitted'},
      {...submissionJson(), 'studentId': 'someone-else'},
      {...submissionJson(), 'activityId': 'other'},
      {...submissionJson(), 'version': 0}
    ]) {
      await expectLater(api((_) async => response(row)).own(activityId),
          throwsA(isA<ApiException>()));
    }
    await expectLater(
        api((_) async => response(submissionJson(version: 3)))
            .submit(activityId, answer: 'Minha resposta', expectedVersion: 0),
        throwsA(isA<ApiException>()));
  });
}
