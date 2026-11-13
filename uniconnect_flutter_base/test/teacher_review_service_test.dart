import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uniconnect/core/network/api_client.dart';
import 'package:uniconnect/features/academic/services/academic_api_service.dart';
import 'package:uniconnect/features/teacher/services/teacher_review_service.dart';
import 'package:uniconnect/features/teacher/services/grade_precision.dart';
import 'student_activity_contract_test.dart'
    show activityId, response, listJson;
import 'student_submission_service_test.dart' show submissionJson;
import 'package:uniconnect/features/teacher/services/teacher_activity_service.dart';
import 'package:uniconnect/features/activities/services/student_submission_service.dart';
import 'student_activity_contract_test.dart' show activityJson;

Map<String, dynamic> reviewJson(
        {double? grade = 8.5,
        String? feedback = 'Boa resposta',
        int revision = 1,
        String state = 'draft',
        int version = 1}) =>
    {
      'grade': grade,
      'feedback': feedback,
      'revision': revision,
      'submissionVersion': version,
      'publicationState': state,
      'gradedAt': '2026-11-02T20:00:00Z',
    };
Map<String, dynamic> reviewedSubmission({Map<String, dynamic>? result}) => {
      ...submissionJson(),
      'result': result,
      'status': result == null
          ? 'submitted'
          : result['publicationState'] == 'published'
              ? 'result_published'
              : result['grade'] == null
                  ? 'in_review'
                  : 'corrected',
    };
TeacherReviewService reviewApi(
        Future<http.Response> Function(http.Request) callback) =>
    TeacherReviewService(ApiClient(httpClient: MockClient((r) {
      expect(r.headers['Authorization'], 'Bearer token');
      expect(r.headers['x-tenant-slug'], 'campus');
      return callback(r);
    })), accessToken: 'token', tenantSlug: 'campus');

