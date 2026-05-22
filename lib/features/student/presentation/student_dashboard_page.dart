import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/bottom_nav.dart';
import '../../../shared/widgets/section_header.dart';
import '../../activities/models/academic_activity.dart';
import '../../activities/providers/activity_provider.dart';
import '../../activities/widgets/activity_card.dart';
import '../../auth/providers/auth_provider.dart';

class StudentDashboardPage extends ConsumerWidget {
  const StudentDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider);
    final activities = ref.watch(activitiesProvider);
    final criticalActivities = activities
        .where((activity) => activity.priority == ActivityPriority.critical)
        .toList();

    return Scaffold(
      bottomNavigationBar: const UniBottomNav(currentIndex: 0),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dashboard do aluno',
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: Colors.white.withValues(alpha: .72),
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Olá, ${user?.name.split(' ').first ?? 'Lucas'}',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '2 itens críticos precisam da sua atenção hoje.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withValues(alpha: .84),
                                  ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.auto_awesome, color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const _AcademicSnapshot(),
            const SizedBox(height: 18),
            SectionHeader(
              title: 'Quadro de urgências',
              subtitle: 'Ordenado pelo impacto acadêmico',
              actionLabel: 'Ver tudo',
              onAction: () => context.push(AppRoutes.activities),
            ),
            ...criticalActivities.map(
              (activity) => ActivityCard(
                activity: activity,
                compact: true,
                onTap: () => context.push('/atividades/${activity.id}'),
              ),
            ),
            const SizedBox(height: 18),
            const SectionHeader(
              title: 'Timeline de prazos',
              subtitle: 'Próximos compromissos em ordem de ação',
            ),
            ...activities
                .take(4)
                .map((activity) => _TimelineItem(activity: activity)),
            const SizedBox(height: 18),
            const SectionHeader(
              title: 'Atividades pendentes',
              subtitle: 'Tarefas que ainda precisam de decisão',
            ),
            ...activities.skip(1).take(3).map(
                  (activity) => ActivityCard(
                    activity: activity,
                    onTap: () => context.push('/atividades/${activity.id}'),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _AcademicSnapshot extends StatelessWidget {
  const _AcademicSnapshot();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          const Row(
            children: [
              Expanded(child: _Metric(title: 'GPA', value: '8.7')),
              Expanded(child: _Metric(title: 'Semestre', value: '4')),
              Expanded(child: _Metric(title: 'Urgências', value: '2')),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: const LinearProgressIndicator(value: .72, minHeight: 8),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '72% das atividades da semana encaminhadas',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
              ),
        ),
        Text(title, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({required this.activity});

  final AcademicActivity activity;

  @override
  Widget build(BuildContext context) {
    final color = switch (activity.priority) {
      ActivityPriority.critical => AppColors.danger,
      ActivityPriority.medium => AppColors.warning,
      ActivityPriority.low => AppColors.success,
    };

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  '${activity.subject} • ${activity.dueLabel}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
