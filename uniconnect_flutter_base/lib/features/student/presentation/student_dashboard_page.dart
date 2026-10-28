import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/academic_content.dart';
import '../../../shared/widgets/academic_demo_frame.dart';
import '../../academic/demo/synthetic_academic_providers.dart';
import '../../../shared/widgets/academic_metric_grid.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/bottom_nav.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/error_state_widget.dart';
import '../../../shared/widgets/section_header.dart';
import '../../activities/models/academic_activity.dart';
import '../../activities/providers/activity_provider.dart';
import '../../activities/widgets/activity_card.dart';
import '../../auth/providers/auth_provider.dart';
import '../../tenant/providers/tenant_provider.dart';
import '../../grades/models/subject_grade.dart';
import '../../grades/providers/grades_provider.dart';

class StudentDashboardPage extends ConsumerWidget {
  const StudentDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final tenant = ref.watch(currentTenantProvider);
    final activitiesAsync = ref.watch(activitiesProvider);
    final gradesAsync = ref.watch(subjectGradesProvider);

    return Scaffold(
      bottomNavigationBar: const UniBottomNav(currentIndex: 0),
      body: SafeArea(
          child: AcademicDemoFrame(
        child: AcademicContent(
          child: RefreshIndicator(
            onRefresh: () async {
              invalidateSyntheticAcademicData(ref);
              ref.invalidate(activitiesProvider);
              ref.invalidate(subjectGradesProvider);
              try {
                await Future.wait([
                  ref.read(activitiesProvider.future),
                  ref.read(subjectGradesProvider.future),
                ]);
              } catch (_) {}
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('UniConnect • Área do aluno',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(color: AppColors.primary)),
                          const SizedBox(height: AppSpacing.xs),
                          Text('Olá, que bom ter você aqui.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: AppColors.muted)),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(user?.name.trim().split(' ').first ?? 'Aluno',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Meu perfil',
                      onPressed: () => context.go(AppRoutes.profile),
                      icon: const Icon(Icons.person_outline),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                AppCard(
                  backgroundColor: AppColors.primary,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.school_outlined, color: Colors.white),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        tenant != null && tenant.id.isNotEmpty
                            ? tenant.name
                            : 'Instituição não informada',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                      if (user?.course case final course?
                          when course.trim().isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(course,
                            style: const TextStyle(color: Colors.white)),
                      ],
                      if (user?.semester case final semester?) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text('$semesterº semestre',
                            style: const TextStyle(color: Colors.white)),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      const Text('Seu panorama acadêmico',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                      const Divider(
                          height: AppSpacing.xl, color: Colors.white24),
                      _GradeSummary(grades: gradesAsync),
                      const SizedBox(height: AppSpacing.lg),
                      activitiesAsync.when(
                        skipLoadingOnRefresh: false,
                        data: (items) =>
                            AcademicMetricGrid(onDark: true, metrics: [
                          AcademicMetric(
                              label: 'Atividades disponíveis',
                              value: '${items.length}',
                              icon: Icons.assignment_outlined),
                          AcademicMetric(
                              label: 'Disciplinas nas atividades',
                              value:
                                  '${items.map((a) => a.subject).toSet().length}',
                              icon: Icons.menu_book_outlined),
                          AcademicMetric(
                              label: 'Prazos futuros',
                              value:
                                  '${items.where((a) => a.isUpcoming).length}',
                              icon: Icons.event_outlined),
                        ]),
                        loading: () => const Text('Carregando indicadores...',
                            style: TextStyle(color: Colors.white)),
                        error: (_, __) => const Text(
                            'Indicadores indisponíveis',
                            style: TextStyle(color: Colors.white)),
                      ),
                      if (tenant?.slug == 'edukmais') ...[
                        const SizedBox(height: AppSpacing.sm),
                        const Text('Ambiente de demonstração',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () => context.go(AppRoutes.activities),
                      icon: const Icon(Icons.checklist_outlined),
                      label: const Text('Ver atividades'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => context.go(AppRoutes.grades),
                      icon: const Icon(Icons.school_outlined),
                      label: const Text('Ver notas'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                const SectionHeader(
                  title: 'Sua rotina acadêmica',
                  subtitle: 'Atividades disponíveis na sua instituição',
                ),
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
                  data: (activities) => _AcademicAgenda(activities: activities),
                ),
              ],
            ),
          ),
        ),
      )),
    );
  }
}

class _AcademicAgenda extends StatelessWidget {
  const _AcademicAgenda({required this.activities});

  final List<AcademicActivity> activities;

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.event_note_outlined,
        title: 'Nenhuma atividade disponível',
        subtitle:
            'As atividades aparecerão aqui quando estiverem disponíveis para consulta.',
      );
    }
    final soon = activities.where((a) => a.isDueSoon).length;
    final expired = activities.where((a) => a.isExpired).length;
    final undated = activities.where((a) => a.dueDate == null).length;
    final subjects = activities.map((a) => a.subject).toSet().toList()..sort();
    final preview = activities.any((a) => a.demoReferenceTime != null)
        ? [
            ...activities.where((a) => a.isUpcoming),
            ...activities.where((a) => !a.isUpcoming)
          ]
        : activities;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
            title: 'Quadro de prazos',
            subtitle: 'Datas informadas nas atividades disponíveis'),
        AppCard(
            child: Column(children: [
          _DeadlineRow(
              icon: Icons.alarm_outlined,
              title: 'Prazo próximo (24h)',
              count: soon,
              color: AppColors.danger),
          const Divider(height: AppSpacing.lg),
          _DeadlineRow(
              icon: Icons.event_busy_outlined,
              title: 'Prazo encerrado',
              count: expired,
              color: AppColors.muted),
          const Divider(height: AppSpacing.lg),
          _DeadlineRow(
              icon: Icons.event_note_outlined,
              title: 'Sem prazo informado',
              count: undated,
              color: AppColors.primary),
          const SizedBox(height: AppSpacing.md),
          const Text('Prazo encerrado não informa se a atividade foi entregue.',
              style: TextStyle(color: AppColors.muted)),
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
            compact: true,
            onTap: () => context.push('/atividades/${activity.id}'),
          ),
        const SizedBox(height: AppSpacing.md),
        const SectionHeader(
          title: 'Disciplinas nas atividades',
          subtitle: 'Informações derivadas da agenda disponível',
        ),
        for (final subject in subjects)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading:
                const Icon(Icons.menu_book_outlined, color: AppColors.primary),
            title: Text(subject),
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
          style: TextStyle(color: Colors.white)),
      error: (_, __) => const Text('Média indisponível',
          style: TextStyle(color: Colors.white)),
      data: (allItems) {
        final items = allItems.where((g) => !g.isHistorical).toList();
        if (items.isEmpty) {
          return const Text('Sem notas disponíveis',
              style: TextStyle(color: Colors.white));
        }
        final average =
            items.map((g) => g.p1).reduce((a, b) => a + b) / items.length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Média simples', style: TextStyle(color: Colors.white)),
            Text(average.toStringAsFixed(1),
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w700)),
            Text(
                '${items.length} ${items.length == 1 ? 'avaliação disponível' : 'avaliações disponíveis'}',
                style: const TextStyle(color: Colors.white)),
            const SizedBox(height: AppSpacing.xs),
            const Text(
                'Indicador de acompanhamento, sem valor de coeficiente oficial.',
                style: TextStyle(color: Colors.white)),
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
    return Row(children: [
      Icon(icon, color: color),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
          child:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700))),
      const SizedBox(width: AppSpacing.sm),
      Text('$count',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(color: color, fontWeight: FontWeight.w700)),
    ]);
  }
}
