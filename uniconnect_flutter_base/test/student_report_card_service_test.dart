import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uniconnect/core/network/api_client.dart';
import 'package:uniconnect/features/academic/services/academic_api_service.dart';
import 'package:uniconnect/features/grades/models/student_report_card.dart';

http.Response reportResponse(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

Map<String, dynamic> reportOffering(String id,
        {String name = 'Métodos', String tenantId = 'tenant-test'}) =>
    {'id': id, 'name': name, 'tenantId': tenantId};

Map<String, dynamic> reportPage(List<Object?> rows,
        {int page = 1, int? total}) =>
    {
      'data': rows,
      'meta': {'page': page, 'limit': 100, 'total': total ?? rows.length}
    };

Map<String, dynamic> reportStage({
  bool closed = false,
  bool applies = true,
  String? examPoints,
  String? activityPoints,
  String? total,
  int pending = 0,
}) =>
    {
      'status': total == null
          ? 'pending'
          : closed
              ? 'definitive'
              : 'partial',
      'closure': {
        'state': closed ? 'closed' : 'open',
        'closedAt': closed ? '2026-11-03T19:00:00Z' : null
      },
      'applies': applies,
      'examPoints': examPoints,
      'activityPoints': activityPoints,
      'total': total,
      'pendingCount': pending,
      'publishedItems': [],
      'pendingItemIds': [],
    };

Map<String, dynamic> reportCardJson({
  String classId = 'class-1',
  String studentId = 'student-test',
  Map<String, dynamic>? n1,
  Map<String, dynamic>? n2,
  String? average,
  String status = 'partial',
}) =>
    {
      'classId': classId,
      'studentId': studentId,
      'studentName': 'Aluno Teste',
      'stages': {'N1': n1 ?? reportStage(), 'N2': n2 ?? reportStage()},
      'average': average,
      'status': status,
    };

void main() {
  test(
      'lists all authorized offering pages without a status filter or student ID',
      () async {
    final requested = <String>[];
    final api = AcademicApiService(ApiClient(
      baseUrl: 'https://fixture.invalid/api/v1',
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/tenants/campus/offerings');
        expect(request.headers['Authorization'], 'Bearer token');
        expect(request.headers['x-tenant-slug'], 'campus');
        final page = request.url.queryParameters['page']!;
        expect(request.url.queryParameters, {'page': page, 'limit': '100'});
        requested.add(page);
        return reportResponse(reportPage([reportOffering('class-$page')],
            page: int.parse(page), total: 2));
      }),
    ));
    final rows = await api.listStudentReportOfferings(
      accessToken: 'token',
      tenantSlug: 'campus',
      tenantId: 'tenant-test',
    );
    expect(requested, ['1', '2']);
    expect(rows.map((row) => (row.id, row.name)),
        [('class-1', 'Métodos'), ('class-2', 'Métodos')]);
  });

  test(
      'requests only the self endpoint by class and preserves exact decimal strings',
      () async {
    final api = AcademicApiService(ApiClient(
      baseUrl: 'https://fixture.invalid/api/v1',
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path,
            '/api/v1/tenants/campus/classes/class-2/report-card/me');
        expect(request.url.queryParameters, isEmpty);
        expect(request.headers['Authorization'], 'Bearer token');
        expect(request.headers['x-tenant-slug'], 'campus');
        return reportResponse(reportCardJson(
          classId: 'class-2',
          n1: reportStage(
              closed: true,
              examPoints: '6.99',
              activityPoints: '0.00999',
              total: '6.99999'),
          n2: reportStage(
              closed: true,
              examPoints: '7.00',
              activityPoints: '0.00',
              total: '7.00'),
          average: '6.999995',
          status: 'final_exam_eligible',
        ));
      }),
    ));
    final card = await api.getStudentReportCard(
      accessToken: 'token',
      tenantSlug: 'campus',
      classId: 'class-2',
      studentId: 'student-test',
    );
    expect(card.n1.activityPoints, '0.00999');
    expect(card.n2.activityPoints, '0.00');
    expect(card.average, '6.999995');
    expect(card.status, ReportCardStatus.finalExamEligible);
  });

  test('rejects mismatched tenant, offer, student and malformed result', () {
    expect(
        () => StudentReportOffering.fromJson(
            reportOffering('class-1', tenantId: 'other'), 'tenant-test'),
        throwsA(isA<ApiException>()));
    for (final payload in [
      reportCardJson(classId: 'class-2'),
      reportCardJson(studentId: 'other-student'),
      reportCardJson(average: '7.00'),
      reportCardJson(status: 'approved', average: '7.00'),
      reportCardJson(n1: {...reportStage(), 'examPoints': 0}),
    ]) {
      expect(
          () => StudentReportCard.fromJson(payload,
              classId: 'class-1', studentId: 'student-test'),
          throwsA(isA<ApiException>()));
    }
  });
}
