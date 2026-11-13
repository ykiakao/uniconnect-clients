import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/quick_action_grid.dart';
import '../../../shared/widgets/academic_content.dart';
import '../../../shared/widgets/academic_demo_frame.dart';
import '../../academic/demo/synthetic_academic_providers.dart';
import '../../../shared/widgets/academic_metric_grid.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/bottom_nav.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/error_state_widget.dart';
import '../../../shared/widgets/section_header.dart';
import '../../activities/models/academic_activity.dart';
import '../../activities/providers/activity_provider.dart';
import '../../activities/providers/student_submission_provider.dart';
import '../../activities/widgets/activity_card.dart';
import '../../auth/providers/auth_provider.dart';
import '../../tenant/providers/tenant_provider.dart';
import '../../grades/models/subject_grade.dart';
import '../../grades/providers/grades_provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../shared/widgets/app_button_styles.dart';

class StudentDashboardPage extends ConsumerWidget {
  const StudentDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final tenant = ref.watch(currentTenantProvider);
    final activitiesAsync = ref.watch(activitiesProvider);
    final now = ref.watch(activityClockProvider);
    final gradesAsync = ref.watch(subjectGradesProvider);
    final demo = ref.watch(syntheticDemoEnabledProvider);

    return Scaffold(
      appBar: const AppHeader(title: 'Início', showProfile: true),
      bottomNavigationBar: const UniBottomNav(currentIndex: 0),
      body: SafeArea(
        child: AcademicDemoFrame(
          child: AcademicContent(
            child: RefreshIndicator(
              onRefresh: () async {
                invalidateSyntheticAcademicData(ref);
                ref.invalidate(activitiesProvider);
                ref.invalidate(subjectGradesProvider);
                ref.invalidate(ownSubmissionProvider);
                try {
                  await Future.wait([
                    ref.read(activitiesProvider.future),
                    ref.read(subjectGradesProvider.future),
                  ]);
                } catch (_) {}
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageHorizontal,
                  AppSpacing.pageTop,
                  AppSpacing.pageHorizontal,
                  AppSpacing.pageBottom,
                ),
                children: [
                  _Greeting(name: user?.name),
                  const SizedBox(height: AppSpacing.md),
                  _StudentHero(
                    institution: tenant != null && tenant.id.isNotEmpty
                        ? tenant.name
                        : 'Instituição não informada',
                    course: user?.course,
                    semester: user?.semester,
                    isDemo: tenant?.slug == 'edukmais',
                    grades: gradesAsync,
                    metrics: activitiesAsync.when(
                      skipLoadingOnRefresh: false,
                      data: (items) =>
                          AcademicMetricGrid(onDark: true, metrics: [
                        AcademicMetric(
                            label: 'Atividades disponíveis',
                            value: '${items.length}',
                            icon: LucideIcons.clipboardList),
                        AcademicMetric(
                            label: 'Disciplinas nas atividades',
                            value:
                                '${items.map((a) => a.subject).toSet().length}',
                            icon: LucideIcons.bookOpen),
                        AcademicMetric(
                            label: 'Prazos futuros',
                            value:
                                '${items.where((a) => a.isUpcomingAt(now)).length}',
                            icon: LucideIcons.calendar),
                      ]),
                      loading: () =>
                          const _OnDarkText('Carregando indicadores...'),
                      error: (_, __) =>
                          const _OnDarkText('Indicadores indisponíveis'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const _QuickActions(),
                  const SizedBox(height: AppSpacing.lg),
                  activitiesAsync.when(
                    skipLoadingOnRefresh: false,
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                      child: Column(children: [
                        LinearProgressIndicator(),
                        SizedBox(height: AppSpacing.md),
                        Text('Carregando atividades...'),
                      ]),
                    ),
                    error: (_, __) => ErrorStateWidget(
                      title: 'Não foi possível carregar a agenda',
                      error: 'Confira sua conexão e tente novamente.',
                      onRetry: () {
                        invalidateSyntheticAcademicData(ref);
                        ref.invalidate(activitiesProvider);
                      },
                    ),
                    data: (activities) => _AcademicAgenda(
                      activities: activities,
                      now: now,
                      demo: demo,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final firstName = name?.trim().split(' ').first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('UniConnect • Área do aluno',
            style: text.labelMedium?.copyWith(color: AppColors.primary)),
        const SizedBox(height: AppSpacing.xxs),
        Text('Olá, que bom ter você aqui.',
            style: text.bodyMedium?.copyWith(color: AppColors.inkMuted)),
        Text(
          firstName == null || firstName.isEmpty ? 'Aluno' : firstName,
          style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

/// Navy identity block from the kit, with the student's context and
/// the numbers that matter at a glance.
class _StudentHero extends StatelessWidget {
  const _StudentHero({
    required this.institution,
    required this.course,
    required this.semester,
    required this.isDemo,
    required this.grades,
    required this.metrics,
  });

  final String institution;
  final String? course;
  final int? semester;
  final bool isDemo;
  final AsyncValue<List<SubjectGrade>> grades;
  final Widget metrics;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final details = [
      if (course case final value? when value.trim().isNotEmpty) value,
      if (semester case final value?) '$valueº semestre',
    ];
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const IconTile(
                icon: LucideIcons.graduationCap,
                color: Colors.white,
                background: Color(0x26FFFFFF),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(institution,
                        style: text.titleLarge?.copyWith(color: Colors.white)),
                    for (final detail in details)
                      Text(detail,
                          style: text.bodySmall
                              ?.copyWith(color: const Color(0xCCFFFFFF))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Seu panorama acadêmico',
              style: text.titleSmall?.copyWith(color: Colors.white)),
          const SizedBox(height: AppSpacing.sm),
          metrics,
          const Divider(height: AppSpacing.lg, color: Color(0x33FFFFFF)),
          _GradeSummary(grades: grades),
          if (isDemo) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0x26FFFFFF),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text('Ambiente de demonstração',
                  style: text.labelSmall
                      ?.copyWith(color: Colors.white, letterSpacing: 0)),
            ),
          ],
        ],
      ),
    );
  }
}

class _OnDarkText extends StatelessWidget {
  const _OnDarkText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(text,
      style:
          Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white));
}

/// Shortcuts to the other student areas, as a 2x2 grid of tappable tiles.
class _QuickActions extends StatelessWidget {
  const _QuickActions();

  static const _items = [
    (LucideIcons.listChecks, 'Ver atividades', AppRoutes.activities),
    (LucideIcons.graduationCap, 'Ver notas', AppRoutes.grades),
    (LucideIcons.bell, 'Ver avisos', AppRoutes.notices),
    (LucideIcons.landmark, 'Ver acadêmico', AppRoutes.academic),
  ];

  @override
  Widget build(BuildContext context) => QuickActionGrid(items: [
        for (final (icon, label, route) in _items)
          (icon: icon, label: label, onTap: () => context.go(route)),
      ]);
}

class _AcademicAgenda extends StatelessWidget {
  const _AcademicAgenda(
      {required this.activities, required this.now, required this.demo});

  final List<AcademicActivity> activities;
  final DateTime now;
  final bool demo;

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return const EmptyStateWidget(
        icon: LucideIcons.calendarDays,
        title: 'Nenhuma atividade disponível',
        subtitle:
            'As atividades aparecerão aqui quando estiverem disponíveis para consulta.',
      );
    }
    final soon = activities.where((a) => a.isDueSoonAt(now)).length;
    final expired = activities
        .where((a) => a.priorityAt(now) == ActivityPriority.expired)
        .length;
    final undated = activities.where((a) => a.dueDate == null).length;
    final subjects = activities.map((a) => a.subject).toSet().toList()..sort();
    final upcoming = activities.where((a) => a.isUpcomingAt(now)).toList()
      ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
    final preview = [
      ...upcoming,
      ...activities.where((a) => !a.isUpcomingAt(now)),
    ];
    final candidates = [
      ...upcoming,
      ...activities.where((a) => a.dueDate == null),
      ...activities.where(
          (a) => a.priorityAt(now) == ActivityPriority.expired && a.allowLate),
    ]
        .where(
            (a) => a.publicationState == 'published' && a.acceptsTextSubmission)
        .take(3)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!demo) ...[
          _PendingActivities(candidates: candidates, now: now),
          const SizedBox(height: AppSpacing.md),
        ],
        const SectionHeader(
            title: 'Quadro de prazos',
            subtitle: 'Datas informadas nas atividades disponíveis'),
        AppCard(
            child: Column(children: [
          _DeadlineRow(
              icon: LucideIcons.alarmClock,
              title: 'Prazo próximo (24h)',
              count: soon,
              color: AppColors.danger),
          const Divider(height: AppSpacing.md),
          _DeadlineRow(
              icon: LucideIcons.calendarX,
              title: 'Prazo encerrado',
              count: expired,
              color: AppColors.muted),
          const Divider(height: AppSpacing.md),
          _DeadlineRow(
              icon: LucideIcons.calendarDays,
              title: 'Sem prazo informado',
              count: undated,
              color: AppColors.primary),
          const SizedBox(height: AppSpacing.md),
          Text('Prazo encerrado não informa se a atividade foi entregue.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.inkMuted)),
        ])),
        const SizedBox(height: AppSpacing.md),
        SectionHeader(
          title: 'Atividades acadêmicas',
          actionLabel: 'Ver todas',
          onAction: () => context.go(AppRoutes.activities),
        ),
        for (final activity in preview.take(3))
          ActivityCard(
            activity: activity,
            now: now,
            compact: true,
            onTap: () => context.push('/atividades/${activity.id}'),
          ),
        const SizedBox(height: AppSpacing.md),
        const SectionHeader(
          title: 'Disciplinas nas atividades',
          subtitle: 'Informações derivadas da agenda disponível',
        ),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final subject in subjects)
              Chip(
                avatar: const Icon(LucideIcons.bookOpen,
                    size: 16, color: AppColors.primary),
                label: Text(subject),
              ),
          ],
        ),
      ],
    );
  }
}

