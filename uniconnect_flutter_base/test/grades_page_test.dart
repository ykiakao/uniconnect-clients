import 'package:uniconnect/features/academic/demo/synthetic_academic_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uniconnect/features/grades/presentation/grades_page.dart';
import 'package:uniconnect/features/grades/providers/grades_provider.dart';

void main() {
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
