import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/academic_content.dart';
import '../../../shared/widgets/academic_demo_frame.dart';
import '../../academic/demo/synthetic_academic_providers.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/bottom_nav.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/error_state_widget.dart';
import '../../../shared/widgets/help_tooltip.dart';
import '../../../shared/widgets/section_header.dart';
import '../models/academic_activity.dart';
import '../providers/activity_provider.dart';
import '../providers/student_submission_provider.dart';
import '../widgets/activity_card.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ActivitiesPage extends ConsumerStatefulWidget {
  const ActivitiesPage({super.key});

  @override
  ConsumerState<ActivitiesPage> createState() => _ActivitiesPageState();
}

class _ActivitiesPageState extends ConsumerState<ActivitiesPage> {
  late final TextEditingController _searchController;
  String _searchQuery = '';
  ActivityPriority? _priorityFilter;
  String? _subjectFilter;
  String? _publicationFilter;

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
    final activitiesAsync = ref.watch(activitiesProvider);
    final now = ref.watch(activityClockProvider);

    return Scaffold(
      appBar: const AppHeader(
        title: 'Atividades',
        showProfile: true,
        fallbackRoute: AppRoutes.studentDashboard,
      ),
      bottomNavigationBar: const UniBottomNav(currentIndex: 1),
      body: SafeArea(
          child: AcademicDemoFrame(
        child: AcademicContent(
            child: activitiesAsync.when(
          skipLoadingOnRefresh: false,
          data: (allActivities) => _ActivitiesContent(
            allActivities: allActivities,
            now: now,
            searchController: _searchController,
            searchQuery: _searchQuery,
            priorityFilter: _priorityFilter,
            subjectFilter: _subjectFilter,
            publicationFilter: _publicationFilter,
            onSubjectChanged: (value) => setState(() => _subjectFilter = value),
            onPublicationChanged: (value) =>
                setState(() => _publicationFilter = value),
            onSearchChanged: (value) => setState(() => _searchQuery = value),
            onPriorityChanged: (value) {
              setState(() => _priorityFilter = value);
            },
            onClearFilters: _clearFilters,
            onRefresh: () async {
              invalidateSyntheticAcademicData(ref);
              ref.invalidate(activitiesProvider);
              await ref.read(activitiesProvider.future).catchError((_) {
                return <AcademicActivity>[];
              });
            },
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => ErrorStateWidget(
            error: submissionErrorText(error),
            onRetry: () {
              invalidateSyntheticAcademicData(ref);
              ref.invalidate(activitiesProvider);
            },
          ),
        )),
      )),
    );
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _priorityFilter = null;
      _subjectFilter = null;
      _publicationFilter = null;
    });
  }
}

class _ActivitiesContent extends StatelessWidget {
  const _ActivitiesContent({
    required this.allActivities,
    required this.now,
    required this.searchController,
    required this.searchQuery,
    required this.priorityFilter,
    required this.subjectFilter,
    required this.publicationFilter,
    required this.onSubjectChanged,
    required this.onPublicationChanged,
    required this.onSearchChanged,
    required this.onPriorityChanged,
    required this.onClearFilters,
    required this.onRefresh,
  });