class _PendingActivities extends ConsumerWidget {
  const _PendingActivities({required this.candidates, required this.now});

  final List<AcademicActivity> candidates;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = <AcademicActivity>[];
    final failures = <String>[];
    var loading = false;
    for (final activity in candidates) {
      final submission = ref.watch(ownSubmissionProvider(activity.id));
      if (submission.isLoading) {
        loading = true;
      } else if (submission.hasError) {
        failures.add(activity.id);
      } else if (submission.hasValue && submission.requireValue == null) {
        pending.add(activity);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Entregas pendentes',
          subtitle: 'Prévia de até três atividades abertas para envio',
          actionLabel: 'Ver lista',
          onAction: () => context.go(AppRoutes.activities),
        ),
        if (candidates.isEmpty)
          const _MutedText('Nenhuma atividade aberta para entrega textual.'),
        if (loading)
          const LinearProgressIndicator(semanticsLabel: 'Consultando entregas'),
        if (failures.isNotEmpty)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Algumas entregas não puderam ser consultadas'),
                TextButton(
                  style: AppButtonStyles.link,
                  onPressed: () {
                    for (final id in failures) {
                      ref.invalidate(ownSubmissionProvider(id));
                    }
                  },
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        if (candidates.isNotEmpty &&
            !loading &&
            failures.isEmpty &&
            pending.isEmpty)
          const _MutedText('Nenhuma pendência nas atividades consultadas.'),
        for (final activity in pending)
          ActivityCard(
            activity: activity,
            now: now,
            compact: true,
            onTap: () => context.push('/atividades/${activity.id}'),
          ),
      ],
    );
  }
}

