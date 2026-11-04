import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/section_header.dart';
import '../providers/teacher_activity_provider.dart';
import '../providers/teacher_review_provider.dart';
import '../services/teacher_activity_service.dart';

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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          partial
                              ? 'Trabalhos publicados na prévia'
                              : 'Trabalhos publicados',
                          style: Theme.of(context).textTheme.titleMedium),
                      Text('${published.length}'),
                      const SizedBox(height: AppSpacing.sm),
                      Text('Próximos prazos',
                          style: Theme.of(context).textTheme.titleMedium),
                      if (upcoming.isEmpty)
                        Text(partial
                            ? 'Sem prazos futuros nos trabalhos consultados.'
                            : 'Sem prazos futuros nos trabalhos publicados.'),
                      for (final work in upcoming.take(3))
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(work.title),
                          subtitle: Text(DateFormat('dd/MM/yyyy HH:mm')
                              .format(work.dueDate!.toLocal())),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const SectionHeader(title: 'Entregas e correções'),
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
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              'Consulta de até 20 entregas por trabalho. Trabalhos consultados: $checked de ${works.length}.'),
          if (limited)
            const Text(
                'A prévia cobre parte da oferta. Consulte Atividades acadêmicas para ver a lista completa.'),
          if (loading)
            const LinearProgressIndicator(
                semanticsLabel: 'Consultando entregas'),
          if (checked > 0) ...[
            Text('Aguardando correção na consulta: $review'),
            Text(
                'Correções salvas aguardando publicação na consulta: $publication'),
          ],
          if (failures.isNotEmpty) ...[
            const Text('Algumas entregas não puderam ser consultadas.'),
            TextButton(
              onPressed: () {
                for (final scope in failures) {
                  ref.invalidate(teacherSubmissionPreviewProvider(scope));
                }
              },
              child: const Text('Tentar novamente'),
            ),
          ],
        ],
      ),
    );
  }
}
