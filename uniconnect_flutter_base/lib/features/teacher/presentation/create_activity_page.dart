import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/academic_content.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_header.dart';
import '../../auth/models/app_user.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/teacher_activity_provider.dart';
import '../providers/teacher_offering_selection.dart';
import '../services/teacher_activity_service.dart';
import '../services/teacher_assessment.dart';
import '../widgets/activity_type_field.dart';
import '../widgets/assessment_fields.dart';
import '../widgets/teacher_offering_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../shared/widgets/app_button_styles.dart';

class CreateActivityPage extends ConsumerWidget {
  const CreateActivityPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final session = ref.watch(teacherNotesSessionProvider);
    return Scaffold(
      appBar: const AppHeader(
          title: 'Atividades acadêmicas',
          fallbackRoute: AppRoutes.teacherDashboard),
      body: SafeArea(
          child: AcademicContent(
              child: user?.role != UserRole.teacher
                  ? const Center(child: Text('Área exclusiva do professor'))
                  : _Workspace(key: ValueKey(session)))),
    );
  }
}

class _Workspace extends ConsumerStatefulWidget {
  const _Workspace({super.key});
  @override
  ConsumerState<_Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends ConsumerState<_Workspace> {
  final _scroll = ScrollController();
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _type = TextEditingController(text: 'assignment');
  final _instructions = TextEditingController();
  final _criteria = TextEditingController();
  late final TeacherDraftGuard _guard;
  late final Future<bool> Function() _exitCallback;
  Future<bool>? _confirmation;
  String? _draftClassId;

  String? get _classId => ref.read(selectedTeacherClassIdProvider);

  bool get _hasDraft =>
      [_title, _description, _instructions, _criteria]
          .any((field) => field.text.isNotEmpty) ||
      _type.text != 'assignment' ||
      _due != null ||
      _allowLate ||
      _assessment != null;
  DateTime? _due;
  bool _allowLate = false;
  TeacherAssessment? _assessment;
  int _assessmentFormVersion = 0;
  bool _busy = false;
  bool _mustRefresh = false;
  String? _message;
  String? _error;

  @override
  void initState() {
    super.initState();
    _guard = ref.read(teacherDraftGuardProvider);
    _exitCallback = _confirmChange;
    _guard.confirmExit = _exitCallback;
  }

  @override
  void dispose() {
    if (identical(_guard.confirmExit, _exitCallback)) {
      _guard.confirmExit = null;
    }
    _scroll.dispose();
    for (final c in [_title, _description, _type, _instructions, _criteria]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<bool> _confirmChange() {
    if (!mounted || !identical(ref.read(teacherDraftGuardProvider), _guard)) {
      return Future.value(true);
    }
    if (_confirmation != null) return _confirmation!;
    if (ModalRoute.isCurrentOf(context) == false) {
      return Future.value(false);
    }
    if (_busy) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Aguarde a operação em andamento.')),
      );
      return Future.value(false);
    }
    return _confirmation ??=
        _confirmDiscard().whenComplete(() => _confirmation = null);
  }

  Future<bool> _confirmDiscard() async {
    if (_hasDraft) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Descartar alterações não salvas?'),
          content: const Text('A edição pertence à oferta atual.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Descartar alterações'),
            ),
          ],
        ),
      );
      if (!mounted || discard != true) return false;
      _clearDraft();
    }
    setState(() {
      _message = null;
      _error = null;
      _mustRefresh = false;
    });
    return true;
  }

  void _clearDraft() {
    for (final field in [_title, _description, _instructions, _criteria]) {
      field.clear();
    }
    _type.text = 'assignment';
    _form.currentState?.reset();
    _due = null;
    _allowLate = false;
    _assessment = null;
    _assessmentFormVersion++;
  }

  String? _validate(String? value, {bool required = false}) {
    if (required && (value == null || value.trim().isEmpty)) {
      return 'Campo obrigatório';
    }
    if ((value?.trim().length ?? 0) > 102400) {
      return 'Limite de 102400 caracteres';
    }
    return null;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
        context: context,
        initialDate: _due ?? now,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100));
    if (date == null || !mounted) return;
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(_due ?? now));
    if (time == null || !mounted) return;
    setState(() => _due =
        DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _refresh() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      ref.invalidate(teacherOfferingsProvider);
      await ref.read(teacherOfferingsProvider.future);
      if (!mounted) return;
      final classId = _classId;
      if (classId != null) {
        ref.invalidate(teacherActivitiesProvider(classId));
        await ref.read(teacherActivitiesProvider(classId).future);
      }
      if (mounted) setState(() => _mustRefresh = false);
    } catch (e) {
      if (mounted) setState(() => _error = _errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _errorText(Object e) {
    if (e is ApiException) {
      if (e.statusCode == 409) {
        return 'Conflito de versão ou estado. Atualize a lista e confira a atividade antes de tentar novamente. ${e.message}';
      }
      if (e.statusCode == 401) return 'Sessão expirada. Entre novamente.';
      if (e.statusCode == 403 || e.statusCode == 404) {
        return 'Permissão ou vínculo indisponível. Atualize as ofertas. ${e.message}';
      }
      return e.message;
    }
    return 'Não foi possível concluir a operação. Atualize a lista antes de tentar novamente.';
  }

  Future<void> _save() async {
    if (_busy || _mustRefresh || !_form.currentState!.validate()) return;
    final id = _classId;
    if (id == null || id != _draftClassId) return;
    FocusScope.of(context).unfocus();
    await _mutate(
        () => ref.read(teacherActivityServiceProvider).create(id,
            title: _title.text,
            description: _description.text,
            type: _type.text,
            instructions: _instructions.text,
            evaluationCriteria: _criteria.text,
            dueDate: _due,
            allowLate: _allowLate,
            assessment: _assessment),
        creating: true,
        academicPlan: _assessment != null);
  }

  Future<void> _editAssessment(TeacherActivity activity) async {
    if (_busy || _mustRefresh) return;
    final form = GlobalKey<FormState>();
    var assessment = activity.assessment;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar dados da avaliação'),
        content: SingleChildScrollView(
            child: Form(
          key: form,
          child: AssessmentFields(
            initial: assessment,
            enabled: true,
            onChanged: (value) => assessment = value,
          ),
        )),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(context, true);
            },
            child: const Text('Salvar alteração'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true || _classId != activity.classId) return;
    await _mutate(
      () => ref
          .read(teacherActivityServiceProvider)
          .updateAssessment(activity, assessment),
      success: 'Dados da avaliação atualizados pela API.',
      academicPlan: true,
    );
  }

  Future<void> _mutate(Future<TeacherActivity> Function() action,
      {bool creating = false,
      String? success,
      bool academicPlan = false}) async {
    if (_busy || _mustRefresh) return;
    setState(() {
      _busy = true;
      _message = null;
      _error = null;
    });
    try {
      final result = await action();
      if (!mounted) return;
      if (creating) _clearDraft();
      setState(() {
        _message = success ??
            (creating
                ? result.isExam
                    ? 'Rascunho salvo pela API. Abra a pauta na tela de notas.'
                    : 'Rascunho salvo pela API. Publique na lista quando estiver pronto.'
                : 'Publicação confirmada pela API.');
      });
      ref.invalidate(teacherActivitiesProvider(result.classId));
      ref.invalidate(teacherActivityPreviewProvider(result.classId));
      try {
        await ref.read(teacherActivitiesProvider(result.classId).future);
      } catch (_) {
        if (mounted) {
          setState(() {
            _error =
                'Operação confirmada, mas a lista não pôde ser atualizada.';
            _mustRefresh = true;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error =
            '${_errorText(e)} Confira a lista antes de repetir a operação.';
        if (academicPlan && e is ApiException && e.statusCode == 409) {
          _error = '$_error Confira a etapa e a distribuição da oferta: até '
              '7,00 pontos de provas e 3,00 de atividades por etapa.';
        }
        _mustRefresh = true;
      });
      final classId = _classId;
      if (classId != null) {
        ref.invalidate(teacherActivitiesProvider(classId));
      }
      if (e is ApiException && e.statusCode == 403) {
        ref.invalidate(teacherOfferingsProvider);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        if (_scroll.hasClients) _scroll.jumpTo(0);
      }
    }
  }

  Widget _formSection(IconData icon, String title) => Padding(
        padding:
            const EdgeInsets.only(top: AppSpacing.xs, bottom: AppSpacing.sm),
        child: Row(
          children: [
            IconTile(icon: icon, size: 32),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleSmall),
            ),
          ],
        ),
      );

  Widget _field(String label, TextEditingController controller,
      {bool required = false, int lines = 1}) {
    return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          Semantics(
              label: label,
              child: TextFormField(
                  controller: controller,
                  enabled: !_busy,
                  minLines: lines,
                  maxLines: lines == 1 ? 1 : lines + 2,
                  validator: (v) => _validate(v, required: required))),
        ]));
  }

  @override
  Widget build(BuildContext context) {
    final offerings = ref.watch(teacherOfferingsProvider);
    final selected = ref.watch(selectedTeacherClassIdProvider);
    if (!_hasDraft) _draftClassId = selected;
    return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
            children: [
              Text('Criar atividade',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                  'Salve um rascunho e publique para os alunos da oferta selecionada.'),
              const SizedBox(height: AppSpacing.md),
              if (_busy) const LinearProgressIndicator(),
              if (_message != null) Text(_message!, semanticsLabel: _message),
              if (_error != null)
                Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              TextButton.icon(
                  onPressed: _busy ? null : _refresh,
                  icon: const Icon(LucideIcons.refreshCw),
                  label: const Text('Atualizar ofertas e atividades')),
              AppCard(
                  child: Form(
                      key: _form,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TeacherOfferingPicker(
                              enabled: !_busy,
                              confirmChange: _confirmChange,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            _formSection(
                                LucideIcons.fileText, 'Dados da atividade'),
                            _field('Título da atividade', _title,
                                required: true),
                            Padding(
                              padding:
                                  const EdgeInsets.only(bottom: AppSpacing.md),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text('Tipo',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge),
                                  const SizedBox(height: AppSpacing.xs),
                                  ActivityTypeField(
                                    controller: _type,
                                    enabled: !_busy,
                                  ),
                                ],
                              ),
                            ),
                            _formSection(LucideIcons.listChecks,
                                'Orientações para os alunos'),
                            _field('Descrição (opcional)', _description,
                                lines: 3),
                            _field('Instruções (opcional)', _instructions,
                                lines: 3),
                            _field(
                                'Critérios de avaliação (opcional)', _criteria,
                                lines: 3),
                            _formSection(
                                LucideIcons.calendarClock, 'Avaliação e prazo'),
                            AssessmentFields(
                              key: ValueKey(_assessmentFormVersion),
                              enabled: !_busy,
                              onChanged: (value) => _assessment = value,
                            ),
                            OutlinedButton.icon(
                                onPressed: _busy ? null : _pickDate,
                                icon: const Icon(LucideIcons.calendar),
                                label: Text(_due == null
                                    ? 'Definir prazo (opcional)'
                                    : 'Prazo local: ${DateFormat('dd/MM/yyyy HH:mm').format(_due!.toLocal())}')),
                            if (_due != null)
                              TextButton(
                                  style: AppButtonStyles.link,
                                  onPressed: _busy
                                      ? null
                                      : () => setState(() => _due = null),
                                  child: const Text('Remover prazo')),
                            SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title:
                                    const Text('Permitir entrega após o prazo'),
                                value: _allowLate,
                                onChanged: _busy
                                    ? null
                                    : (v) => setState(() => _allowLate = v)),
                            ElevatedButton.icon(
                                onPressed: _busy ||
                                        _mustRefresh ||
                                        selected == null ||
                                        selected != _draftClassId ||
                                        offerings.isLoading ||
                                        offerings.hasError
                                    ? null
                                    : _save,
                                icon: const Icon(LucideIcons.save),
                                label: Text(
                                    _busy ? 'Aguarde...' : 'Salvar rascunho')),
                          ]))),
              const SizedBox(height: AppSpacing.lg),
              Text('Atividades da oferta',
                  style: Theme.of(context).textTheme.titleLarge),
              if (selected == null)
                const Text('Selecione uma oferta para consultar as atividades.')
              else
                ref.watch(teacherActivitiesProvider(selected)).when(
                    skipLoadingOnRefresh: false,
                    loading: () => const Padding(
                        padding: EdgeInsets.all(16),
                        child: LinearProgressIndicator()),
                    error: (e, _) => Text(
                        'Não foi possível carregar as atividades. ${_errorText(e)}'),
                    data: (activities) => Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (activities.isEmpty)
                                const Text('Nenhuma atividade nesta oferta.'),
                              for (final activity in activities)
                                AppCard(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(activity.title,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium),
                                      Text(
                                          '${activity.stateLabel} • Versão ${activity.revision}'),
                                      if (activity.assessment != null)
                                        Text(activity.assessment!.label),
                                      if (activity.canEditAssessment)
                                        TextButton(
                                          onPressed: _busy ||
                                                  _mustRefresh ||
                                                  offerings.isLoading ||
                                                  offerings.hasError
                                              ? null
                                              : () => _editAssessment(activity),
                                          child: const Text(
                                              'Editar dados da avaliação'),
                                        ),
                                      if (!activity.isExam &&
                                          activity.state == 'draft' &&
                                          activity.workflowEnabled)
                                        ElevatedButton.icon(
                                            onPressed: _busy ||
                                                    _mustRefresh ||
                                                    offerings.isLoading ||
                                                    offerings.hasError
                                                ? null
                                                : () => _mutate(() => ref
                                                    .read(
                                                        teacherActivityServiceProvider)
                                                    .publish(activity)),
                                            icon:
                                                const Icon(LucideIcons.upload),
                                            label: const Text(
                                                'Publicar atividade')),
                                    ])),
                            ])),
            ]));
  }
}
