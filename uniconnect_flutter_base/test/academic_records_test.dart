import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uniconnect/core/network/api_client.dart';
import 'package:uniconnect/features/academic/models/academic_records.dart';
import 'package:uniconnect/features/academic/presentation/academic_records_section.dart';
import 'package:uniconnect/features/academic/providers/academic_records_providers.dart';
import 'package:uniconnect/features/academic/services/academic_records_service.dart';
import 'package:uniconnect/features/teacher/widgets/activity_type_field.dart';

import 'communication_service_test.dart' show json;
import 'demo_day_test.dart' show pumpDemoPage;

Map<String, dynamic> _envelope() => {
      'source': {'providerId': 'native', 'demonstration': false, 'label': 'X'},
      'scope': {'userId': 'student-1', 'tenantId': 'tenant-1'},
      'institution': {'id': 'tenant-1', 'name': 'Campus', 'slug': 'campus'},
      'complete': true,
      'warnings': <Object>[],
    };

Map<String, dynamic> overviewJson(String periodId, String name,
        {String status = 'in_progress', List<Object>? warnings}) =>
    {
      ..._envelope(),
      if (warnings != null) 'warnings': warnings,
      'period': {'id': periodId, 'name': name},
      'subjects': [
        {
          'id': 'subject-$periodId',
          'name': 'Métodos Numéricos',
          'status': status,
          'grades': null,
          'attendance': {'absences': null, 'absencePercentage': null},
          'activities': [
            {'id': 'a1', 'title': 'Lista 1'},
            {'id': 'a2', 'title': 'Projeto final'},
          ],
          'activitiesComplete': true,
          'assessments': [
            {'activityId': 'a1', 'title': 'Lista 1', 'grade': 8.5},
            {'activityId': 'a2', 'title': 'Projeto final', 'grade': null},
          ],
        },
      ],
    };

AcademicRecordsService _service(
        Future<http.Response> Function(http.Request request) handler) =>
    AcademicRecordsService(
      ApiClient(
          baseUrl: 'https://fixture.invalid/api/v1',
          httpClient: MockClient(handler)),
      accessToken: 'token',
      tenantSlug: 'campus',
    );

