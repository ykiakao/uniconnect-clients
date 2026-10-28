import 'package:uniconnect/features/academic/demo/synthetic_academic_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uniconnect/features/activities/models/academic_activity.dart';
import 'package:uniconnect/features/activities/presentation/activity_detail_page.dart';
import 'package:uniconnect/features/activities/providers/activity_provider.dart';

void main() {
  final activity = AcademicActivity(
    id: 'activity-1',
    subject: 'Metodos Quantitativos',
    title: 'Pesquisa aplicada',
    description: 'Analise os dados disponibilizados para a turma.',
    dueLabel: 'Vence em 3 dias',
    dueDate: DateTime(2026, 10, 3),
    teacher: 'Profa. Ana Lima',
    priority: ActivityPriority.medium,
    status: ActivityStatus.pending,
    criteria: [],
    attachments: [],
  );

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('renders activity details without unsupported actions',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syntheticDemoRequestedProvider.overrideWithValue(false),
          activitiesProvider.overrideWith((ref) async => [activity]),
        ],
        child: const MaterialApp(
          home: ActivityDetailPage(activityId: 'activity-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pesquisa aplicada'), findsOneWidget);
    expect(find.text('METODOS QUANTITATIVOS'), findsOneWidget);
    expect(
      find.text(
          'Os criterios de avaliacao nao foram informados para esta atividade.'),
      findsOneWidget,
    );
    expect(find.text('Enviar mensagem'), findsNothing);
    expect(find.text('Realizar atividade'), findsNothing);
    expect(find.text('10.0 pontos'), findsNothing);
  });
}
