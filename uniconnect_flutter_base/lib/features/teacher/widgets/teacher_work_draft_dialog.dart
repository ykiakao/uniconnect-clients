import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_spacing.dart';
import '../providers/teacher_activity_provider.dart';
import '../providers/teacher_offering_selection.dart';
import '../providers/teacher_review_provider.dart';
import '../services/teacher_activity_service.dart';
import '../../../shared/widgets/app_button_styles.dart';

class TeacherWorkDraftDialog extends ConsumerStatefulWidget {
  const TeacherWorkDraftDialog({super.key, required this.work});

  final TeacherActivity work;

  @override
  ConsumerState<TeacherWorkDraftDialog> createState() =>
      _TeacherWorkDraftDialogState();
}

class _TeacherWorkDraftDialogState
    extends ConsumerState<TeacherWorkDraftDialog> {
  final _form = GlobalKey<FormState>();
  late final Object _session;
  late final TeacherDraftGuard _guard;
  late final _fields = {
    'Título da atividade': TextEditingController(text: widget.work.title),
    'Tipo': TextEditingController(text: widget.work.type),
    'Descrição': TextEditingController(text: widget.work.description),
    'Instruções': TextEditingController(text: widget.work.instructions),
    'Critérios de avaliação':
        TextEditingController(text: widget.work.evaluationCriteria),
  };
  late final Future<bool> Function() _exitCallback;
  Future<bool>? _confirmation;
  DateTime? _newDeadline;
  late bool _allowLate = widget.work.allowLate;
  bool _busy = false, _dirty = false, _blocked = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _session = ref.read(teacherNotesSessionProvider);
    _guard = ref.read(teacherDraftGuardProvider);
    _exitCallback = _confirmExit;
    _guard.confirmWorkExit = _exitCallback;
  }

  @override
  void dispose() {
    if (identical(_guard.confirmWorkExit, _exitCallback)) {
      _guard.confirmWorkExit = null;
    }
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  bool get _current =>
      ref.read(teacherNotesSessionProvider) == _session &&
      ref.read(selectedTeacherClassIdProvider) == widget.work.classId;

  Future<bool> _confirmExit() {
    if (_busy) return Future.value(false);
    if (!_dirty) return Future.value(true);
    return _confirmation ??=
        _askDiscard().whenComplete(() => _confirmation = null);
  }

  Future<bool> _askDiscard() async {
    final discard = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Descartar alterações do rascunho?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Continuar editando'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Descartar alterações'),
              ),
            ],
          ),
        ) ==
        true;
    if (!mounted || !discard) return false;
    setState(() {
      _dirty = false;
      _fields['Título da atividade']!.text = widget.work.title;
      _fields['Tipo']!.text = widget.work.type;
      _fields['Descrição']!.text = widget.work.description;
      _fields['Instruções']!.text = widget.work.instructions;
      _fields['Critérios de avaliação']!.text = widget.work.evaluationCriteria;
      _newDeadline = null;
      _allowLate = widget.work.allowLate;
    });
    return true;
  }

  Future<void> _cancel() async {
    if (await _confirmExit() && mounted) Navigator.pop(context);
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final initial = (_newDeadline ?? widget.work.dueDate ?? now).toLocal();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
    );
    if (date == null || !mounted || !_current) return;
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (time == null || !mounted || !_current) return;
    setState(() {
      _newDeadline =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
      _dirty = true;
    });
  }

  Future<void> _save() async {
    if (_busy || _blocked || !_current || !_form.currentState!.validate()) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final work = widget.work;
    try {
      await ref.read(teacherActivityServiceProvider).updateWorkDraft(
            work,
            title: _fields['Título da atividade']!.text,
            type: _fields['Tipo']!.text,
            description: _fields['Descrição']!.text,
            instructions: _fields['Instruções']!.text,
            evaluationCriteria: _fields['Critérios de avaliação']!.text,
            allowLate: _allowLate,
            dueDate: _newDeadline,
          );
      if (mounted && _current) Navigator.pop(context, true);
    } catch (error) {
      if (mounted && _current) {
        setState(() {
          _blocked = error is ApiException &&
              [401, 403, 404, 409].contains(error.statusCode);
          _error = _blocked
              ? '${teacherReviewError(error)} Volte à lista e abra a versão atual.'
              : teacherReviewError(error);
        });
        if (_blocked) ref.invalidate(teacherActivitiesProvider(work.classId));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sameSession = ref.watch(teacherNotesSessionProvider) == _session;
    final authorized =
        ref.watch(selectedTeacherClassIdProvider) == widget.work.classId;
    final offers = ref.watch(teacherOfferingsProvider);
    final showDraft = sameSession && authorized;
    final canEdit = showDraft && !_busy && !_blocked;
    final deadline = _newDeadline ?? widget.work.dueDate;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: AlertDialog(
        title: const Text('Editar rascunho'),
        scrollable: true,
        content: showDraft
            ? Form(
                key: _form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_busy) const LinearProgressIndicator(),
                    if (_error != null)
                      Semantics(liveRegion: true, child: Text(_error!)),
                    for (final entry in _fields.entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: TextFormField(
                          controller: entry.value,
                          decoration: InputDecoration(labelText: entry.key),
                          enabled: canEdit,
                          maxLines: entry.key == 'Título da atividade' ||
                                  entry.key == 'Tipo'
                              ? 1
                              : 3,
                          onChanged: (_) => _dirty = true,
                          validator: (value) {
                            final length = value?.trim().length ?? 0;
                            if (length == 0 &&
                                (entry.key == 'Título da atividade' ||
                                    entry.key == 'Tipo')) {
                              return 'Campo obrigatório';
                            }
                            return length > 102400
                                ? 'Limite de 102400 caracteres'
                                : null;
                          },
                        ),
                      ),
                    Text(deadline == null
                        ? 'Sem prazo informado'
                        : 'Prazo: ${DateFormat('dd/MM/yyyy HH:mm').format(deadline.toLocal())}'),
                    TextButton(
                      style: AppButtonStyles.link,
                      onPressed: canEdit ? _pickDeadline : null,
                      child: const Text('Definir ou alterar prazo'),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Permitir entrega após o prazo'),
                      value: _allowLate,
                      onChanged: canEdit
                          ? (value) => setState(() {
                                _allowLate = value;
                                _dirty = true;
                              })
                          : null,
                    ),
                  ],
                ),
              )
            : Text(offers.isLoading && sameSession
                ? 'Validando oferta...'
                : 'A oferta não está disponível nesta sessão.'),
        actions: [
          TextButton(
              onPressed: _busy ? null : _cancel, child: const Text('Cancelar')),
          FilledButton(
              onPressed: canEdit ? _save : null,
              child: const Text('Salvar alterações')),
        ],
      ),
    );
  }
}
