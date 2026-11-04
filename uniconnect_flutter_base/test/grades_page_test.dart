import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uniconnect/features/academic/demo/synthetic_academic_providers.dart';
import 'package:uniconnect/features/auth/providers/auth_provider.dart';
import 'package:uniconnect/features/grades/presentation/grades_page.dart';
import 'package:uniconnect/features/grades/providers/grades_provider.dart';

import 'fakes/fake_session_storage.dart';

void main() {
  testWidgets(
      'grades without a student session do not request legacy evaluations',
      (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    var legacyRequests = 0;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        syntheticDemoRequestedProvider.overrideWithValue(false),
        sessionStorageProvider.overrideWithValue(FakeSessionStorage()),
        subjectGradesProvider.overrideWith((ref) async {
          legacyRequests++;
          return [];
        }),
      ],
      child: const MaterialApp(home: GradesPage()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Boletim acadêmico indisponível'), findsOneWidget);
    expect(legacyRequests, 0);
    expect(find.text('Simulador de média'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