  final List<AcademicActivity> allActivities;
  final DateTime now;
  final TextEditingController searchController;
  final String searchQuery;
  final ActivityPriority? priorityFilter;
  final String? subjectFilter;
  final String? publicationFilter;
  final ValueChanged<String?> onSubjectChanged;
  final ValueChanged<String?> onPublicationChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<ActivityPriority?> onPriorityChanged;
  final VoidCallback onClearFilters;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = searchQuery.trim().toLowerCase();
    final groups = <ActivityPriority, List<AcademicActivity>>{};
    final subjects = allActivities
        .map((activity) => activity.subject)
        .toSet()
        .toList()
      ..sort();
    final subject = subjects.contains(subjectFilter) ? subjectFilter : null;
    var filteredCount = 0;
    for (final activity in allActivities) {
      final matchesSearch = normalizedQuery.isEmpty ||
          activity.title.toLowerCase().contains(normalizedQuery) ||
          activity.subject.toLowerCase().contains(normalizedQuery) ||
          activity.teacher.toLowerCase().contains(normalizedQuery);
      if (!matchesSearch ||
          (subject != null && activity.subject != subject) ||
          (publicationFilter != null &&
              activity.publicationState != publicationFilter)) {
        continue;
      }
      final priority = activity.priorityAt(now);
      if (priorityFilter != null && priority != priorityFilter) continue;
      (groups[priority] ??= []).add(activity);
      filteredCount++;
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageHorizontal,
          AppSpacing.md,
          AppSpacing.pageHorizontal,
          AppSpacing.xl,
        ),
        children: [
          const ContextualTip(
            title: 'Organizado por prioridade',
            message:
                'Consulte os prazos por disciplina. Use a busca e os filtros para organizar sua rotina.',
            icon: LucideIcons.flag,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Buscar por atividade, disciplina ou professor...',
              prefixIcon: const Icon(LucideIcons.search),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                      tooltip: 'Limpar busca',
                      icon: const Icon(LucideIcons.x),
                      onPressed: onClearFilters,
                    )
                  : null,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final (value, label) in _priorityFilters)
                ChoiceChip(
                  label: Text(label),
                  showCheckmark: false,
                  selected: priorityFilter == value,
                  onSelected: (_) => onPriorityChanged(value),
                ),
            ],
          ),
          if (allActivities.isNotEmpty)
            ExpansionTile(
              title: const Text('Mais filtros'),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
              children: [
                _ActivityFilter(
                  label: 'Disciplina',
                  value: subject,
                  options: {for (final name in subjects) name: name},
                  onChanged: onSubjectChanged,
                ),
                const SizedBox(height: AppSpacing.sm),
                _ActivityFilter(
                  label: 'Situação da atividade',
                  value: publicationFilter,
                  options: const {
                    'published': 'Publicada',
                    'closed': 'Encerrada'
                  },
                  onChanged: onPublicationChanged,
                ),
              ],
            ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            backgroundColor: AppColors.primarySoft,
            child: Row(
              children: [
                const HelpTooltip(
                  message:
                      'Combine a busca com filtros de prazo, disciplina e situação da atividade.',
                  child: Icon(
                    LucideIcons.funnel,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Exibindo $filteredCount de ${allActivities.length} atividade(s)',
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
          if (filteredCount == 0)
            EmptyStateWidget(
              icon: LucideIcons.listChecks,
              title: 'Nenhuma atividade encontrada',
              subtitle: allActivities.isEmpty
                  ? 'Não há atividades disponíveis para consulta neste momento.'
                  : 'Tente outras palavras-chave ou limpe os filtros.',
              action: normalizedQuery.isNotEmpty ||
                      priorityFilter != null ||
                      subject != null ||
                      publicationFilter != null
                  ? onClearFilters
                  : null,
              actionLabel: 'Limpar filtros',
            )
          else ...[
            _ActivityGroup(
              now: now,
              title: 'Prazo encerrado',
              subtitle:
                  'A data passou; a situação de entrega não foi informada',
              activities: groups[ActivityPriority.expired] ?? const [],
            ),
            _ActivityGroup(
              now: now,
              title: 'Críticas',
              subtitle: 'Atividades com prazo próximo',
              activities: groups[ActivityPriority.critical] ?? const [],
            ),
            _ActivityGroup(
              now: now,
              title: 'Prioridade média',
              subtitle: 'Importantes, mas com respiro',
              activities: groups[ActivityPriority.medium] ?? const [],
            ),
            _ActivityGroup(
              now: now,
              title: 'Baixa prioridade',
              subtitle: 'Acompanhar sem interromper seu foco',
              activities: groups[ActivityPriority.low] ?? const [],
            ),
            _ActivityGroup(
              now: now,
              title: 'Prazo não informado',
              subtitle: 'Consulte as orientações da disciplina',
              activities: groups[ActivityPriority.noDeadline] ?? const [],
            ),
          ],
        ],
      ),
    );
  }
}

class _ActivityFilter extends StatelessWidget {
  const _ActivityFilter({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final Map<String, String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      key: ValueKey((label, value)),
      initialValue: value ?? '',
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem(value: '', child: Text('Todas')),
        for (final option in options.entries)
          DropdownMenuItem(
            value: option.key,
            child: Text(option.value,
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (value) => onChanged(value == '' ? null : value),
    );
  }
}

class _ActivityGroup extends StatelessWidget {
  const _ActivityGroup({
    required this.now,
    required this.title,
    required this.subtitle,
    required this.activities,
  });

  final DateTime now;
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
            now: now,
            onTap: () => context.push('/atividades/${activity.id}'),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

const _priorityFilters = <(ActivityPriority?, String)>[
  (null, 'Todas'),
  (ActivityPriority.critical, 'Críticas'),
  (ActivityPriority.medium, 'Médias'),
  (ActivityPriority.low, 'Baixas'),
  (ActivityPriority.expired, 'Expiradas'),
  (ActivityPriority.noDeadline, 'Sem prazo'),
];
