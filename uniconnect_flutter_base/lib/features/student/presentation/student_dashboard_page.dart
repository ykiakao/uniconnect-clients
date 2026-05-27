import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/bottom_nav.dart';
import '../../activities/models/academic_activity.dart';
import '../../activities/providers/activity_provider.dart';
import '../../activities/widgets/activity_card.dart';
import '../../auth/providers/auth_provider.dart';
import '../../tenant/providers/tenant_provider.dart';

class StudentDashboardPage extends ConsumerWidget {
  const StudentDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final tenant = ref.watch(currentTenantProvider);
    final activities = ref.watch(activitiesProvider);
    final criticalActivities = activities
        .where((activity) => activity.priority == ActivityPriority.critical)
        .toList();

    return Scaffold(
      bottomNavigationBar: const UniBottomNav(currentIndex: 0),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          children: [
            _WelcomeHeader(
              name: user?.name.split(' ').first ?? 'Lucas',
              institution: tenant?.name ?? 'Universidade Norte',
            ),
            const SizedBox(height: AppSpacing.lg),
            const _PerformanceCard(),
            const SizedBox(height: AppSpacing.lg),
            const _SectionTitle('Quadro de Urgências'),
            const _UrgencyCard(),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                const Expanded(child: _SectionTitle('Atividades Pendentes')),
                TextButton(
                  onPressed: () => context.push(AppRoutes.activities),
                  child: const Text('Ver matriz completa'),
                ),
              ],
            ),
            ...activities.take(3).map(
                  (activity) => ActivityCard(
                    activity: activity,
                    compact: true,
                    onTap: () => context.push('/atividades/${activity.id}'),
                  ),
                ),
            const SizedBox(height: AppSpacing.md),
            const _SectionTitle('Meus Cursos'),
            const _CourseCard(
              title: 'Segurança Digital',
              teacher: 'Prof. Ricardo M.',
              progress: .85,
              delta: '+12',
            ),
            const _CourseCard(
              title: 'Hardware & IoT',
              teacher: 'Profa. Juliana S.',
              progress: .62,
              delta: '+8',
            ),
            if (criticalActivities.isNotEmpty)
              const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader({required this.name, required this.institution});

  final String name;
  final String institution;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                institution.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .8,
                    ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                name,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ],
          ),
        ),
        const CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.primary,
          child: Icon(Icons.person, color: Colors.white),
        ),
      ],
    );
  }
}

class _PerformanceCard extends StatelessWidget {
  const _PerformanceCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      backgroundColor: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Seu desempenho acadêmico',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Row(
            children: [
              Expanded(
                child: _HeroMetric(
                  label: 'GPA',
                  value: '8.7',
                  icon: Icons.trending_up,
                ),
              ),
              Expanded(
                child: _HeroMetric(
                  label: 'ATIVIDADES HOJE',
                  value: '3',
                  icon: Icons.assignment_turned_in_outlined,
                ),
              ),
              Expanded(
                child: _HeroMetric(
                  label: 'SEMESTRE',
                  value: '4',
                  icon: Icons.school_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white70,
                fontWeight: FontWeight.w900,
              ),
        ),
      ],
    );
  }
}

class _UrgencyCard extends StatelessWidget {
  const _UrgencyCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      accentColor: AppColors.danger,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StatusLabel(
            label: 'CRÍTICO (IMEDIATO)',
            color: AppColors.danger,
            softColor: AppColors.dangerSoft,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Entrega Projeto Final - IA',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Hoje até 23:59',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: AppSpacing.md),
          const _StatusLabel(
            label: 'PLANEJAMENTO (PRÓXIMOS DIAS)',
            color: AppColors.secondary,
            softColor: AppColors.secondarySoft,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text('Estudo Dirigido: Cálculo III'),
          const Text(
            'Vence em 3 dias',
            style: TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({
    required this.title,
    required this.teacher,
    required this.progress,
    required this.delta,
  });

  final String title;
  final String teacher;
  final double progress;
  final String delta;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  teacher,
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: AppSpacing.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    color: AppColors.primary,
                    backgroundColor: AppColors.primarySoft,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${(progress * 100).round()}%',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              Text(
                delta,
                style: const TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
      ),
    );
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({
    required this.label,
    required this.color,
    required this.softColor,
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
              letterSpacing: .4,
            ),
      ),
    );
  }
}
