import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/academic_content.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/bottom_nav.dart';
import '../../auth/models/app_user.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/teacher_activity_provider.dart';
import '../providers/teacher_review_provider.dart';
import '../providers/teacher_offering_selection.dart';
import '../services/teacher_activity_service.dart';
import '../widgets/teacher_exam_panel.dart';
import '../widgets/teacher_offering_picker.dart';
import '../widgets/teacher_report_panel.dart';

enum _NotesMode {
  entry('Lançar notas'),
  report('Consultar boletim');

  const _NotesMode(this.title);
  final String title;
}

class TeacherGradesPage extends ConsumerWidget {
  const TeacherGradesPage({super.key, this.openExams = false});

  final bool openExams;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(currentUserProvider)?.role != UserRole.teacher) {
      return const Scaffold(
        appBar: AppHeader(
            title: 'Notas', fallbackRoute: AppRoutes.teacherDashboard),
        body: Center(child: Text('Área exclusiva do professor')),
      );
    }
    return _NotesWorkspace(
        key: ValueKey((ref.watch(teacherNotesSessionProvider), openExams)),
        openExams: openExams);
  }
}

class _NotesWorkspace extends ConsumerStatefulWidget {
  const _NotesWorkspace({super.key, required this.openExams});

  final bool openExams;

  @override
  ConsumerState<_NotesWorkspace> createState() => _NotesWorkspaceState();
}

class _NotesWorkspaceState extends ConsumerState<_NotesWorkspace> {
  late _NotesMode? _mode = widget.openExams ? _NotesMode.entry : null;
  late final TeacherDraftGuard _guard;
  late final bool Function() _exitCallback;

  @override
  void initState() {
    super.initState();
    _guard = ref.read(teacherDraftGuardProvider);
    _exitCallback =
        () => !mounted || ModalRoute.of(context)?.isCurrent != false;
    _guard.canExitNotes = _exitCallback;
  }

  @override
  void dispose() {
    if (identical(_guard.canExitNotes, _exitCallback)) {
      _guard.canExitNotes = null;
    }
    super.dispose();
  }

  void _back() => setState(() => _mode = null);

  @override
  Widget build(BuildContext context) {
    final offers = ref.watch(teacherOfferingsProvider);
    final classId = ref.watch(selectedTeacherClassIdProvider);
    final selected =
        offers.value?.where((offering) => offering.id == classId).firstOrNull;
    ref.listen(teacherOfferingSelectionProvider, (previous, next) {
      if (_mode != null && previous?.classId != next.classId) _back();
    });
    final mode = selected == null && !offers.isLoading ? null : _mode;
    return PopScope(
      canPop: mode == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _mode != null) _back();
      },
      child: Scaffold(
        appBar: mode == null
            ? const AppHeader(
                title: 'Notas',
                fallbackRoute: AppRoutes.teacherDashboard,
                showProfile: true,
              )
            : AppBar(
                title: Text(mode.title),
                leading: IconButton(
                  tooltip: 'Retornar',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _back,
                ),
              ),
        bottomNavigationBar: mode == null
            ? const UniBottomNav(currentIndex: 3, isTeacher: true)
            : null,
        body: SafeArea(
          child: AcademicContent(
            child: ListView(
              key: ValueKey(mode),
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                if (mode == null)
                  const TeacherOfferingPicker()
                else if (offers.isLoading)
                  const _LoadingNotes('Carregando disciplinas...')
                else if (offers.hasError)
                  Text(_academicError(offers.error!)),
                if (mode == null) ...[
                  const SizedBox(height: AppSpacing.md),
                  FilledButton(
                    onPressed: selected == null
                        ? null
                        : () => setState(() => _mode = _NotesMode.entry),
                    child: Text(_NotesMode.entry.title),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton(
                    onPressed: selected == null
                        ? null
                        : () => setState(() => _mode = _NotesMode.report),
                    child: Text(_NotesMode.report.title),
                  ),
                  TextButton.icon(
                    onPressed: () => ref.invalidate(teacherOfferingsProvider),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Atualizar disciplinas'),
                  ),
                ] else if (selected != null) ...[
                  Text(selected.label,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.md),
                  if (mode == _NotesMode.entry)
                    _GradeEntry(
                        key: ValueKey(selected.id), classId: selected.id)
                  else
                    TeacherReportPanel(
                      key: ValueKey(selected.id),
                      classId: selected.id,
                      service: ref.watch(teacherAcademicServiceProvider),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GradeEntry extends ConsumerStatefulWidget {
  const _GradeEntry({super.key, required this.classId});
  final String classId;

  @override
  ConsumerState<_GradeEntry> createState() => _GradeEntryState();
}

class _GradeEntryState extends ConsumerState<_GradeEntry> {
  String? _activityId;

  void _refresh() {
    ref.invalidate(teacherActivitiesProvider(widget.classId));
  }

  String _activityLabel(TeacherActivity activity) {
    final assessment = activity.assessment;
    if (assessment == null) return '${activity.title} • ${activity.stateLabel}';
    final category = assessment.isExam ? 'Prova' : 'Atividade';
    return '${activity.title} — ${assessment.stage} • $category • ${activity.stateLabel}';
  }

  @override
  Widget build(BuildContext context) {
    final activities = ref.watch(teacherActivitiesProvider(widget.classId));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Provas N1/N2'),
      TextButton.icon(
        onPressed: _refresh,
        icon: const Icon(Icons.refresh),
        label: const Text('Atualizar avaliações'),
      ),
      activities.when(
        skipLoadingOnRefresh: false,
        skipLoadingOnReload: false,
        loading: () => const _LoadingNotes('Carregando avaliações...'),
        error: (error, _) => Text(_academicError(error)),
        data: (activities) {
          final rows = activities.where((activity) => activity.isExam).toList();
          if (rows.isEmpty) {
            return const Text('Nenhuma prova nesta disciplina.');
          }
          final selected =
              rows.where((activity) => activity.id == _activityId).firstOrNull;
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  key: ValueKey(selected?.id),
                  initialValue: selected?.id,
                  isExpanded: true,
                  itemHeight: null,
                  decoration: const InputDecoration(labelText: 'Avaliação'),
                  items: [
                    for (final activity in rows)
                      DropdownMenuItem(
                        value: activity.id,
                        child: Text(_activityLabel(activity),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (id) => setState(() => _activityId = id),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (selected == null)
                  const Text('Selecione uma avaliação para consultar as notas.')
                else
                  TeacherExamPanel(
                    key: ValueKey(selected.id),
                    examId: selected.id,
                    service: ref.watch(teacherAcademicServiceProvider),
                  )
              ]);
        },
      ),
    ]);
  }
}

String _academicError(Object error) {
  if (error is ApiException && [403, 404].contains(error.statusCode)) {
    return 'Acesso negado. Confira seu vínculo com a disciplina.';
  }
  return teacherReviewError(error);
}

class _LoadingNotes extends StatelessWidget {
  const _LoadingNotes(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Column(children: [
        const LinearProgressIndicator(),
        Text(label),
      ]);
}
