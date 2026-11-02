import 'package:uniconnect/features/academic/demo/synthetic_academic_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uniconnect/features/grades/presentation/grades_page.dart';
import 'package:uniconnect/features/grades/providers/grades_provider.dart';
import 'package:uniconnect/features/grades/models/subject_grade.dart';
import 'package:uniconnect/features/activities/providers/activity_provider.dart';

void main() {
  testWidgets(
      'individual zero and absent grades remain distinct without invented aggregates',
      (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.pumpWidget(ProviderScope(overrides: [
      syntheticDemoRequestedProvider.overrideWithValue(false),
      activitiesProvider.overrideWith((ref) async => []),
      subjectGradesProvider.overrideWith((ref) async => const [
            SubjectGrade(
                subject: 'Pesquisa',
                code: 'a',
                activityId: 'a',
                teacher: '',
                grade: 0,
                feedback: 'Revisada'),
            SubjectGrade(
                subject: 'Projeto',
                code: 'b',
                activityId: 'b',
                teacher: '',
                grade: null),
          ]),
    ], child: const MaterialApp(home: GradesPage())));
    await tester.pumpAndSettle();
    expect(find.text('Pesquisa'), findsOneWidget);
    expect(find.text('Projeto'), findsOneWidget);
    expect(find.text('0.0'), findsOneWidget);
    expect(find.text('Nota indisponível'), findsOneWidget);
    expect(find.text('Revisada'), findsOneWidget);
    for (final text in [
      'P1',
      'P2',
      'Trab.',
      'Aprovado',
      'Simulador de média',
      'MÉDIA DAS NOTAS DISPONÍVEIS'
    ]) {
      expect(find.text(text), findsNothing);
    }
    expect(tester.takeException(), isNull);
  });
  testWidgets('renders grades dashboard content', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.view.physicalSize = const Size(264, 1206);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syntheticDemoRequestedProvider.overrideWithValue(false),
          subjectGradesProvider.overrideWith((ref) => const []),
        ],
        child: const MaterialApp(
          home: GradesPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Seu acompanhamento'), findsOneWidget);
    expect(find.text('Nenhuma nota disponível'), findsOneWidget);
    expect(find.text('COEFICIENTE DE RENDIMENTO'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
