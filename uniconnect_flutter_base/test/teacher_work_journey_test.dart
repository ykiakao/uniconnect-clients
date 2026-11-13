import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:uniconnect/features/teacher/presentation/teacher_activities_page.dart';
import 'package:uniconnect/features/teacher/presentation/teacher_dashboard_page.dart';
import 'package:uniconnect/features/teacher/providers/teacher_activity_provider.dart';
import 'package:uniconnect/features/teacher/providers/teacher_review_provider.dart';
import 'package:uniconnect/features/teacher/providers/teacher_offering_selection.dart';
import 'package:uniconnect/features/teacher/services/teacher_review_service.dart';

import 'demo_day_test.dart' show pumpDemoPage;
import 'fakes/fake_auth_service.dart';
import 'teacher_activity_service_test.dart'
    show activityRow, jsonResponse, page, service;
import 'teacher_review_service_test.dart' show reviewedSubmission, reviewJson;

Future<void> _mount(WidgetTester tester, Widget widget,
    Future<http.Response> Function(http.Request) handler,
    {bool multipleOffers = false}) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  final activityApi = service((request) {
    if (request.url.path.endsWith('/offerings')) {
      return Future.value(jsonResponse(page([
        {'id': 'class-1', 'name': 'Métodos', 'status': 'active'},
        if (multipleOffers)
          {'id': 'class-2', 'name': 'Pesquisa', 'status': 'active'},
      ])));
    }
    return handler(request);
  });
  await pumpDemoPage(tester, widget, user: fakeTeacher, overrides: [
    teacherActivityServiceProvider.overrideWithValue(activityApi),
    teacherReviewServiceProvider.overrideWithValue(TeacherReviewService(
      activityApi.client,
      accessToken: activityApi.accessToken,
      tenantSlug: activityApi.tenantSlug,
    )),
  ]);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String label) async {
  final target = find.text(label).last;
  await tester.ensureVisible(target);
  // ensureVisible scrolls without a frame; settle before tapping.
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'work actions retain accessible labels at 320px with enlarged text',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await _mount(
      tester,
      Builder(builder: (context) {
        return Theme(
          data: ThemeData.dark(useMaterial3: true),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(2),
            ),
            child: const TeacherActivitiesPage(),
          ),
        );
      }),
      (_) async => jsonResponse(page([activityRow(state: 'published')])),
    );
    tester.view.physicalSize = const Size(320, 1000);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Ver entregas'), 150,
        scrollable: find.byType(Scrollable).first);
    expect(
      tester
          .getSemantics(find.widgetWithText(TextButton, 'Ver entregas'))
          .label,
      contains('Ver entregas'),
    );
    expect(find.byTooltip('Meu perfil'), findsOneWidget);
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'work tab edits a draft with the current version and closes explicitly',
      (tester) async {
    var work = activityRow();
    final writes = <(String, Map<String, dynamic>)>[];
    await _mount(tester, const TeacherActivitiesPage(), (request) async {
      if (request.method == 'GET') {
        return jsonResponse(page([
          work,
          {
            ...activityRow(state: 'closed'),
            'id': 'closed-1',
            'title': 'Trabalho encerrado'
          },
          {
            ...activityRow(),
            'id': 'exam-1',
            'title': 'Prova separada',
            'assessment': {
              'stage': 'N1',
              'category': 'exam',
              'maxPoints': '7.00'
            },
          },
        ]));
      }
      final payload = jsonDecode(request.body) as Map<String, dynamic>;
      writes.add((request.url.pathSegments.last, payload));
      if (request.method == 'PUT') {
        work = {...work, ...payload, 'revision': 2};
      } else if (request.url.path.endsWith('/publish')) {
        work = {
          ...work,
          'state': 'published',
          'revision': 3,
          'dueDate': '2020-01-01T12:00:00.000Z'
        };
      } else {
        work = {...work, 'state': 'closed', 'revision': 4};
      }
      return jsonResponse(work);
    });
    expect(find.text('Rascunho'), findsOneWidget);
    expect(find.text('Encerrada'), findsOneWidget);
    expect(find.text('Prova separada'), findsNothing);
    expect(find.byTooltip('Meu perfil'), findsOneWidget);
    await _tap(tester, 'Editar rascunho');
    await tester.enterText(
        find.byType(TextFormField).first, 'Título atualizado');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await _tap(tester, 'Cancelar');
    expect(find.text('Descartar alterações do rascunho?'), findsOneWidget);
    await _tap(tester, 'Continuar editando');
    expect(find.text('Título atualizado'), findsOneWidget);
    await _tap(tester, 'Salvar alterações');
    expect(writes.single.$2['expectedVersion'], 1);
    expect(writes.single.$2['title'], 'Título atualizado');
    expect(writes.single.$2.containsKey('dueDate'), isFalse);
    expect(
        find.text('Edição do rascunho confirmada pela API.'), findsOneWidget);

    await _tap(tester, 'Publicar atividade');
    expect(writes[1].$1, 'publish');
    expect(writes[1].$2, {'expectedVersion': 2});
    expect(find.text('Publicada'), findsOneWidget);
    expect(find.textContaining('Prazo vencido'), findsOneWidget);
    await _tap(tester, 'Encerrar trabalho');
    expect(writes, hasLength(2));
    await _tap(tester, 'Confirmar encerramento');
    expect(writes.last.$1, 'close');
    expect(writes.last.$2, {'expectedVersion': 3});
    expect(find.text('Encerramento confirmado pela API.'), findsOneWidget);
    expect(find.text('Encerrada'), findsNWidgets(2));
    expect(find.textContaining('Prazo vencido'), findsNothing);
    expect(find.text('Encerrar trabalho'), findsNothing);
  });

  testWidgets('close conflict reloads the server state before another attempt',
      (tester) async {
    var work = activityRow(state: 'published', revision: 2);
    final versions = <int>[];
    await _mount(tester, const TeacherActivitiesPage(), (request) async {
      if (request.method == 'GET') return jsonResponse(page([work]));
      versions.add((jsonDecode(request.body) as Map)['expectedVersion'] as int);
      if (versions.length == 1) {
        work = {...work, 'revision': 4};
        return jsonResponse({
          'error': {'message': 'Versão desatualizada'}
        }, 409);
      }
      work = {...work, 'revision': 5, 'state': 'closed'};
      return jsonResponse(work);
    });
    await _tap(tester, 'Encerrar trabalho');
    await _tap(tester, 'Confirmar encerramento');
    expect(find.textContaining('Conflito de versão'), findsOneWidget);
    expect(find.text('Publicada'), findsOneWidget);
    expect(find.text('Encerramento confirmado pela API.'), findsNothing);
    await _tap(tester, 'Encerrar trabalho');
    await _tap(tester, 'Confirmar encerramento');
    expect(versions, [2, 4]);
    expect(find.text('Encerrada'), findsOneWidget);
  });

  testWidgets('a late home summary cannot appear in another offering',
      (tester) async {
    final lateA = Completer<http.Response>();
    final requests = <String>[];
    Map<String, dynamic> preview(String classId, String title) => {
          'data': [
            {
              ...activityRow(state: 'published'),
              'classId': classId,
              'title': title,
              'workflowEnabled': false,
              'dueDate': '2099-01-01T12:00:00.000Z',
            },
          ],
          'meta': {'page': 1, 'limit': 20, 'total': 1},
        };
    await _mount(tester, const TeacherDashboardPage(), (request) async {
      requests.add(request.url.path);
      return request.url.path.endsWith('/class-1/activities')
          ? lateA.future
          : jsonResponse(preview('class-2', 'Prazo da oferta atual'));
    }, multipleOffers: true);
    final container = ProviderScope.containerOf(
        tester.element(find.byType(TeacherDashboardPage)));
    final selection = container.read(teacherOfferingSelectionProvider.notifier);
    expect(selection.select('class-1'), isTrue);
    await tester.pump();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
    await tester.pump();
    expect(requests.single, endsWith('/class-1/activities'));
    expect(selection.select('class-2'), isTrue);
    await tester.pumpAndSettle();
    lateA
        .complete(jsonResponse(preview('class-1', 'Prazo da oferta anterior')));
    await tester.pumpAndSettle();
    expect(find.text('Prazo da oferta atual'), findsOneWidget);
    expect(find.text('Prazo da oferta anterior'), findsNothing);
  });

  testWidgets(
      'dashboard bounds requests, shows real deadlines and retries a failed preview',
      (tester) async {
    final checked = <String>[];
    var failed = true;
    Map<String, dynamic> preview(List<Object?> data, int total) => {
          'data': data,
          'meta': {'page': 1, 'limit': 20, 'total': total},
        };
    await _mount(tester, const TeacherDashboardPage(), (request) async {
      expect(request.url.queryParameters, {'page': '1', 'limit': '20'});
      if (request.url.path.endsWith('/activities')) {
        return jsonResponse(preview([
          for (var index = 1; index <= 4; index++)
            {
              ...activityRow(state: 'published'),
              'id': 'work-$index',
              'title': 'Trabalho $index',
              if (index == 1) 'dueDate': '2099-01-01T12:00:00.000Z'
            },
        ], 25));
      }
      final work =
          request.url.pathSegments[request.url.pathSegments.length - 2];
      checked.add(work);
      if (work == 'work-3' && failed) {
        return jsonResponse({
          'error': {'message': 'Temporariamente indisponível'}
        }, 503);
      }
      final receipt = reviewedSubmission(
        result: work == 'work-2' ? reviewJson(grade: 0) : null,
      )..['activityId'] = work;
      return jsonResponse(preview([receipt], 1));
    });
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.text('Algumas entregas não puderam ser consultadas.'),
        findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((widget) => widget.data)
            .join(' | '));
    expect(checked.toSet(), {'work-1', 'work-2', 'work-3'});
    expect(find.text('Prévia da oferta: 4 de 25 registros consultados.'),
        findsOneWidget);
    expect(find.text('Trabalho 1'), findsOneWidget);
    expect(find.bySemanticsLabel('Aguardando correção na consulta: 1'),
        findsOneWidget);
    expect(
        find.bySemanticsLabel(
            'Correções salvas aguardando publicação na consulta: 1'),
        findsOneWidget);
    failed = false;
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -350));
    await tester.pumpAndSettle();
    await _tap(tester, 'Tentar novamente');
    expect(find.text('Algumas entregas não puderam ser consultadas.'),
        findsNothing);
    expect(find.bySemanticsLabel('Aguardando correção na consulta: 2'),
        findsOneWidget);
    expect(checked.where((work) => work == 'work-3'), hasLength(2));
  });
}
