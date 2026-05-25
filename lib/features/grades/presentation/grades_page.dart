import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/bottom_nav.dart';
import '../models/subject_grade.dart';
import '../providers/grades_provider.dart';
import '../widgets/average_simulator.dart';

class GradesPage extends ConsumerWidget {
  const GradesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects = ref.watch(subjectGradesProvider);
    final gpa = subjects.isEmpty
        ? 0.0
        : subjects
                .map((subject) => subject.finalAverage)
                .reduce((a, b) => a + b) /
            subjects.length;

    return Scaffold(
      appBar: const AppHeader(
        title: 'Quadro de notas',
        fallbackRoute: AppRoutes.studentDashboard,
      ),
      bottomNavigationBar: const UniBottomNav(currentIndex: 3),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        children: [
          AppCard(
            backgroundColor: AppColors.primary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'COEFICIENTE DE RENDIMENTO',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .8,
                      ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      gpa.toStringAsFixed(1),
                      style:
                          Theme.of(context).textTheme.displayMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        ' / 10.0',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                const Text(
                  'Progresso do Curso',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: AppSpacing.xs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: const LinearProgressIndicator(
                    value: .75,
                    minHeight: 10,
                    backgroundColor: Colors.white24,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text('75%', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
          AppCard(
            backgroundColor: AppColors.successSoft,
            child: Row(
              children: [
                const Icon(Icons.emoji_events_outlined,
                    color: AppColors.success),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Lista do Reitor',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        'Parabéns! Seu desempenho acadêmico este semestre te coloca entre os top 5%.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.muted,
                            ),
                      ),
                    ],
                  ),
                ),
                const _TinyBadge(label: 'DESTAQUE 2024.1'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Semestre Atual',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.filter_list),
                label: const Text('Filtrar'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ...subjects.map((subject) => _SubjectGradeCard(subject: subject)),
          const SizedBox(height: AppSpacing.md),
          const AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionLabel('EVOLUÇÃO ACADÊMICA'),
                SizedBox(height: AppSpacing.md),
                _CreditProgress(),
              ],
            ),
          ),
          const AppCard(child: AverageSimulator()),
          SecondaryButton(
            icon: Icons.picture_as_pdf_outlined,
            label: 'Gerar Histórico (PDF)',
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

class _SubjectGradeCard extends StatelessWidget {
  const _SubjectGradeCard({required this.subject});

  final SubjectGrade subject;

  @override
  Widget build(BuildContext context) {
    final approved = subject.finalAverage >= 7;

    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject.subject,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'MAT-204 • ${subject.status}',
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: AppSpacing.sm),
                _TinyBadge(
                  label: approved ? 'APROVADO' : 'EM CURSO',
                  color: approved ? AppColors.success : AppColors.secondary,
                  softColor: approved
                      ? AppColors.successSoft
                      : AppColors.secondarySoft,
                ),
              ],
            ),
          ),
          Text(
            subject.finalAverage == 0
                ? '--'
                : subject.finalAverage.toStringAsFixed(1),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

class _CreditProgress extends StatelessWidget {
  const _CreditProgress();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Total de Créditos'),
        const SizedBox(height: AppSpacing.xs),
        const Row(
          children: [
            Expanded(child: Text('142 / 180')),
            Text('22.1   22.2   23.1   24.1'),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: const LinearProgressIndicator(value: .78, minHeight: 8),
        ),
      ],
    );
  }
}

class _TinyBadge extends StatelessWidget {
  const _TinyBadge({
    required this.label,
    this.color = AppColors.primary,
    this.softColor = AppColors.primarySoft,
  });

  final String label;
  final Color color;
  final Color softColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: softColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: .8,
          ),
    );
  }
}