void main() {
  test('reads periods, the chosen overview and the history', () async {
    final paths = <String>[];
    final service = _service((request) async {
      paths.add('${request.url.path}?${request.url.query}');
      return switch (request.url.path.split('/academic').last) {
        '/periods' => json({
            ..._envelope(),
            'periods': [
              {'id': 'p1', 'name': '2026.1'},
              {'id': 7, 'name': null},
            ],
          }),
        '/overview' => json(overviewJson('p1', '2026.1', warnings: [
            {'code': 'ATTENDANCE_UNAVAILABLE', 'message': 'Sem frequência.'},
            {'code': 'ATTENDANCE_UNAVAILABLE', 'message': 'Sem frequência.'},
          ])),
        _ => json({
            ..._envelope(),
            'periods': [overviewJson('p1', '2026.1')],
          }),
      };
    });

    final periods = await service.periods();
    expect(periods.map((p) => p.label), ['2026.1', 'Período 7']);

    final overview = await service.overview(periodId: 'p1');
    expect(overview.period.id, 'p1');
    expect(overview.warnings, ['Sem frequência.']);
    final subject = overview.subjects.single;
    expect(subject.activityCount, 2);
    expect(subject.gradedCount, 1);
    expect(subject.assessments.first.grade, 8.5);

    final history = await service.history();
    expect(history.periods.single.subjects.single.title, 'Métodos Numéricos');

    expect(paths, [
      '/api/v1/tenants/campus/academic/periods?',
      '/api/v1/tenants/campus/academic/overview?periodId=p1',
      '/api/v1/tenants/campus/academic/history?',
    ]);
  });

  test('rejects an overview without subjects list', () {
    expect(
        () => AcademicOverviewRecord.fromJson({
              'period': {'id': 'p1'}
            }),
        throwsA(isA<ApiException>()));
  });

  test('subject status uses the API label first, then a Portuguese one', () {
    expect(
        subjectStatus(const AcademicSubjectRecord(id: 's', status: 'failed'))
            ?.$1,
        'Reprovada');
    expect(
        subjectStatus(const AcademicSubjectRecord(
                id: 's', status: 'passed', statusLabel: 'Aprovado por média'))
            ?.$1,
        'Aprovado por média');
    expect(subjectStatus(const AcademicSubjectRecord(id: 's')), isNull);
    final period = AcademicOverviewRecord(
      period: const AcademicPeriodRef(id: 'p'),
      subjects: [
        for (final status in ['completed', 'completed', 'in_progress'])
          AcademicSubjectRecord(id: status, status: status),
      ],
    );
    expect(historySummary(period), '3 disciplinas • 2 concluídas, 1 cursando');
  });

  testWidgets('section lists subjects with grades and selects history periods',
      (tester) async {
    final requested = <String?>[];
    await pumpDemoPage(
      tester,
      const Scaffold(
          body: SingleChildScrollView(child: AcademicRecordsSection())),
      overrides: [
        academicPeriodsProvider.overrideWith((ref) async => const [
              AcademicPeriodRef(id: 'p1', name: '2026.1'),
              AcademicPeriodRef(id: 'p2', name: '2026.2'),
            ]),
        academicOverviewProvider.overrideWith((ref, periodId) async {
          requested.add(periodId);
          return periodId == 'p1'
              ? AcademicOverviewRecord.fromJson(
                  overviewJson('p1', '2026.1', status: 'completed'))
              : AcademicOverviewRecord.fromJson(
                  overviewJson('p2', '2026.2', warnings: [
                  {'code': 'X', 'message': 'Médias indisponíveis.'}
                ]));
        }),
        academicHistoryProvider
            .overrideWith((ref) async => AcademicHistoryRecord.fromJson({
                  ..._envelope(),
                  'periods': [
                    overviewJson('p1', '2026.1', status: 'completed'),
                    overviewJson('p2', '2026.2'),
                  ],
                })),
      ],
    );
    await tester.pumpAndSettle();

    expect(requested, [null]);
    expect(find.text('Cursando'), findsOneWidget);
    expect(find.text('8,5'), findsOneWidget);
    expect(find.text('Sem nota'), findsOneWidget);
    expect(find.text('2 atividades • 1 com nota'), findsOneWidget);
    expect(find.text('Médias indisponíveis.'), findsOneWidget);
    expect(find.text('1 disciplina • 1 concluída'), findsOneWidget);
    expect(find.text('1 disciplina • 1 cursando'), findsOneWidget);

    await tester.tap(find.text('1 disciplina • 1 concluída'));
    await tester.pumpAndSettle();

    expect(requested.last, 'p1');
    expect(find.text('Concluída'), findsOneWidget);
    final chip =
        tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '2026.1'));
    expect(chip.selected, isTrue);
  });

  testWidgets('section explains a failure and offers a retry', (tester) async {
    await pumpDemoPage(
      tester,
      const Scaffold(
          body: SingleChildScrollView(child: AcademicRecordsSection())),
      overrides: [
        academicPeriodsProvider.overrideWith((ref) async => const []),
        academicOverviewProvider.overrideWith(
            (ref, _) async => throw const ApiException('x', statusCode: 404)),
        academicHistoryProvider.overrideWith(
            (ref) async => const AcademicHistoryRecord(periods: [])),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Nenhum período letivo disponível para consulta.'),
        findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(find.text('Escolher outro período'), findsNothing);
  });

  testWidgets('activity type shows Portuguese labels and keeps API values',
      (tester) async {
    final controller = TextEditingController(text: 'assignment');
    addTearDown(controller.dispose);
    var changes = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ActivityTypeField(
            controller: controller, onChanged: () => changes++),
      ),
    ));

    expect(find.text('Trabalho'), findsOneWidget);
    expect(find.text('assignment'), findsNothing);

    await tester.tap(find.text('Trabalho'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Projeto').last);
    await tester.pumpAndSettle();

    expect(controller.text, 'project');
    expect(changes, 1);
    expect(find.text('Projeto'), findsOneWidget);

    controller.text = 'seminario-livre';
    await tester.pump();
    expect(find.text('seminario-livre'), findsOneWidget);
    expect(activityTypeLabel('report'), 'Relatório');
  });

  testWidgets('an empty active period falls back to the latest with subjects',
      (tester) async {
    Map<String, dynamic> empty(String id, String name) =>
        {...overviewJson(id, name), 'subjects': <Object>[]};
    await pumpDemoPage(
      tester,
      const Scaffold(
          body: SingleChildScrollView(child: AcademicRecordsSection())),
      overrides: [
        academicPeriodsProvider.overrideWith((ref) async => const []),
        academicOverviewProvider.overrideWith((ref, periodId) async =>
            AcademicOverviewRecord.fromJson(periodId == 'p1'
                ? overviewJson('p1', '2026.1')
                : empty('p2', '2026.2'))),
        academicHistoryProvider
            .overrideWith((ref) async => AcademicHistoryRecord.fromJson({
                  ..._envelope(),
                  'periods': [
                    empty('p2', '2026.2'),
                    overviewJson('p1', '2026.1')
                  ],
                })),
      ],
    );
    await tester.pumpAndSettle();

    expect(
        find.text('2026.2 ainda não tem disciplinas. '
            'Exibindo o período mais recente com disciplinas.'),
        findsOneWidget);
    expect(find.text('Métodos Numéricos'), findsWidgets);
    expect(find.text('Escolher outro período'), findsOneWidget);
  });

  test('published grades map each graded activity of the history', () async {
    final container = ProviderContainer(overrides: [
      academicHistoryProvider
          .overrideWith((ref) async => AcademicHistoryRecord.fromJson({
                ..._envelope(),
                'periods': [overviewJson('p1', '2026.1')],
              })),
    ]);
    addTearDown(container.dispose);
    container.listen(publishedGradesProvider, (_, __) {});
    await container.read(academicHistoryProvider.future);

    expect(container.read(publishedGradesProvider), {'a1': 8.5});
  });
}
