import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_spacing.dart';
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
      setState(() => _notice = close
          ? 'Encerramento confirmado pela API.'
          : 'Publicação confirmada pela API.');
      _reload(work.classId);
    } catch (error) {
      if (!mounted || ref.read(teacherNotesSessionProvider) != session) return;
      setState(() => _notice = teacherReviewError(error));
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
    setState(() => _notice = 'Edição do rascunho confirmada pela API.');
    _reload(work.classId);
  }

  @override
  Widget build(BuildContext context) {
    final classId = widget.classId;
    final workList =
        classId == null ? null : ref.watch(teacherActivitiesProvider(classId));
    final activityId = _activityId;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (activityId == null)
          TeacherOfferingPicker(enabled: !_busy)
        else
          TextButton(
            onPressed: () => setState(() => _activityId = null),
            child: const Text('Voltar aos trabalhos'),
          ),
        if (activityId == null)
          FilledButton(
            onPressed: classId == null || _busy
                ? null
                : () => GoRouter.maybeOf(context)
                    ?.push(AppRoutes.teacherCreateActivity),
            child: const Text('Criar atividade'),
          ),
        if (_notice != null && classId != null)
          Semantics(liveRegion: true, child: Text(_notice!)),
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
  }

  Widget _card(TeacherActivity work) {
    final deadline = work.dueDate?.toLocal();
    final expired = deadline?.isBefore(DateTime.now()) == true;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(work.title, style: Theme.of(context).textTheme.titleMedium),
          Text(work.stateLabel),
          if (work.assessment case final assessment?) Text(assessment.label),
          if (deadline != null)
            Text('Prazo: ${DateFormat('dd/MM/yyyy HH:mm').format(deadline)}')
          else
            const Text('Sem prazo informado'),
          if (expired && work.state == 'published')
            Text(work.allowLate
                ? 'Prazo vencido • Aceita entrega em atraso'
                : 'Prazo vencido • Envio indisponível'),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              if (work.isWorkDraft) ...[
                TextButton(
                  onPressed: _busy ? null : () => _edit(work),
                  child: const Text('Editar rascunho'),
                ),
                TextButton(
                  onPressed: _busy ? null : () => _transition(work),
                  child: const Text('Publicar atividade'),
                ),
              ],
              if (work.hasSubmissions)
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() => _activityId = work.id),
                  child: const Text('Ver entregas'),
                ),
              if (work.canCloseWork)
                TextButton(
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
