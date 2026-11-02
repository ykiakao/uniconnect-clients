import 'package:flutter/material.dart';
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
import '../services/teacher_activity_service.dart';

class CreateActivityPage extends ConsumerWidget {
  const CreateActivityPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final token =
        ref.watch(authControllerProvider.select((s) => s.accessToken));
    return Scaffold(
      appBar: const AppHeader(
          title: 'Atividades acadêmicas',
          fallbackRoute: AppRoutes.teacherDashboard),
      body: SafeArea(
          child: AcademicContent(
              child: user?.role != UserRole.teacher
                  ? const Center(child: Text('Área exclusiva do professor'))
                  : _Workspace(
                      key: ValueKey((user!.id, user.tenant.slug, token))))),
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
  String? _classId;
  String _priority = 'medium';
  DateTime? _due;
  bool _allowLate = false;
  bool _busy = false;
  bool _mustRefresh = false;
  String? _message;
  String? _error;

  @override
  void dispose() {
    _scroll.dispose();
    for (final c in [_title, _description, _type, _instructions, _criteria]) {
      c.dispose();
    }
    super.dispose();
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
      final offerings = await ref.read(teacherOfferingsProvider.future);
      if (!mounted) return;
      if (_classId != null && !offerings.any((o) => o.id == _classId)) {
        setState(() {
          _classId = null;
          _mustRefresh = false;
        });
      } else if (_classId != null) {
        ref.invalidate(teacherActivitiesProvider(_classId!));
        await ref.read(teacherActivitiesProvider(_classId!).future);
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
    if (id == null) return;
    await _mutate(
        () => ref.read(teacherActivityServiceProvider).create(id,
            title: _title.text,
            description: _description.text,
            type: _type.text,
            instructions: _instructions.text,
            evaluationCriteria: _criteria.text,
            dueDate: _due,
            priority: _priority,
            allowLate: _allowLate),
        creating: true);
  }

  Future<void> _mutate(Future<TeacherActivity> Function() action,
      {bool creating = false}) async {
    if (_busy || _mustRefresh) return;
    setState(() {
      _busy = true;
      _message = null;
      _error = null;
    });
    try {
      final result = await action();
      if (!mounted) return;
      if (creating) {
        _title.clear();
        _description.clear();
        _instructions.clear();
        _criteria.clear();
        _type.text = 'assignment';
        _form.currentState?.reset();
      }
      setState(() {
        _message = creating
            ? 'Rascunho salvo pela API. Publique na lista quando estiver pronto.'
            : 'Publicação confirmada pela API.';
        if (creating) {
          _due = null;
          _allowLate = false;
          _priority = 'medium';
        }
      });
      ref.invalidate(teacherActivitiesProvider(result.classId));
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
        _mustRefresh = true;
      });
      if (_classId != null) {
        ref.invalidate(teacherActivitiesProvider(_classId!));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        if (_scroll.hasClients) _scroll.jumpTo(0);
      }
    }
  }

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
    final rows = offerings.asData?.value ?? const <TeacherOffering>[];
    final selected = rows.any((o) => o.id == _classId) ? _classId : null;
    return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.lg),
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
                  icon: const Icon(Icons.refresh),
                  label: const Text('Atualizar ofertas e atividades')),
              offerings.when(
                  skipLoadingOnRefresh: false,
                  loading: () =>
                      const Text('Carregando ofertas autorizadas...'),
                  error: (e, _) => Text(_errorText(e)),
                  data: (data) => data.isEmpty
                      ? const Text(
                          'Nenhuma oferta ativa autorizada. Solicite o vínculo à instituição.')
                      : const SizedBox.shrink()),
              AppCard(
                  child: Form(
                      key: _form,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('Oferta acadêmica',
                                style: Theme.of(context).textTheme.labelLarge),
                            const SizedBox(height: AppSpacing.xs),
                            DropdownButtonFormField<String>(
                                key: ValueKey(selected),
                                initialValue: selected,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                    hintText: 'Selecione'),
                                items: rows
                                    .map((o) => DropdownMenuItem(
                                        value: o.id,
                                        child: Text('${o.name} • ${o.id}',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis)))
                                    .toList(),
                                onChanged: _busy ||
                                        offerings.isLoading ||
                                        offerings.hasError
                                    ? null
                                    : (id) {
                                        if (id == _classId) return;
                                        setState(() {
                                          _classId = id;
                                          _error = null;
                                          _message = null;
                                          _mustRefresh = false;
                                        });
                                      },
                                validator: (_) => selected == null
                                    ? 'Selecione uma oferta autorizada'
                                    : null),
                            const SizedBox(height: AppSpacing.md),
                            _field('Título da atividade', _title,
                                required: true),
                            _field('Tipo', _type, required: true),
                            _field('Descrição (opcional)', _description,
                                lines: 3),
                            _field('Instruções (opcional)', _instructions,
                                lines: 3),
                            _field(
                                'Critérios de avaliação (opcional)', _criteria,
                                lines: 3),
                            OutlinedButton.icon(
                                onPressed: _busy ? null : _pickDate,
                                icon: const Icon(Icons.event),
                                label: Text(_due == null
                                    ? 'Definir prazo (opcional)'
                                    : 'Prazo local: ${_due!.toLocal()}')),
                            if (_due != null)
                              TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => setState(() => _due = null),
                                  child: const Text('Remover prazo')),
                            DropdownButtonFormField<String>(
                                key: ValueKey(_priority),
                                initialValue: _priority,
                                decoration: const InputDecoration(
                                    labelText: 'Prioridade'),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'low', child: Text('Baixa')),
                                  DropdownMenuItem(
                                      value: 'medium', child: Text('Média')),
                                  DropdownMenuItem(
                                      value: 'high', child: Text('Alta'))
                                ],
                                onChanged: _busy
                                    ? null
                                    : (v) => setState(() => _priority = v!)),
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
                                        offerings.isLoading ||
                                        offerings.hasError
                                    ? null
                                    : _save,
                                icon: const Icon(Icons.save_outlined),
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
                                      if (activity.state == 'draft' &&
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
                                            icon: const Icon(
                                                Icons.publish_outlined),
                                            label: const Text(
                                                'Publicar atividade')),
                                    ])),
                            ])),
            ]));
  }
}