class _GradeSummary extends StatelessWidget {
  const _GradeSummary({required this.grades});

  final AsyncValue<List<SubjectGrade>> grades;

  @override
  Widget build(BuildContext context) {
    return grades.when(
      skipLoadingOnRefresh: false,
      loading: () => const Text('Carregando notas...',
          style: TextStyle(color: Color(0xE6FFFFFF))),
      error: (_, __) => const Text('Notas indisponíveis',
          style: TextStyle(color: Color(0xE6FFFFFF))),
      data: (allItems) {
        final items = allItems.where((g) => !g.isHistorical).toList();
        if (items.isEmpty) {
          return const Text('Sem notas disponíveis',
              style: TextStyle(color: Color(0xE6FFFFFF)));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                '${items.length} ${items.length == 1 ? 'avaliação disponível' : 'avaliações disponíveis'}',
                style: const TextStyle(color: Colors.white)),
            const SizedBox(height: AppSpacing.xs),
            const Text('Consulte o boletim por disciplina em Ver notas.',
                style: TextStyle(color: Color(0xE6FFFFFF))),
          ],
        );
      },
    );
  }
}

class _DeadlineRow extends StatelessWidget {
  const _DeadlineRow(
      {required this.icon,
      required this.title,
      required this.count,
      required this.color});

  final IconData icon;
  final String title;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(children: [
      IconTile(
        icon: icon,
        color: color,
        background: color.withValues(alpha: .12),
        size: 36,
      ),
      const SizedBox(width: AppSpacing.sm),
      Expanded(child: Text(title, style: text.titleSmall)),
      const SizedBox(width: AppSpacing.sm),
      Text('$count',
          style: text.titleLarge
              ?.copyWith(color: color, fontWeight: FontWeight.w700)),
    ]);
  }
}

class _MutedText extends StatelessWidget {
  const _MutedText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.inkMuted)),
      );
}
