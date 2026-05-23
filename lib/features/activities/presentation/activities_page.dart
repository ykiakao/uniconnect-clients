import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/bottom_nav.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/help_tooltip.dart';
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
  late final TextEditingController _searchController;
  String _searchQuery = '';
  ActivityPriority? _priorityFilter;

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
    final normalizedQuery = _searchQuery.trim().toLowerCase();
    final filteredActivities = allActivities.where((activity) {
      final matchesSearch = normalizedQuery.isEmpty ||
          activity.title.toLowerCase().contains(normalizedQuery) ||
          activity.subject.toLowerCase().contains(normalizedQuery) ||
          activity.teacher.toLowerCase().contains(normalizedQuery);
      final matchesPriority =
          _priorityFilter == null || activity.priority == _priorityFilter;

      return matchesSearch && matchesPriority;
    }).toList();

    return Scaffold(
      appBar: const AppHeader(
        title: 'Atividades',
        fallbackRoute: AppRoutes.studentDashboard,
      ),
      bottomNavigationBar: const UniBottomNav(currentIndex: 1),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(activitiesProvider);
          await Future<void>.delayed(const Duration(milliseconds: 350));
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          children: [
            const ContextualTip(
              title: 'Organizado por prioridade',
              message:
                  'Atividades críticas ficam no topo para você focar no que realmente importa.',
              icon: Icons.priority_high,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Buscar por atividade, disciplina ou professor...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        tooltip: 'Limpar busca',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<ActivityPriority?>(
                selected: {_priorityFilter},
                onSelectionChanged: (selection) {
                  setState(() => _priorityFilter = selection.first);
                },
                segments: const [
                  ButtonSegment(
                    value: null,
                    label: Text('Todas'),
                    icon: Icon(Icons.all_inbox_outlined),
                  ),
                  ButtonSegment(
                    value: ActivityPriority.critical,
                    label: Text('Críticas'),
                    icon: Icon(Icons.priority_high),
                  ),
                  ButtonSegment(
                    value: ActivityPriority.medium,
                    label: Text('Médias'),
                    icon: Icon(Icons.schedule),
                  ),
                  ButtonSegment(
                    value: ActivityPriority.low,
                    label: Text('Baixas'),
                    icon: Icon(Icons.check_circle_outline),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              backgroundColor: AppColors.primarySoft,
              child: Row(
                children: [
                  const HelpTooltip(
                    message:
                        'Filtragem em tempo real por título, disciplina, professor e prioridade.',
                    child: Icon(
                      Icons.filter_alt_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Exibindo ${filteredActivities.length} de ${allActivities.length} atividade(s)',
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
                    ? 'Você está em dia com este filtro.'
                    : 'Tente outras palavras-chave ou limpe os filtros.',
                action: _clearFilters,
                actionLabel: 'Limpar filtros',
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
                    .where(
                        (activity) => activity.priority == ActivityPriority.low)
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _priorityFilter = null;
    });
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
