import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/bottom_nav.dart';
import '../../../shared/widgets/section_header.dart';
import '../models/academic_activity.dart';
import '../providers/activity_provider.dart';
import '../widgets/activity_card.dart';

class ActivitiesPage extends ConsumerWidget {
  const ActivitiesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activities = ref.watch(activitiesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Atividades')),
      bottomNavigationBar: const UniBottomNav(currentIndex: 1),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          AppCard(
            backgroundColor: AppColors.primarySoft,
            child: Row(
              children: [
                const Icon(Icons.filter_alt_outlined, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Atividades agrupadas por urgência para reduzir ruído acadêmico.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
          ),
          _ActivityGroup(
            title: 'Críticas',
            subtitle: 'Exigem ação imediata',
            activities: activities
                .where((activity) =>
                    activity.priority == ActivityPriority.critical)
                .toList(),
          ),
          _ActivityGroup(
            title: 'Prioridade média',
            subtitle: 'Importantes, mas com respiro',
            activities: activities
                .where(
                    (activity) => activity.priority == ActivityPriority.medium)
                .toList(),
          ),
          _ActivityGroup(
            title: 'Baixa prioridade',
            subtitle: 'Acompanhar sem interromper seu foco',
            activities: activities
                .where((activity) => activity.priority == ActivityPriority.low)
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _ActivityGroup extends StatelessWidget {
  const _ActivityGroup({
    required this.title,
    required this.subtitle,
    required this.activities,
  });

  final String title;
  final String subtitle;
  final List<AcademicActivity> activities;

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title, subtitle: subtitle),
        ...activities.map(
          (activity) => ActivityCard(
            activity: activity,
            onTap: () => context.push('/atividades/${activity.id}'),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
