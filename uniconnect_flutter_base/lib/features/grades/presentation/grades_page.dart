import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/academic_content.dart';
import '../../../shared/widgets/academic_demo_frame.dart';
import '../../academic/demo/synthetic_academic_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/bottom_nav.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/error_state_widget.dart';
import '../../../shared/widgets/section_header.dart';
import '../models/subject_grade.dart';
import '../providers/grades_provider.dart';
import '../../activities/models/academic_activity.dart';
import '../../activities/providers/activity_provider.dart';

class GradesPage extends ConsumerWidget {
  const GradesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(subjectGradesProvider);
    final activitiesAsync = subjectsAsync.asData?.value.isNotEmpty == true
        ? ref.watch(activitiesProvider)
        : null;
    final activities =
        activitiesAsync?.asData?.value ?? const <AcademicActivity>[];

    return Scaffold(
      appBar: const AppHeader(
        title: 'Quadro de notas',
        fallbackRoute: AppRoutes.studentDashboard,
      ),
      bottomNavigationBar: const UniBottomNav(currentIndex: 3),
      body: SafeArea(
          child: AcademicDemoFrame(
        child: AcademicContent(
          child: RefreshIndicator(
            onRefresh: () async {
              invalidateSyntheticAcademicData(ref);
              ref.invalidate(subjectGradesProvider);
              ref.invalidate(activitiesProvider);
              try {
                await Future.wait([
                  ref.read(subjectGradesProvider.future),
                  ref.read(activitiesProvider.future),
                ]);
              } catch (_) {}
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              children: [
                const SectionHeader(
                  title: 'Seu acompanhamento',
                  subtitle: 'Notas das atividades disponíveis para consulta',
                ),
                subjectsAsync.when(
                  skipLoadingOnRefresh: false,
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: Column(children: [
                      LinearProgressIndicator(),
                      SizedBox(height: AppSpacing.md),
                      Text('Carregando notas...'),
                    ]),
                  ),
                  error: (_, __) => ErrorStateWidget(
                    title: 'Não foi possível carregar suas notas',
                    error: 'Confira sua conexão e tente novamente.',
                    onRetry: () {
                      invalidateSyntheticAcademicData(ref);
                      ref.invalidate(subjectGradesProvider);
                      ref.invalidate(activitiesProvider);
                    },
                  ),
                  data: (subjects) => _GradesContent(
                      subjects: subjects, activities: activities),
                ),
                if (activitiesAsync?.hasError == true)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Text(
                        'Identificação das disciplinas temporariamente indisponível. Puxe para atualizar.',
                        style: TextStyle(color: AppColors.muted)),
                  ),
              ],
            ),
          ),
        ),
      )),
    );
  }
}

class _GradesContent extends StatelessWidget {
  const _GradesContent({required this.subjects, required this.activities});

  final List<SubjectGrade> subjects;
  final List<AcademicActivity> activities;

  @override
  Widget build(BuildContext context) {
    if (subjects.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.school_outlined,
        title: 'Nenhuma nota disponível',
        subtitle:
            'Suas notas aparecerão aqui quando forem disponibilizadas pela instituição.',
      );
    }
    final current = subjects.where((s) => !s.isHistorical).toList();
    final history = subjects.where((s) => s.isHistorical).toList();
    final activityById = {
      for (final activity in activities) activity.id: activity
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
            '${current.length} ${current.length == 1 ? 'avaliação disponível' : 'avaliações disponíveis'}'),
        const SizedBox(height: AppSpacing.md),
        const SectionHeader(title: 'Avaliações registradas'),
        for (final subject in current)
          _EvaluationCard(
              subject: subject, activity: activityById[subject.activityId]),
        if (history.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          const SectionHeader(
              title: 'Histórico acadêmico demonstrativo',
              subtitle: 'Avaliações de períodos anteriores'),
          for (final subject in history)
            _EvaluationCard(
                subject: subject, activity: activityById[subject.activityId]),
        ],
      ],
    );
  }
}

class _EvaluationCard extends StatelessWidget {
  const _EvaluationCard({required this.subject, this.activity});

  final SubjectGrade subject;
  final AcademicActivity? activity;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      accentColor: AppColors.primary,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.assignment_turned_in_outlined,
              color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(subject.subject,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: AppSpacing.xxs),
                Text('Referência: ${subject.code}',
                    style: const TextStyle(color: AppColors.muted)),
              ])),
        ]),
        if (subject.disciplineName != null || activity != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
              'Disciplina/turma: ${subject.disciplineName ?? activity!.subject}',
              style: const TextStyle(color: AppColors.primary)),
        ],
        if (subject.periodLabel != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text('Período acadêmico: ${subject.periodLabel}',
              style: const TextStyle(color: AppColors.muted)),
        ],
        const SizedBox(height: AppSpacing.md),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(12)),
          child: Wrap(
              spacing: AppSpacing.md,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                    subject.disciplineName != null && subject.activityId == null
                        ? 'Nota da avaliação'
                        : 'Nota da atividade',
                    style: const TextStyle(color: AppColors.primaryDark)),
                Text(subject.grade?.toString() ?? 'Nota indisponível',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppColors.primary, fontWeight: FontWeight.w700)),
              ]),
        ),
        if (subject.feedback?.trim().isNotEmpty == true) ...[
          const SizedBox(height: AppSpacing.md),
          const Text('Devolutiva da avaliação',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.xs),
          Text(subject.feedback!,
              style: const TextStyle(color: AppColors.muted)),
        ],
      ]),
    );
  }
}
