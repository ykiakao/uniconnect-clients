import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/bottom_nav.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../activities/models/academic_activity.dart';
import '../../activities/providers/activity_provider.dart';
import '../../activities/widgets/activity_card.dart';
import '../../auth/models/app_user.dart';
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
      body: DefaultTabController(
        length: 2,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              _HeroCard(user: user, criticalCount: criticalActivities.length),
              const SizedBox(height: AppSpacing.lg),
              const _AcademicSnapshot(),
              const SizedBox(height: AppSpacing.lg),
              TabBar(
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.priority_high),
                        const SizedBox(width: 8),
                        Text('Críticas (${criticalActivities.length})'),
                      ],
                    ),
                  ),
                  const Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.schedule),
                        SizedBox(width: 8),
                        Text('Próximos'),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: 300,
                child: TabBarView(
                  children: [
                    criticalActivities.isEmpty
                        ? EmptyStateWidget(
                            icon: Icons.check_circle,
                            title: 'Nenhuma urgência!',
                            subtitle: 'Você está em dia com as atividades críticas',
                          )
                        : ListView.builder(
                            itemCount: criticalActivities.length,
                            itemBuilder: (context, index) => ActivityCard(
                              activity: criticalActivities[index],
                              compact: true,
                              onTap: () =>
                                  context.push('/atividades/${criticalActivities[index].id}'),
                            ),
                          ),
                    ListView.builder(
                      itemCount: activities.length,
                      itemBuilder: (context, index) => _TimelineItem(
                        activity: activities[index],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Align(
                alignment: Alignment.center,
                child: TextButton.icon(
                  onPressed: () => context.push(AppRoutes.activities),
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Ver todas as atividades'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.user, required this.criticalCount});

  final AppUser? user;
  final int criticalCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bem-vindo,',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            user?.name.split(' ').first ?? 'Aluno',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (criticalCount > 0) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: Colors.red.shade700,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$criticalCount atividade(s) crítica(s) que precisa(m) de atenção',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
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
          const SizedBox(height: AppSpacing.lg),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: const LinearProgressIndicator(value: .72, minHeight: 8),
          ),
          const SizedBox(height: AppSpacing.sm),
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
      padding: const EdgeInsets.all(AppSpacing.lg),
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
          const SizedBox(width: AppSpacing.md),
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
