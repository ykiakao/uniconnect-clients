import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uniconnect/features/teacher/presentation/create_activity_page.dart';
import 'dart:async';
import 'dart:convert';
import 'package:uniconnect/features/teacher/providers/teacher_activity_provider.dart';
import 'teacher_activity_service_test.dart'
    show service, page, jsonResponse, activityRow;
import 'demo_day_test.dart' show pumpDemoPage;
import 'fakes/fake_auth_service.dart';

void main() {
  Future<void> selectOffering(WidgetTester tester) async {
    final dropdown = find.byType(DropdownButtonFormField<String>).first;
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Métodos').last);
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, String label) async {
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text(label),
        label == 'Atualizar ofertas e atividades' ? -250 : 250,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pump();
  }

  for (final status in [403, 503]) {
    testWidgets('creation HTTP $status shows error without success',
        (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      var writes = 0;
      final api = service((r) async {
        if (r.url.path.endsWith('/offerings')) {
          return jsonResponse(page([
            {'id': 'class-1', 'name': 'Métodos', 'status': 'active'}
          ]));
        }
        if (r.method == 'GET') return jsonResponse(page([]));
        writes++;
        return jsonResponse({
          'error': {'message': 'Operação recusada'}
        }, status);
      });
      await pumpDemoPage(tester, const CreateActivityPage(),
          user: fakeTeacher,
          overrides: [teacherActivityServiceProvider.overrideWithValue(api)]);
      await tester.pumpAndSettle();
      await selectOffering(tester);
      await tester.enterText(find.byType(TextFormField).first, 'Pesquisa');
      await tapVisible(tester, 'Salvar rascunho');
      await tester.pumpAndSettle();
      expect(writes, 1);
      expect(find.textContaining('Rascunho salvo pela API.'), findsNothing);
      expect(find.textContaining('Confira a lista antes de repetir'),
          findsOneWidget);
      expect(
          tester
              .widget<ElevatedButton>(
                  find.widgetWithText(ElevatedButton, 'Salvar rascunho'))
              .onPressed,
          isNull);
    });
  }

  testWidgets(
      'create then publish waits for HTTP confirmation and refreshes list',
      (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final confirmation = Completer<void>();
    var created = false;
    var published = false;
    var creates = 0;
    var lists = 0;
    final api = service((r) async {
      if (r.url.path.endsWith('/offerings')) {
        return jsonResponse(page([
          {'id': 'class-1', 'name': 'Métodos', 'status': 'active'}
        ]));
      }
      if (r.method == 'GET') {
        lists++;
        return jsonResponse(page(created
            ? [
                activityRow(
                    state: published ? 'published' : 'draft',
                    revision: published ? 2 : 1)
              ]
            : []));
      }
      if (r.url.path.endsWith('/publish')) {
        expect(jsonDecode(r.body), {'expectedVersion': 1});
        published = true;
        return jsonResponse(activityRow(state: 'published', revision: 2));
      }
      final payload = jsonDecode(r.body) as Map<String, dynamic>;
      expect(payload.containsKey('priority'), isFalse);
      expect(payload['allowLate'], isTrue);
      creates++;
      await confirmation.future;
      created = true;
      return jsonResponse(activityRow(), 201);
    });
    await pumpDemoPage(tester, const CreateActivityPage(),
        user: fakeTeacher,
        overrides: [teacherActivityServiceProvider.overrideWithValue(api)]);
    await tester.pumpAndSettle();
    await selectOffering(tester);
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    expect(find.text('Prioridade'), findsNothing);
    expect(find.text('Definir prazo (opcional)'), findsOneWidget);
    await tapVisible(tester, 'Salvar rascunho');
    expect(find.text('Campo obrigatório'), findsOneWidget);
    expect(creates, 0);
    final title = find.byType(TextFormField).first;
    await tester.ensureVisible(title);
    await tester.enterText(title, 'Pesquisa');
    await tapVisible(tester, 'Permitir entrega após o prazo');
    await tapVisible(tester, 'Salvar rascunho');
    expect(creates, 1);
    expect(find.textContaining('Rascunho salvo pela API.'), findsNothing);
    expect(
        tester
            .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Aguarde...'))
            .onPressed,
        isNull);
    confirmation.complete();
    await tester.pumpAndSettle();
    expect(find.textContaining('Rascunho salvo pela API.'), findsOneWidget);
    await tapVisible(tester, 'Publicar atividade');
    await tester.pumpAndSettle();
    expect(find.text('Publicação confirmada pela API.'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Publicada • Versão 2'), 250,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Publicada • Versão 2'), findsOneWidget);
    expect(find.text('Publicar atividade'), findsNothing);
    expect(lists, greaterThanOrEqualTo(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'empty authorization exposes no selectable offering or enabled creation',
      (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final api = service((_) async => jsonResponse(page([])));
    await pumpDemoPage(tester, const CreateActivityPage(),
        user: fakeTeacher,
        overrides: [teacherActivityServiceProvider.overrideWithValue(api)]);
    await tester.pumpAndSettle();
    expect(find.textContaining('Nenhuma oferta ativa autorizada.'),
        findsOneWidget);
    expect(
        tester
            .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Salvar rascunho'))
            .onPressed,
        isNull);
    final selector = tester.widget<DropdownButton<String>>(
        find.byType(DropdownButton<String>).first);
    expect(selector.items, isEmpty);
  });

  testWidgets('version conflict requires refresh and uses refreshed revision',
      (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    var revision = 1;
    var publications = 0;
    var published = false;
    final api = service((r) async {
      if (r.url.path.endsWith('/offerings')) {
        return jsonResponse(page([
          {'id': 'class-1', 'name': 'Métodos', 'status': 'active'}
        ]));
      }
      if (r.method == 'GET') {
        return jsonResponse(page([
          activityRow(
              revision: published ? 4 : revision,
              state: published ? 'published' : 'draft')
        ]));
      }
      publications++;
      if (publications == 1) {
        revision = 3;
        return jsonResponse({
          'error': {'message': 'Versão alterada'}
        }, 409);
      }
      expect(jsonDecode(r.body), {'expectedVersion': 3});
      published = true;
      return jsonResponse(activityRow(state: 'published', revision: 4));
    });
    await pumpDemoPage(tester, const CreateActivityPage(),
        user: fakeTeacher,
        overrides: [teacherActivityServiceProvider.overrideWithValue(api)]);
    await tester.pumpAndSettle();
    await selectOffering(tester);
    await tapVisible(tester, 'Publicar atividade');
    await tester.pumpAndSettle();
    expect(find.textContaining('Conflito de versão'), findsOneWidget);
    expect(find.text('Publicação confirmada pela API.'), findsNothing);
    await tester.scrollUntilVisible(find.text('Publicar atividade'), 250,
        scrollable: find.byType(Scrollable).first);
    expect(
        tester
            .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Publicar atividade'))
            .onPressed,
        isNull);
    expect(publications, 1);
    await tapVisible(tester, 'Atualizar ofertas e atividades');
    await tester.pumpAndSettle();
    await tapVisible(tester, 'Publicar atividade');
    await tester.pumpAndSettle();
    expect(publications, 2);
    await tester.scrollUntilVisible(find.text('Publicada • Versão 4'), 250,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Publicada • Versão 4'), findsOneWidget);
  });
  testWidgets('student cannot create or publish activities', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await pumpDemoPage(tester, const CreateActivityPage());
    await tester.pumpAndSettle();
    expect(find.text('Área exclusiva do professor'), findsOneWidget);
    expect(find.text('Salvar rascunho'), findsNothing);
  });
  testWidgets(
      'teacher form saves drafts instead of claiming immediate publication',
      (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await pumpDemoPage(tester, const CreateActivityPage(), user: fakeTeacher);
    await tester.pumpAndSettle();
    expect(find.text('Salvar rascunho'), findsOneWidget);
    expect(find.text('Valor da Atividade (Pontos)'), findsNothing);
  });
}
