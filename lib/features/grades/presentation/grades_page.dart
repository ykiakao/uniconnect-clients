import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/bottom_nav.dart';
import '../../../shared/widgets/section_header.dart';
import '../providers/grades_provider.dart';
import '../widgets/average_simulator.dart';

class GradesPage extends ConsumerWidget {
  const GradesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects = ref.watch(subjectGradesProvider);
    final gpa = subjects
            .map((subject) => subject.finalAverage)
            .reduce((value, element) => value + element) /
        subjects.length;

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackRoute: AppRoutes.studentDashboard),
        title: const Text('Quadro de notas'),
      ),
      bottomNavigationBar: const UniBottomNav(currentIndex: 3),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          AppCard(
            backgroundColor: AppColors.primary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Coeficiente de rendimento',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: .78),
                      ),
                ),
                Text(
                  '${gpa.toStringAsFixed(1)} / 10.0',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: gpa / 10,
                    minHeight: 8,
                    backgroundColor: Colors.white.withValues(alpha: .18),
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Evolução acadêmica estável neste semestre',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: .78),
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const SectionHeader(
            title: 'Disciplinas',
            subtitle: 'Notas consolidadas e situação atual',
          ),
          ...subjects.map(
            (subject) => AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          subject.subject,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          subject.finalAverage.toStringAsFixed(1),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _GradePill(label: 'P1', value: subject.p1),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _GradePill(label: 'P2', value: subject.p2),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _GradePill(label: 'Trab.', value: subject.work),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subject.status,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const AppCard(child: AverageSimulator()),
        ],
      ),
    );
  }
}

class _GradePill extends StatelessWidget {
  const _GradePill({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700,
                ),
          ),
          Text(
            value == 0 ? '--' : value.toStringAsFixed(1),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