void main() {
  test('decimal representation is checked without binary scaling or rounding', () {
    for (final text in ['7.25', '7.2500', '725e-2', '1e-2', '2.9e-1', '0', '-0.0', '.29', '10.000']) {
      expect(hasGradePrecision(text), isTrue, reason: text);
    }
    for (final text in ['7.255', '7.25000000000000001', '1.00000000000000001', '1e-400', '.', '']) {
      expect(hasGradePrecision(text), isFalse, reason: text);
    }
  });
  for (final grade in <double?>[
    0,
    null,
    1,
    7.2,
    7.25,
    10,
    0.29,
    1.1,
    1e-2,
    7.2500
  ]) {
    test(
        'valid precision $grade is sent and confirmed without numeric transformation',
        () async {
      final api = reviewApi((r) async {
        expect(jsonDecode(r.body)['grade'], grade);
        return response({
          ...reviewJson(grade: grade, feedback: null),
          'grade': grade != null && grade == grade.truncateToDouble()
              ? grade.toInt()
              : grade
        });
      });
      final result = await api.save(
          TeacherSubmission.fromJson(reviewedSubmission(), activityId),
          grade: grade,
          feedback: null);
      expect(result.grade, grade);
    });
  }
  for (final grade in [
    7.255,
    7.2549,
    0.001,
    1e-7,
    0.1 + 0.2,
    1.0000000000000002
  ]) {
    test('precision $grade cannot be silently rounded or accepted with epsilon',
        () async {
      final api =
          reviewApi((_) async => throw StateError('Must not call HTTP'));
      await expectLater(
          api.save(TeacherSubmission.fromJson(reviewedSubmission(), activityId),
              grade: grade, feedback: null),
          throwsA(isA<ApiException>()));
    });
  }
  test('different returned grade remains an invalid confirmation', () async {
    var calls = 0;
    final api = reviewApi((_) async {
      calls++;
      return response(reviewJson(grade: 7.26, feedback: null));
    });
    await expectLater(
        api.save(TeacherSubmission.fromJson(reviewedSubmission(), activityId),
            grade: 7.25, feedback: null),
        throwsA(isA<ApiException>()));
    expect(calls, 1);
  });
  test('excess precision is rejected locally before any HTTP request',
      () async {
    var calls = 0;
    final api = reviewApi((_) async {
      calls++;
      return response(reviewJson(grade: 7.26));
    });
    final row = TeacherSubmission.fromJson(reviewedSubmission(), activityId);
    await expectLater(api.save(row, grade: 7.255, feedback: 'Preservar'),
        throwsA(isA<ApiException>()));
    expect(calls, 0);
  });
  test(
      'local contract cycle uses publication, answer, draft review and published zero grade',
      () async {
    var hasAnswer = false;
    Map<String, dynamic>? review;
    final client = ApiClient(httpClient: MockClient((r) async {
      final path = r.url.path;
      if (path.endsWith('/classes/class-1/activities')) {
        return response({...activityJson(state: 'draft'), 'revision': 1}, 201);
      }
      if (path.endsWith('/activities/$activityId/publish')) {
        return response(activityJson());
      }
      if (path.endsWith('/activities/$activityId/submissions')) {
        if (r.method == 'POST') {
          expect(jsonDecode(r.body)['expectedVersion'], 0);
          hasAnswer = true;
          return response(submissionJson(), 201);
        }
        return response(
            listJson(hasAnswer ? [reviewedSubmission(result: review)] : []));
      }
      if (path.endsWith('/review') && r.method == 'PUT') {
        expect(jsonDecode(r.body)['publish'], false);
        review = reviewJson(grade: 0, feedback: 'Boa resposta');
        return response(review!);
      }
      if (path.endsWith('/review/publish')) {
        review = reviewJson(grade: 0, revision: 2, state: 'published');
        return response(review!);
      }
      if (path.endsWith('/grades')) {
        return response({
          'data': review?['publicationState'] == 'published'
              ? [
                  {
                    'activityId': activityId,
                    'title': 'Pesquisa',
                    'grade': 0,
                    'feedback': 'Boa resposta'
                  }
                ]
              : []
        });
      }
      return response(reviewedSubmission(result: review));
    }));
    final activities = TeacherActivityService(client,
        accessToken: 'teacher', tenantSlug: 'campus');
    final draft = await activities.create('class-1', title: 'Pesquisa');
    await activities.publish(draft);
    await StudentSubmissionService(client,
            accessToken: 'student',
            tenantSlug: 'campus',
            studentId: 'student-test')
        .submit(activityId, answer: 'Minha resposta', expectedVersion: 0);
    final teacher = TeacherReviewService(client,
        accessToken: 'teacher', tenantSlug: 'campus');
    final delivery = (await teacher.list(activityId)).single;
    await teacher.save(delivery, grade: 0, feedback: 'Boa resposta');
    final student = AcademicApiService(client);
    expect(
        await student.listStudentGrades(
            accessToken: 'student',
            tenantSlug: 'campus',
            studentId: 'student-test'),
        isEmpty);
    await teacher.publish(await teacher.find(delivery.id, activityId));
    expect(
        (await student.listStudentGrades(
                accessToken: 'student',
                tenantSlug: 'campus',
                studentId: 'student-test'))
            .single
            .grade,
        0);
  });
  test('invalid write confirmation or mismatched receipt is rejected',
      () async {
    final row = TeacherSubmission.fromJson(reviewedSubmission(), activityId);
    await expectLater(
        reviewApi((_) async => response(reviewJson(revision: 5)))
            .save(row, grade: 8.5, feedback: 'Boa resposta'),
        throwsA(isA<ApiException>()));
    await expectLater(
        reviewApi(
                (_) async => response({...reviewedSubmission(), 'id': 'other'}))
            .find(row.id, activityId),
        throwsA(isA<ApiException>()));
  });
  test('authorized paginated list preserves student ID, answer and review',
      () async {
    var page = 0;
    final api = reviewApi((r) async {
      expect(
          r.url.path.endsWith('/activities/$activityId/submissions'), isTrue);
      page++;
      return response(listJson(
          List.generate(page == 1 ? 100 : 1,
              (_) => reviewedSubmission(result: reviewJson(grade: 0))),
          page: page,
          total: 101));
    });
    final rows = await api.list(activityId);
    expect(rows, hasLength(101));
    expect(rows.first.answer, 'Minha resposta');
    expect(rows.first.studentId, 'student-test');
    expect(rows.first.result!.grade, 0);
  });
  test('empty list is distinct from malformed or cross-activity response',
      () async {
    expect(
        await reviewApi((_) async => response(listJson([]))).list(activityId),
        isEmpty);
    for (final body in [
      {},
      listJson([
        {...submissionJson(), 'activityId': 'other'}
      ])
    ]) {
      await expectLater(reviewApi((_) async => response(body)).list(activityId),
          throwsA(isA<ApiException>()));
    }
  });
  for (final grade in [8.5, 0.0, null]) {
    test('save grade $grade and nullable feedback as draft with both revisions',
        () async {
      final submission =
          TeacherSubmission.fromJson(reviewedSubmission(), activityId);
      final saved = await reviewApi((r) async {
        expect(r.method, 'PUT');
        expect(r.url.path.endsWith('/review'), isTrue);
        expect(jsonDecode(r.body), {
          'expectedRevision': 0,
          'submissionVersion': 1,
          'grade': grade,
          'feedback': null,
          'publish': false
        });
        return response(reviewJson(grade: grade, feedback: null));
      }).save(submission, grade: grade, feedback: null);
      expect(saved.grade, grade);
      expect(saved.publicationState, 'draft');
    });
  }
  test('existing draft uses observed review revision and trims feedback',
      () async {
    final row = TeacherSubmission.fromJson(
        reviewedSubmission(result: reviewJson(revision: 4)), activityId);
    final result = await reviewApi((r) async {
      expect(jsonDecode(r.body)['expectedRevision'], 4);
      expect(jsonDecode(r.body)['feedback'], 'Revisada');
      return response(reviewJson(feedback: 'Revisada', revision: 5));
    }).save(row, grade: 8.5, feedback: ' Revisada ');
    expect(result.revision, 5);
  });
  test('publish is separate and binds the saved revision', () async {
    final row = TeacherSubmission.fromJson(
        reviewedSubmission(result: reviewJson(grade: 0)), activityId);
    final result = await reviewApi((r) async {
      expect(r.method, 'POST');
      expect(r.url.path.endsWith('/review/publish'), isTrue);
      expect(jsonDecode(r.body), {'expectedRevision': 1});
      return response(reviewJson(grade: 0, state: 'published', revision: 2));
    }).publish(row);
    expect(result.publicationState, 'published');
  });
  test('invalid grade and published-to-draft writes never call HTTP', () async {
    final api = reviewApi((_) async => throw StateError('Must not write'));
    final row = TeacherSubmission.fromJson(reviewedSubmission(), activityId);
    for (final grade in [-1.0, 11.0, double.nan, double.infinity]) {
      await expectLater(api.save(row, grade: grade, feedback: null),
          throwsA(isA<ApiException>()));
    }
    await expectLater(api.save(row, grade: 0, feedback: 'x' * 20001),
        throwsA(isA<ApiException>()));
    await expectLater(api.publish(row), throwsA(isA<ApiException>()));
    final published = TeacherSubmission.fromJson(
        reviewedSubmission(result: reviewJson(state: 'published')), activityId);
    await expectLater(api.save(published, grade: 1, feedback: null),
        throwsA(isA<ApiException>()));
  });
  for (final status in [400, 401, 403, 404, 409, 429, 503]) {
    test('HTTP $status remains error with no automatic write retry', () async {
      var calls = 0;
      final api = reviewApi((_) async {
        calls++;
        return response({
          'error': {'message': 'Falha'}
        }, status);
      });
      final row = TeacherSubmission.fromJson(
          reviewedSubmission(result: reviewJson()), activityId);
      final error =
          isA<ApiException>().having((e) => e.statusCode, 'status', status);
      await expectLater(api.list(activityId), throwsA(error));
      await expectLater(
          api.save(row, grade: 8.5, feedback: 'Boa resposta'), throwsA(error));
      await expectLater(api.publish(row), throwsA(error));
      expect(calls, 3);
    });
  }
  test(
      'student grade consultation uses published individual grade including zero',
      () async {
    var published = false;
    final client = ApiClient(httpClient: MockClient((r) async {
      if (r.url.path.endsWith('/grades')) {
        return response({
          'data': published
              ? [
                  {
                    'activityId': activityId,
                    'title': 'Pesquisa',
                    'grade': 0,
                    'feedback': 'Boa resposta'
                  }
                ]
              : []
        });
      }
      published = true;
      return response(reviewJson(grade: 0, revision: 2, state: 'published'));
    }));
    final student = AcademicApiService(client);
    expect(
        await student.listStudentGrades(
            accessToken: 'student',
            tenantSlug: 'campus',
            studentId: 'student-test'),
        isEmpty);
    await TeacherReviewService(client,
            accessToken: 'teacher', tenantSlug: 'campus')
        .publish(TeacherSubmission.fromJson(
            reviewedSubmission(result: reviewJson(grade: 0)), activityId));
    final grades = await student.listStudentGrades(
        accessToken: 'student',
        tenantSlug: 'campus',
        studentId: 'student-test');
    expect(grades.single.grade, 0);
    expect(grades.single.feedback, 'Boa resposta');
  });
}
