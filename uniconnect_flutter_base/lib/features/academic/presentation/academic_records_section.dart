import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_button_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/status_banner.dart';
import '../models/academic_records.dart';
import '../providers/academic_records_providers.dart';

/// Subjects of the selected period followed by the student's history.
/// Choosing a period in the history brings its subjects to the top.
class AcademicRecordsSection extends ConsumerStatefulWidget {
  const AcademicRecordsSection({super.key});

  @override
  ConsumerState<AcademicRecordsSection> createState() =>
      _AcademicRecordsSectionState();
}

class _AcademicRecordsSectionState
    extends ConsumerState<AcademicRecordsSection> {
  final _periodKey = GlobalKey();

  /// `null` until the student picks one: the API answers with the active
  /// period.
  String? _periodId;

  void _select(String periodId, {bool reveal = false}) {
    setState(() => _periodId = periodId);
    if (!reveal) return;
    final target = _periodKey.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(target,
          duration: const Duration(milliseconds: 250));
    }
  }

  void _reload() {
    ref.invalidate(academicPeriodsProvider);
    ref.invalidate(academicOverviewProvider(_periodId));
    ref.invalidate(academicHistoryProvider);
  }

  @override
  Widget build(BuildContext context) {
    final overview = ref.watch(academicOverviewProvider(_periodId));
    final periods =
        ref.watch(academicPeriodsProvider).asData?.value ?? const [];
    final current = overview.asData?.value;
    final selectedId = _periodId ?? current?.period.id;
    return Column(
      key: _periodKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Disciplinas por período',
          subtitle: current?.period.label,
          actionLabel: 'Atualizar',
          onAction: _reload,
        ),
        if (periods.length > 1) ...[
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final period in periods)
                ChoiceChip(
                  label: Text(period.label),
                  selected: period.id == selectedId,
                  onSelected: (_) => _select(period.id),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        overview.when(
          skipLoadingOnReload: false,
          loading: () => const _LoadingCard(label: 'Carregando disciplinas'),
          error: (error, _) => _ErrorCard(
            message: academicRecordsErrorText(error),
            onRetry: _reload,
          ),
          data: (data) => _PeriodSubjects(overview: data),
        ),
        const SizedBox(height: AppSpacing.md),
        const SectionHeader(title: 'Histórico acadêmico'),
        _History(selectedId: selectedId, onSelect: _select, onRetry: _reload),
      ],
    );
  }
}

class _PeriodSubjects extends StatelessWidget {
  const _PeriodSubjects({required this.overview});

  final AcademicOverviewRecord overview;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (overview.warnings.isNotEmpty || !overview.complete)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: StatusBanner(
              title: 'Sobre estes dados',
              message: [
                ...overview.warnings,
                if (!overview.complete && overview.warnings.isEmpty)
                  'Parte dos dados deste período não pôde ser carregada.',
              ].join(' '),
              tone: AppBadgeTone.neutral,
              icon: LucideIcons.info,
            ),
          ),
        if (overview.subjects.isEmpty)
          const _MessageCard(
            icon: LucideIcons.bookOpen,
            message: 'Nenhuma disciplina neste período.',
          )
        else
          for (final subject in overview.subjects)
            AcademicSubjectCard(subject: subject),
      ],
    );
  }
}

/// One subject: status, activities, final average and absences when the
/// institution sends them, and the grade of each assessment.
class AcademicSubjectCard extends StatelessWidget {
  const AcademicSubjectCard({super.key, required this.subject});

