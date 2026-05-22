import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/bottom_nav.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/section_header.dart';
import '../models/academic_activity.dart';
import '../providers/activity_provider.dart';
import '../widgets/activity_card.dart';

class ActivitiesPage extends ConsumerStatefulWidget {
  const ActivitiesPage({super.key});

  @override
  ConsumerState<ActivitiesPage> createState() => _ActivitiesPageState();
}

class _ActivitiesPageState extends ConsumerState<ActivitiesPage> {
  late TextEditingController _searchController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allActivities = ref.watch(activitiesProvider);

    final filteredActivities = allActivities
        .where((activity) =>
            activity.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            activity.subject.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackRoute: AppRoutes.studentDashboard),
        title: const Text('Atividades'),
      ),
      bottomNavigationBar: const UniBottomNav(currentIndex: 1),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const AppBackAction(fallbackRoute: AppRoutes.studentDashboard),
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Buscar atividades...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            backgroundColor: AppColors.primarySoft,
            child: Row(
              children: [
                const Icon(Icons.filter_alt_outlined, color: AppColors.primary),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Total: ${filteredActivities.length} atividade(s)',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (filteredActivities.isEmpty)
            EmptyStateWidget(
              icon: Icons.checklist_outlined,
              title: 'Nenhuma atividade encontrada',
              subtitle: _searchQuery.isEmpty
                  ? 'Você está em dia com todas as atividades! 🎉'
                  : 'Tente usar outras palavras-chave',
            )
          else ...[
            _ActivityGroup(
              title: 'Críticas',
              subtitle: 'Exigem ação imediata',
              activities: filteredActivities
                  .where((activity) =>
                      activity.priority == ActivityPriority.critical)
                  .toList(),
            ),
            _ActivityGroup(
              title: 'Prioridade média',
              subtitle: 'Importantes, mas com respiro',
              activities: filteredActivities
                  .where((activity) =>
                      activity.priority == ActivityPriority.medium)
                  .toList(),
            ),
            _ActivityGroup(
              title: 'Baixa prioridade',
              subtitle: 'Acompanhar sem interromper seu foco',
              activities: filteredActivities
                  .where((activity) =>
                      activity.priority == ActivityPriority.low)
                  .toList(),
            ),
          ],
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
        SectionHeader(
          title: '$title (${activities.length})',
          subtitle: subtitle,
        ),
        ...activities.map(
          (activity) => ActivityCard(
            activity: activity,
            onTap: () => context.push('/atividades/${activity.id}'),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}
