import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/academic_blocks.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/section_header.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../providers/class_students_provider.dart';
import '../providers/teacher_activity_provider.dart';
import '../providers/teacher_offering_selection.dart';
import '../providers/teacher_review_provider.dart';
import '../services/teacher_activity_service.dart';
import '../services/teacher_review_service.dart';
import 'teacher_review_editor.dart';
import '../../../shared/widgets/app_button_styles.dart';

class TeacherWorkSubmissions extends ConsumerWidget {
  const TeacherWorkSubmissions({super.key, required this.work});

  final TeacherActivity work;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = (classId: work.classId, activityId: work.id);
    final submissions = teacherSubmissionsProvider(scope);
    final enrollments = teacherEnrollmentsProvider(work.classId);
    final enrolled = work.workflowEnabled ? ref.watch(enrollments) : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextButton(
          style: AppButtonStyles.link,
          onPressed: () {
            ref.invalidate(submissions);
            if (enrolled != null) ref.invalidate(enrollments);
          },
          child: const Text('Atualizar entregas e matrículas'),
        ),
        const SizedBox(height: AppSpacing.xs),
        ref.watch(submissions).when(
              skipLoadingOnRefresh: false,
              skipLoadingOnReload: false,
              loading: () => const LinearProgressIndicator(
                semanticsLabel: 'Carregando entregas',
              ),
              error: (error, _) => _LookupError(
                message:
                    'Erro ao consultar entregas. ${teacherReviewError(error)}',
                retry: () => ref.invalidate(submissions),
              ),
              data: (rows) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (rows.isEmpty)
                    const _Muted('Nenhuma entrega nesta atividade.'),
                  for (final submission in rows)
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          PersonTile(
                            name: classStudentName(
                                ref, work.classId, submission.studentId),
                            subtitle:
                                'Versão da resposta: ${submission.version}'
                                ' • enviada em ${_date.format(submission.submittedAt.toLocal())}',
                            badges: [
                              AppBadge(
                                  label: submission.statusLabel,
                                  tone: submissionTone(submission)),
                              if (submission.isLate)
                                const AppBadge(
                                    label: 'Entrega registrada com atraso',
                                    tone: AppBadgeTone.warning),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              style: AppButtonStyles.compact(),
                              onPressed: () => _open(context, ref, submission),
                              icon: const Icon(LucideIcons.fileText, size: 16),
                              label: const Text('Abrir entrega'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (enrolled != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    const SectionHeader(
                        title: 'Alunos sem entrega',
                        subtitle: 'Matrículas ativas sem resposta enviada'),
                    enrolled.when(
                      skipLoadingOnRefresh: false,
                      skipLoadingOnReload: false,
                      loading: () => const LinearProgressIndicator(
                        semanticsLabel: 'Carregando matrículas',
                      ),
                      error: (error, _) => _LookupError(
                        message:
                            'Não foi possível consultar as matrículas. ${teacherReviewError(error)}',
                        retry: () => ref.invalidate(enrollments),
                      ),
                      data: (students) {
                        final submitted = {
                          for (final row in rows) row.studentId
                        };
                        final withoutSubmission = students
                            .where((student) => !submitted.contains(student));
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (students.isEmpty)
                              const _Muted(
                                  'Nenhuma matrícula ativa nesta oferta.')
                            else if (withoutSubmission.isEmpty)
                              const _Muted(
                                  'Todos os alunos com matrícula ativa entregaram.'),
                            for (final student in withoutSubmission)
                              AppCard(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                child: PersonTile(
                                  name: classStudentName(
                                      ref, work.classId, student),
                                  badges: const [
                                    AppBadge(
                                        label: 'Sem entrega',
                                        tone: AppBadgeTone.neutral),
                                  ],
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
      ],
    );
  }

  Future<void> _open(
      BuildContext context, WidgetRef ref, TeacherSubmission submission) async {
    final session = ref.read(teacherNotesSessionProvider);
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => Consumer(builder: (_, ref, __) {
        final sameSession = ref.watch(teacherNotesSessionProvider) == session;
        final classId = ref.watch(selectedTeacherClassIdProvider);
        final offers = ref.watch(teacherOfferingsProvider);
        if (!sameSession || (classId != work.classId && !offers.isLoading)) {
          return Scaffold(
            appBar: AppBar(title: const Text('Avaliar entrega')),
            body: const Center(
                child: Text('A oferta não está disponível nesta sessão.')),
          );
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            ExcludeFocus(
              excluding: classId != work.classId,
              child: Offstage(
                offstage: classId != work.classId,
                child: TeacherReviewPage(submission: submission),
              ),
            ),
            if (classId != work.classId)
              const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: 'Validando oferta',
                  ),
                ),
              ),
          ],
        );
      }),
    ));
    if (!context.mounted || ref.read(teacherNotesSessionProvider) != session) {
      return;
    }
    final scope = (classId: work.classId, activityId: work.id);
    ref.invalidate(teacherSubmissionsProvider(scope));
    ref.invalidate(teacherSubmissionPreviewProvider(scope));
  }
}

class _LookupError extends StatelessWidget {
  const _LookupError({required this.message, required this.retry});

  final String message;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          TextButton(
              style: AppButtonStyles.link,
              onPressed: retry,
              child: const Text('Tentar novamente')),
        ],
      );
}

final _date = DateFormat('dd/MM/yyyy HH:mm');

/// Badge tone of a submission status: review pending stands out.
AppBadgeTone submissionTone(TeacherSubmission submission) {
  if (submission.awaitingReview) return AppBadgeTone.warning;
  if (submission.awaitingPublication) return AppBadgeTone.info;
  if (submission.result?.publicationState == 'published') {
    return AppBadgeTone.success;
  }
  return AppBadgeTone.neutral;
}

class _Muted extends StatelessWidget {
  const _Muted(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.inkMuted)),
      );
}
