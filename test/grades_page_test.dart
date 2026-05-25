import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uniconnect/features/grades/presentation/grades_page.dart';

void main() {
  testWidgets('renders grades dashboard content', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.view.physicalSize = const Size(264, 1206);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: GradesPage(),
        ),
      ),
    );

    expect(find.text('COEFICIENTE DE RENDIMENTO'), findsOneWidget);
    expect(find.text('Semestre Atual'), findsOneWidget);
  });
}
