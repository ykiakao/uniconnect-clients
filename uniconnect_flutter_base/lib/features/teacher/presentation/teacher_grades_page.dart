import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/academic_content.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_header.dart';
import '../../auth/models/app_user.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/teacher_activity_provider.dart';
import '../providers/teacher_review_provider.dart';
import '../services/teacher_activity_service.dart';
import '../widgets/teacher_review_editor.dart';

class TeacherGradesPage extends ConsumerWidget {
  const TeacherGradesPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return Scaffold(
        appBar: const AppHeader(
            title: 'Lançamento de notas',
            fallbackRoute: AppRoutes.teacherDashboard),
        body: SafeArea(
            child: AcademicContent(
                child: user?.role != UserRole.teacher
                    ? const Center(child: Text('Área exclusiva do professor'))
                    : _ReviewWorkspace(
                        key: ValueKey((
                        user!.id,
                        user.tenant.slug,
                        ref.watch(
                            authControllerProvider.select((s) => s.accessToken))
                      ))))));
  }
}

class _ReviewWorkspace extends ConsumerStatefulWidget {
  const _ReviewWorkspace({super.key});
  @override
  ConsumerState<_ReviewWorkspace> createState() => _ReviewWorkspaceState();
}

class _ReviewWorkspaceState extends ConsumerState<_ReviewWorkspace> {
  String? _classId, _activityId;
  void _refresh() {
    ref.invalidate(teacherOfferingsProvider);
    if (_classId != null) ref.invalidate(teacherActivitiesProvider(_classId!));
    if (_classId != null && _activityId != null) {
      ref.invalidate(teacherSubmissionsProvider(
          (classId: _classId!, activityId: _activityId!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final offers = ref.watch(teacherOfferingsProvider);
    final rows = offers.asData?.value ?? const <TeacherOffering>[];
    final selectedClass = rows.any((r) => r.id == _classId) ? _classId : null;
    final activities = selectedClass == null
        ? null
        : ref.watch(teacherActivitiesProvider(selectedClass));
    final activityRows = activities?.asData?.value ?? const <TeacherActivity>[];
    final selectedActivity =
        activityRows.any((a) => a.id == _activityId) ? _activityId : null;
    return ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
      Text('Avaliar entregas',
          style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: AppSpacing.sm),
      const Text(
          'Selecione uma oferta e uma atividade. Salvar a correção não publica o resultado.'),
      TextButton.icon(
          onPressed: _refresh,
          icon: const Icon(Icons.refresh),
          label: const Text('Atualizar ofertas e entregas')),
      offers.when(
          skipLoadingOnRefresh: false,
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text(teacherReviewError(e)),
          data: (data) => data.isEmpty
              ? const Text('Nenhuma oferta ativa autorizada.')
              : const SizedBox.shrink()),
      const Text('Oferta acadêmica'),
      DropdownButtonFormField<String>(
          key: ValueKey(selectedClass),
          initialValue: selectedClass,
          isExpanded: true,
          items: rows
              .map((r) => DropdownMenuItem(
                  value: r.id,
                  child: Text('${r.name} • ${r.id}',
                      maxLines: 2, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: offers.isLoading || offers.hasError
              ? null
              : (id) => setState(() {
                    _classId = id;
                    _activityId = null;
                  })),
      const SizedBox(height: AppSpacing.md),
      if (activities != null)
        activities.when(
            skipLoadingOnRefresh: false,
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text(teacherReviewError(e)),
            data: (data) => data.isEmpty
                ? const Text('Nenhuma atividade nesta oferta.')
                : const SizedBox.shrink()),
      const Text('Atividade'),
      DropdownButtonFormField<String>(
          key: ValueKey((selectedClass, selectedActivity)),
          initialValue: selectedActivity,
          isExpanded: true,
          items: activityRows
              .map((a) => DropdownMenuItem(
                  value: a.id,
                  child: Text('${a.title} • ${a.stateLabel}',
                      maxLines: 2, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: activities == null ||
                  activities.isLoading ||
                  activities.hasError ||
                  offers.isLoading ||
                  offers.hasError
              ? null
              : (id) => setState(() => _activityId = id)),
      const SizedBox(height: AppSpacing.lg),
      if (selectedClass == null || selectedActivity == null)
        const Text(
            'Selecione uma atividade autorizada para consultar as entregas.')
      else
        ref
            .watch(teacherSubmissionsProvider(
                (classId: selectedClass, activityId: selectedActivity)))
            .when(
                skipLoadingOnRefresh: false,
                loading: () => const Column(children: [
                      LinearProgressIndicator(),
                      Text('Carregando entregas...')
                    ]),
                error: (e, _) => Text(
                    'Erro ao consultar entregas. ${teacherReviewError(e)}'),
                data: (submissions) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (submissions.isEmpty)
                            const Text('Nenhuma entrega nesta atividade.'),
                          for (final submission in submissions)
                            AppCard(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text('Aluno: ${submission.studentId}'),
                                  Text('Entrega: ${submission.id}'),
                                  Text(
                                      'Versão da resposta: ${submission.version} • ${submission.status}'),
                                  Text(submission.result == null
                                      ? 'Sem avaliação'
                                      : submission.result!.publicationState ==
                                              'published'
                                          ? 'Avaliação publicada'
                                          : 'Avaliação salva — não publicada'),
                                  TextButton.icon(
                                      icon: const Icon(Icons.grading_outlined),
                                      label: const Text('Abrir entrega'),
                                      onPressed: offers.hasError ||
                                              offers.isLoading ||
                                              activities!.hasError ||
                                              activities.isLoading
                                          ? null
                                          : () async {
                                              await Navigator.of(context)
                                                  .push<void>(MaterialPageRoute(
                                                      builder: (_) =>
                                                          TeacherReviewPage(
                                                              submission:
                                                                  submission)));
                                              if (mounted) {
                                                ref.invalidate(
                                                    teacherSubmissionsProvider((
                                                  classId: selectedClass,
                                                  activityId: selectedActivity
                                                )));
                                              }
                                            }),
                                ])),
                        ])),
    ]);
  }
}
