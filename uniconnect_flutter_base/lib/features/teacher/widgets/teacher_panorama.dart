import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../shared/widgets/academic_metric_grid.dart';
import '../providers/teacher_activity_provider.dart';
import '../providers/teacher_review_provider.dart';

/// Works sampled for the review count; the same bound as the class
/// overview, so the home screen makes no extra API request.
const panoramaReviewSample = 3;

/// Real teaching indicators for the teacher home. Classes come from the
/// authorized offerings; works and pending reviews from the selected class,
/// reusing the previews the home already loads. A "+" marks a partial count.
class TeacherPanorama extends ConsumerWidget {
  const TeacherPanorama({super.key, required this.classId});

  final String? classId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offerings = ref.watch(teacherOfferingsProvider);
    final classes = offerings.asData?.value.length;
    final selected = classId;
    String published = '—';
    String pending = '—';
    if (selected != null) {
      final preview = ref.watch(teacherActivityPreviewProvider(selected));
      if (preview.isLoading) {
        published = pending = '…';
      } else if (preview.asData?.value case final data?) {
        final works = data.rows.where((work) => !work.isExam).toList();
        final partial = data.rows.length < data.total;
        published = '${works.where((work) => work.state == 'published').length}'
            '${partial ? '+' : ''}';
        final reviewable = works
            .where((work) => work.hasSubmissions && work.workflowEnabled)
            .toList();
        var count = 0;
        var loading = false;
        var limited = partial || reviewable.length > panoramaReviewSample;
        for (final work in reviewable.take(panoramaReviewSample)) {
          final result = ref.watch(teacherSubmissionPreviewProvider(
              (classId: work.classId, activityId: work.id)));
          final page = result.asData?.value;
          if (result.isLoading) {
            loading = true;
          } else if (page == null) {
            limited = true;
          } else {
            limited = limited || page.rows.length < page.total;
            count += page.rows.where((row) => row.awaitingReview).length;
          }
        }
        pending = loading ? '…' : '$count${limited ? '+' : ''}';
      }
    }
    final caption = selected == null
        ? 'Selecione uma turma abaixo para ver trabalhos e correções.'
        : 'Trabalhos e correções da turma selecionada.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AcademicMetricGrid(onDark: true, metrics: [
          AcademicMetric(
              label: 'Turmas',
              value: classes == null ? '…' : '$classes',
              icon: LucideIcons.users),
          AcademicMetric(
              label: 'Trabalhos publicados',
              value: published,
              icon: LucideIcons.clipboardList),
          AcademicMetric(
              label: 'Correções pendentes',
              value: pending,
              icon: LucideIcons.clipboardCheck),
        ]),
        const SizedBox(height: 8),
        Text(caption,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: const Color(0xCCFFFFFF))),
      ],
    );
  }
}
