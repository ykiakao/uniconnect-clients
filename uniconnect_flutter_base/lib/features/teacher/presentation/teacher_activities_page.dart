import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_tokens.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/academic_content.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/bottom_nav.dart';
import '../../../shared/widgets/section_header.dart';
import '../../auth/models/app_user.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/teacher_activity_provider.dart';
import '../providers/teacher_offering_selection.dart';
import '../providers/teacher_review_provider.dart';
import '../services/teacher_activity_service.dart';
import '../widgets/teacher_offering_picker.dart';
import '../widgets/teacher_work_draft_dialog.dart';
import '../widgets/teacher_work_submissions.dart';
import '../../../shared/widgets/app_button_styles.dart';

class TeacherActivitiesPage extends ConsumerWidget {
  const TeacherActivitiesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(currentUserProvider)?.role != UserRole.teacher) {
      return const Scaffold(
        appBar: AppHeader(title: 'Atividades acadêmicas'),
        body: Center(child: Text('Área exclusiva do professor')),
      );
    }
    final session = ref.watch(teacherNotesSessionProvider);
    final selection = ref.watch(teacherOfferingSelectionProvider).classId;
    final classId = ref.watch(selectedTeacherClassIdProvider);
    return Scaffold(
      appBar:
          const AppHeader(title: 'Atividades acadêmicas', showProfile: true),
      bottomNavigationBar: const UniBottomNav(currentIndex: 1, isTeacher: true),
      body: SafeArea(
        child: AcademicContent(
          child: _WorkArea(
            key: ValueKey((session, selection)),
            classId: classId,
          ),
        ),
      ),
    );
  }
}

class _WorkArea extends ConsumerStatefulWidget {
  const _WorkArea({super.key, required this.classId});

  final String? classId;

  @override
  ConsumerState<_WorkArea> createState() => _WorkAreaState();
}

class _WorkAreaState extends ConsumerState<_WorkArea> {
  String? _activityId;
  String? _notice;
  bool _busy = false;

  void _reload(String classId) {
    ref.invalidate(teacherActivitiesProvider(classId));
    ref.invalidate(teacherActivityPreviewProvider(classId));
  }

  /// Feedback sits above the scrolling list, so it stays visible without
  /// covering the actions at the end of it.
  void _announce(String message) => setState(() => _notice = message);

  bool _authorized(TeacherActivity work) =>
      ref.read(selectedTeacherClassIdProvider) == work.classId &&
      ref.read(teacherActivitiesProvider(work.classId)).asData?.value.any(
                (row) => row.id == work.id && row.revision == work.revision,
              ) ==
          true &&
      !ref.read(teacherActivitiesProvider(work.classId)).isLoading;