  final AcademicSubjectRecord subject;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = text.bodySmall?.copyWith(color: AppColors.inkMuted);
    final status = subjectStatus(subject);
    final activities = switch (subject.activityCount) {
      0 => 'Nenhuma atividade',
      1 => '1 atividade',
      final count => '$count atividades',
    };
    final graded =
        subject.assessments.isEmpty ? '' : ' • ${subject.gradedCount} com nota';
    final partial = subject.activitiesComplete ? '' : ' • lista parcial';
    final metrics = [
      if (subject.finalAverage case final average?)
        'Média final ${formatGrade(average)}',
      if (subject.absences case final absences?)
        'Faltas ${formatGrade(absences, decimals: 0)}'
            '${subject.absencePercentage == null ? '' : ' (${formatGrade(subject.absencePercentage!, decimals: 0)}%)'}',
    ];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(subject.title, style: text.titleMedium)),
              if (status != null) ...[
                const SizedBox(width: AppSpacing.xs),
                AppBadge(label: status.$1, tone: status.$2),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Row(
            children: [
              const Icon(LucideIcons.listChecks,
                  size: 16, color: AppColors.inkMuted),
              const SizedBox(width: AppSpacing.xxs),
              Expanded(child: Text('$activities$graded$partial', style: muted)),
            ],
          ),
          if (metrics.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final metric in metrics)
                  AppBadge(label: metric, tone: AppBadgeTone.primary),
              ],
            ),
          ],
          if (subject.assessments.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1),
            for (final assessment in subject.assessments)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        assessment.title?.trim().isNotEmpty == true
                            ? assessment.title!.trim()
                            : 'Avaliação',
                        style: text.bodyMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      assessment.grade == null
                          ? 'Sem nota'
                          : formatGrade(assessment.grade!),
                      style: assessment.grade == null ? muted : text.titleSmall,
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _History extends ConsumerWidget {
  const _History({
    required this.selectedId,
    required this.onSelect,
    required this.onRetry,
  });

  final String? selectedId;
  final void Function(String id, {bool reveal}) onSelect;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return ref.watch(academicHistoryProvider).when(
          skipLoadingOnReload: false,
          loading: () => const _LoadingCard(label: 'Carregando histórico'),
          error: (error, _) => _ErrorCard(
            message: academicRecordsErrorText(error),
            onRetry: onRetry,
          ),
          data: (history) {
            if (history.periods.isEmpty) {
              return const _MessageCard(
                icon: LucideIcons.history,
                message: 'Ainda não há períodos no seu histórico.',
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final period in history.periods)
                  AppCard(
                    backgroundColor: period.period.id == selectedId
                        ? AppColors.primaryTint
                        : null,
                    onTap: () => onSelect(period.period.id, reveal: true),
                    child: Row(
                      children: [
                        const IconTile(
                            icon: LucideIcons.calendarRange, size: 36),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(period.period.label, style: text.titleSmall),
                              const SizedBox(height: 2),
                              Text(
                                historySummary(period),
                                style: text.bodySmall
                                    ?.copyWith(color: AppColors.inkMuted),
                              ),
                            ],
                          ),
                        ),
                        const Icon(LucideIcons.chevronRight,
                            size: 18, color: AppColors.inkMuted),
                      ],
                    ),
                  ),
              ],
            );
          },
        );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: LinearProgressIndicator(semanticsLabel: label),
      );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: Theme.of(context).textTheme.bodyMedium),
            TextButton(
              style: AppButtonStyles.link,
              onPressed: onRetry,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => AppCard(
        child: Row(
          children: [
            IconTile(
              icon: icon,
              color: AppColors.inkMuted,
              background: AppColors.surface200,
              size: 36,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.inkMuted),
              ),
            ),
          ],
        ),
      );
}

/// Label and tone for a subject status; the API label wins when present.
(String, AppBadgeTone)? subjectStatus(AcademicSubjectRecord subject) {
  final tone = switch (subject.status) {
    'in_progress' => AppBadgeTone.info,
    'passed' || 'completed' || 'credited' || 'exempt' => AppBadgeTone.success,
    'failed' => AppBadgeTone.danger,
    'suspended' || 'cancelled' => AppBadgeTone.warning,
    _ => AppBadgeTone.neutral,
  };
  final custom = subject.statusLabel?.trim();
  if (custom != null && custom.isNotEmpty) return (custom, tone);
  final label = switch (subject.status) {
    'in_progress' => 'Cursando',
    'passed' => 'Aprovada',
    'failed' => 'Reprovada',
    'exempt' => 'Dispensada',
    'suspended' => 'Trancada',
    'cancelled' => 'Cancelada',
    'completed' => 'Concluída',
    'credited' => 'Aproveitada',
    'not_taken' => 'Não cursada',
    _ => null,
  };
  return label == null ? null : (label, tone);
}

String historySummary(AcademicOverviewRecord period) {
  final count = period.subjects.length;
  final subjects = switch (count) {
    0 => 'Nenhuma disciplina',
    1 => '1 disciplina',
    _ => '$count disciplinas',
  };
  final statuses = <String, int>{};
  for (final subject in period.subjects) {
    final label = subjectStatus(subject)?.$1;
    if (label != null) statuses[label] = (statuses[label] ?? 0) + 1;
  }
  final details = statuses.entries
      .map((entry) => '${entry.value} ${_plural(entry.key, entry.value)}')
      .join(', ');
  return details.isEmpty ? subjects : '$subjects • $details';
}

/// Status labels are feminine adjectives ("concluída"): plural adds an
/// "s". Gerunds ("cursando") and API labels stay as they are.
String _plural(String label, int count) {
  final lower = label.toLowerCase();
  return count > 1 && lower.endsWith('a') ? '${lower}s' : lower;
}

String formatGrade(double value, {int decimals = 1}) =>
    value.toStringAsFixed(decimals).replaceAll('.', ',');
