import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/academic_blocks.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../providers/teacher_activity_provider.dart';
import '../providers/teacher_review_provider.dart';
import '../services/teacher_activity_service.dart';
import '../../../shared/widgets/app_button_styles.dart';

class TeacherWorkOverview extends ConsumerWidget {
  const TeacherWorkOverview({super.key, required this.classId});

  final String classId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = teacherActivityPreviewProvider(classId);
    return ref.watch(provider).when(
          skipLoadingOnRefresh: false,
          skipLoadingOnReload: false,
          loading: () => const LinearProgressIndicator(
            semanticsLabel: 'Carregando resumo da oferta',
          ),
          error: (error, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'Resumo da oferta indisponível. ${teacherReviewError(error)}'),
              TextButton(
                style: AppButtonStyles.link,
                onPressed: () => ref.invalidate(provider),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
          data: (preview) {
            final works =
                preview.rows.where((activity) => !activity.isExam).toList();
            final published =
                works.where((work) => work.state == 'published').toList();
            final now = DateTime.now();
            final upcoming = published
                .where((work) => work.dueDate?.isAfter(now) == true)
                .toList()
              ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
            final reviewable = works
                .where((work) => work.hasSubmissions && work.workflowEnabled)
                .toList();
            final sample = reviewable.take(3).toList();
            final partial = preview.rows.length < preview.total;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (partial)
                  Text(
                      'Prévia da oferta: ${preview.rows.length} de ${preview.total} registros consultados.'),
                AppCard(
                  icon: LucideIcons.calendarClock,
                  title: 'Próximos prazos',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      InfoLine(
                          label: partial
                              ? 'Trabalhos publicados na prévia'
                              : 'Trabalhos publicados',
                          value: '${published.length}',
                          icon: LucideIcons.clipboardList),
                      const Divider(height: AppSpacing.md),
                      if (upcoming.isEmpty)
                        Text(
                            partial
                                ? 'Sem prazos futuros nos trabalhos consultados.'
                                : 'Sem prazos futuros nos trabalhos publicados.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppColors.inkMuted)),
                      for (final work in upcoming.take(3))
                        _DeadlineRow(
                            title: work.title, due: work.dueDate!.toLocal()),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (sample.isEmpty)
                  Text(partial
                      ? 'Nenhum trabalho com fluxo de entrega na prévia.'
                      : 'Nenhum trabalho com fluxo de entrega nesta oferta.')
                else
                  _ReviewPreview(
                    works: sample,
                    partial: partial || sample.length < reviewable.length,
                  ),
              ],
            );
          },
        );
  }
}

class _ReviewPreview extends ConsumerWidget {
  const _ReviewPreview({required this.works, required this.partial});

  final List<TeacherActivity> works;
  final bool partial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final failures = <({String classId, String activityId})>[];
    var review = 0;
    var publication = 0;
    var checked = 0;
    var loading = false;
    var limited = partial;
    for (final work in works) {
      final scope = (classId: work.classId, activityId: work.id);
      final result = ref.watch(teacherSubmissionPreviewProvider(scope));
      if (result.isLoading) {
        loading = true;
      } else if (result.hasError) {
        failures.add(scope);
      } else if (result.asData case final data?) {
        checked++;
        final page = data.value;
        limited = limited || page.rows.length < page.total;
        review += page.rows.where((row) => row.awaitingReview).length;
        publication += page.rows.where((row) => row.awaitingPublication).length;
      }
    }
    final muted = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: AppColors.inkMuted);
    return AppCard(
      icon: LucideIcons.clipboardCheck,
      title: 'Entregas e correções',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (loading)
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.xs),
              child: LinearProgressIndicator(
                  semanticsLabel: 'Consultando entregas'),
            ),
          if (checked > 0) ...[
            InfoLine(
                label: 'Aguardando correção na consulta',
                value: '$review',
                icon: LucideIcons.hourglass,
                strong: review > 0),
            InfoLine(
                label: 'Correções salvas aguardando publicação na consulta',
                value: '$publication',
                icon: LucideIcons.send),
            const SizedBox(height: AppSpacing.xs),
          ],
          Text(
              'Consulta de até 20 entregas por trabalho. Trabalhos consultados: $checked de ${works.length}.',
              style: muted),
          if (limited)
            Text(
                'A prévia cobre parte da oferta. Consulte Atividades acadêmicas para ver a lista completa.',
                style: muted),
          if (failures.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text('Algumas entregas não puderam ser consultadas.',
                style: muted?.copyWith(color: AppColors.danger)),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: AppButtonStyles.link,
                onPressed: () {
                  for (final scope in failures) {
                    ref.invalidate(teacherSubmissionPreviewProvider(scope));
                  }
                },
                child: const Text('Tentar novamente'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DeadlineRow extends StatelessWidget {
  const _DeadlineRow({required this.title, required this.due});

  final String title;
  final DateTime due;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          const IconTile(icon: LucideIcons.calendar, size: 32),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleSmall),
                Text(DateFormat('dd/MM/yyyy HH:mm').format(due),
                    style: text.bodySmall?.copyWith(color: AppColors.inkMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