  Future<void> _transition(TeacherActivity work, {bool close = false}) async {
    if (_busy || !_authorized(work)) return;
    if (close) {
      final offer = ref
          .read(teacherOfferingsProvider)
          .asData
          ?.value
          .where((row) => row.id == work.classId)
          .firstOrNull;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Encerrar trabalho?'),
          content: Text(
              '“${work.title}” (${offer?.label ?? 'oferta selecionada'}) deixará de aceitar novas entregas. As entregas registradas poderão ser consultadas.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirmar encerramento')),
          ],
        ),
      );
      if (!mounted || confirmed != true || !_authorized(work)) return;
    }
    setState(() {
      _busy = true;
      _notice = null;
    });
    final session = ref.read(teacherNotesSessionProvider);
    try {
      final service = ref.read(teacherActivityServiceProvider);
      if (close) {
        await service.closeWork(work);
      } else {
        await service.publish(work);
      }
      if (!mounted || ref.read(teacherNotesSessionProvider) != session) return;
      _announce(close
          ? 'Encerramento confirmado pela API.'
          : 'Publicação confirmada pela API.');
      _reload(work.classId);
    } catch (error) {
      if (!mounted || ref.read(teacherNotesSessionProvider) != session) return;
      _announce(teacherReviewError(error));
      _reload(work.classId);
      if (error is ApiException && [403, 404].contains(error.statusCode)) {
        ref.invalidate(teacherOfferingsProvider);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(TeacherActivity work) async {
    if (_busy || !_authorized(work)) return;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TeacherWorkDraftDialog(work: work),
    );
    if (!mounted || saved != true) return;
    _announce('Edição do rascunho confirmada pela API.');
    _reload(work.classId);
  }

  @override
  Widget build(BuildContext context) {
    final classId = widget.classId;
    final workList =
        classId == null ? null : ref.watch(teacherActivitiesProvider(classId));
    final activityId = _activityId;
    final notice = classId == null ? null : _notice;
    final list = ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.pageTop,
        AppSpacing.pageHorizontal,
        AppSpacing.pageBottom,
      ),
      children: [
        if (activityId == null)
          TeacherOfferingPicker(enabled: !_busy)
        else
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: AppButtonStyles.link,
              onPressed: () => setState(() => _activityId = null),
              child: const Text('Voltar aos trabalhos'),
            ),
          ),
        if (activityId == null) ...[
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            onPressed: classId == null || _busy
                ? null
                : () => GoRouter.maybeOf(context)
                    ?.push(AppRoutes.teacherCreateActivity),
            child: const Text('Criar atividade'),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        if (_busy)
          const LinearProgressIndicator(semanticsLabel: 'Atualizando trabalho'),
        if (workList != null)
          workList.when(
            skipLoadingOnRefresh: false,
            skipLoadingOnReload: false,
            loading: () => const LinearProgressIndicator(
                semanticsLabel: 'Carregando trabalhos'),
            error: (error, _) => Column(
              children: [
                Text(
                    'Não foi possível consultar os trabalhos. ${teacherReviewError(error)}'),
                TextButton(
                  style: AppButtonStyles.link,
                  onPressed: () => _reload(classId!),
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
            data: (activities) {
              final works = activities.where((work) => !work.isExam);
              if (activityId != null) {
                final work =
                    works.where((row) => row.id == activityId).firstOrNull;
                return work == null || !work.hasSubmissions
                    ? const Text(
                        'As entregas deste trabalho estão indisponíveis.')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SectionHeader(
                              title: work.title, subtitle: work.stateLabel),
                          TeacherWorkSubmissions(
                              key: ValueKey(work.id), work: work),
                        ],
                      );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionHeader(
                    title: 'Trabalhos da oferta',
                    actionLabel: 'Atualizar trabalhos',
                    onAction: () => _reload(classId!),
                  ),
                  if (works.isEmpty)
                    const Text('Nenhum trabalho nesta oferta.'),
                  for (final work in works) _card(work),
                ],
              );
            },
          ),
      ],
    );
    return Column(
      children: [
        if (notice != null)
          Semantics(
            liveRegion: true,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(
                AppSpacing.pageHorizontal,
                AppSpacing.sm,
                AppSpacing.pageHorizontal,
                0,
              ),
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.primaryTint,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(notice, style: Theme.of(context).textTheme.bodySmall),
            ),
          ),
        Expanded(child: list),
      ],
    );
  }

  Widget _card(TeacherActivity work) {
    final text = Theme.of(context).textTheme;
    final deadline = work.dueDate?.toLocal();
    final expired = deadline?.isBefore(DateTime.now()) == true;
    final stateTone = switch (work.state) {
      'published' => AppBadgeTone.success,
      'draft' => AppBadgeTone.neutral,
      _ => AppBadgeTone.warning,
    };
    final accent = switch (work.state) {
      'published' => AppColors.success,
      'draft' => AppColors.lineStrong,
      _ => AppColors.warning,
    };
    final (kindIcon, kindLabel) = work.isExam
        ? (LucideIcons.fileCheck, 'Prova • sem entrega digital')
        : work.workflowEnabled
            ? (LucideIcons.send, 'Atividade • entrega digital')
            : (
                LucideIcons.school,
                'Avaliação presencial • sem entrega digital'
              );
    return AppCard(
      accentColor: accent,
      padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(work.title, style: text.titleMedium)),
              const SizedBox(width: AppSpacing.xs),
              AppBadge(label: work.stateLabel, tone: stateTone),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Row(
            children: [
              Icon(kindIcon, size: 14, color: AppColors.inkMuted),
              const SizedBox(width: AppSpacing.xxs),
              Flexible(
                child: Text(kindLabel,
                    style: text.bodySmall?.copyWith(
                        color: AppColors.inkMuted,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          if (work.assessment case final assessment?)
            Text(assessment.label,
                style: text.bodySmall?.copyWith(color: AppColors.inkMuted)),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              const Icon(LucideIcons.calendar,
                  size: 16, color: AppColors.inkMuted),
              const SizedBox(width: AppSpacing.xxs),
              Expanded(
                child: Text(
                  deadline != null
                      ? 'Prazo: ${DateFormat('dd/MM/yyyy HH:mm').format(deadline)}'
                      : 'Sem prazo informado',
                  style: text.bodySmall?.copyWith(color: AppColors.inkMuted),
                ),
              ),
            ],
          ),
          if (expired && work.state == 'published')
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxs),
              child: Text(
                work.allowLate
                    ? 'Prazo vencido • Aceita entrega em atraso'
                    : 'Prazo vencido • Envio indisponível',
                style: text.bodySmall?.copyWith(color: AppColors.warning),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              if (work.isWorkDraft) ...[
                TextButton(
                  style: AppButtonStyles.compact(),
                  onPressed: _busy ? null : () => _transition(work),
                  child: const Text('Publicar atividade'),
                ),
                TextButton(
                  style: AppButtonStyles.compact(),
                  onPressed: _busy ? null : () => _edit(work),
                  child: const Text('Editar rascunho'),
                ),
              ],
              if (work.hasSubmissions)
                TextButton(
                  style: AppButtonStyles.compact(),
                  onPressed: _busy
                      ? null
                      : () => setState(() => _activityId = work.id),
                  child: const Text('Ver entregas'),
                ),
              if (work.canCloseWork)
                TextButton(
                  style: AppButtonStyles.compact(foreground: AppColors.danger),
                  onPressed:
                      _busy ? null : () => _transition(work, close: true),
                  child: const Text('Encerrar trabalho'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
