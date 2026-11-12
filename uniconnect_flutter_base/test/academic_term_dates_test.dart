import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uniconnect/core/network/api_client.dart';
import 'package:uniconnect/features/academic/demo/synthetic_academic_providers.dart';
import 'package:uniconnect/features/academic/models/academic_records.dart';
import 'package:uniconnect/features/academic/providers/academic_records_providers.dart';
import 'package:uniconnect/features/academic/services/academic_records_service.dart';
import 'package:uniconnect/features/communication/providers/communication_providers.dart';
import 'package:uniconnect/features/student/presentation/student_academic_page.dart';

import 'demo_day_test.dart' show pumpDemoPage;

Map<String, dynamic> _term(
        {String? start = '2031-01-15', String? end = '2031-06-20'}) =>
    {
      'id': 'term-test',
      'name': 'Período retornado pela API',
      'status': 'active',
      'startDate': start,
      'endDate': end,
    };

http.Response _response(List<Object> data) => http.Response(
    jsonEncode({
      'data': data,
      'meta': {'page': 1, 'limit': 100, 'total': data.length},
    }),
    200,
    headers: {'content-type': 'application/json'});

Future<void> _pump(WidgetTester tester,
    Future<http.Response> Function(http.Request) handler) async {
  await pumpDemoPage(tester, const StudentAcademicPage(), overrides: [
    syntheticDemoRequestedProvider.overrideWithValue(false),
    unreadNotificationsProvider.overrideWith((ref) async => 0),
    academicRecordsServiceProvider.overrideWithValue(AcademicRecordsService(
      ApiClient(
          baseUrl: 'https://fixture.invalid/api/v1',
          httpClient: MockClient(handler)),
      accessToken: 'test-access-token',
      tenantSlug: 'campus',
    )),
    academicPeriodsProvider.overrideWith((ref) async => const []),
    academicOverviewProvider
        .overrideWith((ref, _) async => const AcademicOverviewRecord(
              period: AcademicPeriodRef(id: 'p1'),
              subjects: [],
            )),
    academicHistoryProvider
        .overrideWith((ref) async => const AcademicHistoryRecord(periods: [])),
  ]);
}

void main() {
  testWidgets('shows API term dates using authenticated tenant HTTP requests',
      (tester) async {
    final requests = <http.Request>[];
    await _pump(tester, (request) async {
      requests.add(request);
      return _response([_term()]);
    });
    await tester.pumpAndSettle();
    expect(find.text('Período letivo'), findsOneWidget);
    expect(find.text('Período retornado pela API'), findsOneWidget);
    expect(find.text('Início: 15/01/2031'), findsOneWidget);
    expect(find.text('Fim: 20/06/2031'), findsOneWidget);
    expect(
        find.text(
            'Horários semanais e eventos institucionais ainda indisponíveis.'),
        findsOneWidget);
    expect(requests, hasLength(1));
    expect(requests.single.method, 'GET');
    expect(requests.single.url.path, '/api/v1/tenants/campus/academic-periods');
    expect(requests.single.url.queryParameters,
        {'status': 'active', 'page': '1', 'limit': '100'});
    expect(
        requests.single.headers['authorization'], 'Bearer test-access-token');
    expect(requests.single.headers['x-tenant-slug'], 'campus');
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps missing dates distinct from available dates',
      (tester) async {
    await _pump(tester, (_) async => _response([_term(end: null)]));
    await tester.pumpAndSettle();
    expect(find.text('Início: 15/01/2031'), findsOneWidget);
    expect(find.text('Fim: Não informado'), findsOneWidget);
  });

  testWidgets('explains an empty active term catalogue', (tester) async {
    await _pump(tester, (_) async => _response([]));
    await tester.pumpAndSettle();
    expect(
        find.text('Nenhum período letivo ativo disponível.'), findsOneWidget);
    expect(find.textContaining('Início:'), findsNothing);
  });

  testWidgets('shows loading until the HTTP request completes', (tester) async {
    final pending = Completer<http.Response>();
    await _pump(tester, (_) => pending.future);
    expect(
        find.byWidgetPredicate((widget) =>
            widget is LinearProgressIndicator &&
            widget.semanticsLabel == 'Carregando período letivo'),
        findsOneWidget);
    expect(find.text('Nenhum período letivo ativo disponível.'), findsNothing);
    pending.complete(_response([_term()]));
    await tester.pumpAndSettle();
    expect(find.text('Início: 15/01/2031'), findsOneWidget);
  });

  testWidgets('retries a failed term request without changing academic records',
      (tester) async {
    var attempts = 0;
    await _pump(
        tester,
        (_) async => attempts++ == 0
            ? http.Response(
                jsonEncode({
                  'error': {
                    'code': 'UNAVAILABLE',
                    'message': 'Consulta temporariamente indisponível.'
                  }
                }),
                503)
            : _response([_term()]));
    await tester.pumpAndSettle();
    expect(find.text('Consulta temporariamente indisponível.'), findsOneWidget);
    await tester.ensureVisible(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Início: 15/01/2031'), findsOneWidget);
  });

  testWidgets('uses the existing expired-session error presentation',
      (tester) async {
    await _pump(
        tester,
        (_) async => http.Response(
            jsonEncode({
              'error': {'code': 'INVALID_SESSION', 'message': 'expired'},
            }),
            401));
    await tester.pumpAndSettle();
    expect(find.text('Sessão inválida ou expirada. Entre novamente.'),
        findsOneWidget);
    expect(find.textContaining('Início:'), findsNothing);
  });

  testWidgets('does not silently normalize an impossible date', (tester) async {
    await _pump(tester, (_) async => _response([_term(start: '2031-02-30')]));
    await tester.pumpAndSettle();
    expect(find.text('A API retornou datas de período inválidas.'),
        findsOneWidget);
    expect(find.textContaining('Início:'), findsNothing);
  });

  test('preserves date-only values, optional dates and valid leap days', () {
    final term =
        AcademicTermDates.fromJson(_term(start: '2028-02-29', end: null));
    expect(term.startDate, DateTime(2028, 2, 29));
    expect(term.startDate!.isUtc, isFalse);
    expect(term.endDate, isNull);
    final missing = AcademicTermDates.fromJson(_term(start: null, end: null));
    expect(missing.startDate, isNull);
    expect(missing.endDate, isNull);
    expect(() => AcademicTermDates.fromJson(_term(start: '2031-06-21')),
        throwsA(isA<ApiException>()));
    expect(
        () => AcademicTermDates.fromJson(_term(start: '2031-01-15T00:00:00Z')),
        throwsA(isA<ApiException>()));
  });

  test('loads every page of active terms without truncating the catalogue',
      () async {
    final pages = <String>[];
    final service = AcademicRecordsService(
        ApiClient(
          baseUrl: 'https://fixture.invalid/api/v1',
          httpClient: MockClient((request) async {
            final page = request.url.queryParameters['page']!;
            pages.add(page);
            final data = page == '1'
                ? [
                    for (var i = 0; i < 100; i++) {..._term(), 'id': 'p$i'}
                  ]
                : [
                    {..._term(), 'id': 'p100'}
                  ];
            return http.Response(
                jsonEncode({
                  'data': data,
                  'meta': {'page': int.parse(page), 'limit': 100, 'total': 101},
                }),
                200);
          }),
        ),
        accessToken: 'test-access-token',
        tenantSlug: 'campus');
    final terms = await service.activeTermDates();
    expect(pages, ['1', '2']);
    expect(terms, hasLength(101));
    expect(terms.last.period.id, 'p100');
  });
}
