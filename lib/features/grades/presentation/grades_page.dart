import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
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
    final gpa = subjects.isEmpty
        ? 0.0
        : subjects.map((subject) => subject.finalAverage).reduce((a, b) => a + b) /
            subjects.length;

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackRoute: AppRoutes.studentDashboard),
        title: const Text('Quadro de notas'),
      ),
      bottomNavigationBar: const UniBottomNav(currentIndex: 3),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const AppBackAction(fallbackRoute: AppRoutes.studentDashboard),
          AppCard(
            backgroundColor: AppColors.primary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Coeficiente de rendimento',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
                ),
                Text(
                  '${gpa.toStringAsFixed(1)} / 10.0',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: gpa / 10,
                    minHeight: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.18),
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Evolução acadêmica estável neste semestre',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
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
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
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
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: _GradePill(label: 'P1', value: subject.p1),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _GradePill(label: 'P2', value: subject.p2),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _GradePill(label: 'Trab.', value: subject.work),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
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
          const SizedBox(height: AppSpacing.md),
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
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
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
