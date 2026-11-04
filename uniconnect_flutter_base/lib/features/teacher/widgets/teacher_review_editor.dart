import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/academic_content.dart';
import '../../../shared/widgets/app_card.dart';
import '../../auth/models/app_user.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/teacher_review_provider.dart';
import '../providers/teacher_activity_provider.dart';
import '../providers/teacher_offering_selection.dart';
import '../services/teacher_review_service.dart';
import '../services/grade_precision.dart';

class TeacherReviewPage extends ConsumerWidget {
  const TeacherReviewPage({super.key, required this.submission});
  final TeacherSubmission submission;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final allowed =
        auth.user?.role == UserRole.teacher && auth.accessToken != null;
    return Scaffold(
        appBar: AppBar(
          title: const Text('Avaliar entrega'),
          leading: IconButton(
            tooltip: 'Retornar',
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final confirm =
                  ref.read(teacherDraftGuardProvider).confirmReviewExit;
              if ((confirm == null || await confirm()) && context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
        ),
        body: SafeArea(
            child: AcademicContent(
                child: !allowed
                    ? const Center(
                        child: Text(
                            'Sessão de professor inválida. Entre novamente.'))
                    : _ReviewEditor(
                        key: ValueKey((
                          ref.watch(teacherNotesSessionProvider),
                          submission.id
                        )),
                        submission: submission))));
  }
}

class _ReviewEditor extends ConsumerStatefulWidget {
  const _ReviewEditor({super.key, required this.submission});
  final TeacherSubmission submission;
  @override
  ConsumerState<_ReviewEditor> createState() => _ReviewEditorState();
}

class _ReviewEditorState extends ConsumerState<_ReviewEditor> {
  final _scroll = ScrollController();
  final _form = GlobalKey<FormState>();
  final _grade = TextEditingController();
  final _feedback = TextEditingController();
  late TeacherSubmission _current;
  bool _ready = false,
      _busy = false,
      _dirty = false,
      _mustRefresh = false,
      _denied = false;
  String? _error, _message;
  late final TeacherDraftGuard _guard;
  late final Future<bool> Function() _exitCallback;
  Future<bool>? _confirmation;
  @override
  void initState() {
    super.initState();
    _current = widget.submission;
    _guard = ref.read(teacherDraftGuardProvider);
    _exitCallback = _confirmExit;
    _guard.confirmReviewExit = _exitCallback;
    Future.microtask(_refresh);
  }

  @override
  void dispose() {
    if (identical(_guard.confirmReviewExit, _exitCallback)) {
      _guard.confirmReviewExit = null;
    }
    _scroll.dispose();
    _grade.dispose();
    _feedback.dispose();
    super.dispose();
  }

  Future<bool> _confirmExit() {
    if (_busy) return Future.value(false);
    if (!_dirty) return Future.value(true);
    return _confirmation ??=
        _confirmDiscard().whenComplete(() => _confirmation = null);
  }

  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Descartar alterações da correção?'),
            content: const Text(
                'A nota e a devolutiva digitadas ainda não foram salvas.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Continuar corrigindo'),
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
      _grade.text = _current.result?.grade?.toString() ?? '';
      _feedback.text = _current.result?.feedback ?? '';
    });
    return true;
  }

  Future<void> _read() async {
    final row = await ref
        .read(teacherReviewServiceProvider)
        .find(_current.id, _current.activityId);
    if (!mounted) return;
    if (row.studentId != _current.studentId) {
      throw const ApiException('A API retornou outro aluno.');
    }
    setState(() {
      _current = row;
      _ready = true;
      _denied = false;
      _mustRefresh = false;
      if (!_dirty) {
        _grade.text = row.result?.grade?.toString() ?? '';
        _feedback.text = row.result?.feedback ?? '';
      }
    });
  }

  void _failure(Object e) {
    setState(() {
      _error = teacherReviewError(e);
      _mustRefresh = true;
      if (e is ApiException && [401, 403, 404].contains(e.statusCode)) {
        _denied = true;
        _ready = false;
      }
    });
  }

  Future<void> _refresh() async {
    if (!mounted || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _read();
    } catch (e) {
      if (mounted) _failure(e);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        if (_scroll.hasClients) _scroll.jumpTo(0);
      }
    }
  }

  String? _validateGrade(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final text = value.trim().replaceAll(',', '.');
    final grade = double.tryParse(text);
    if (grade == null || !grade.isFinite || grade < 0 || grade > 10) {
      return 'Informe uma nota de 0 a 10, ou deixe em branco.';
    }
    if (!hasGradePrecision(text) || !hasGradePrecision(grade.toString())) {
      return 'A nota deve ter no máximo duas casas decimais.';
    }
    return null;
  }

  Future<void> _mutate({required bool publish}) async {
    if (_busy ||
        !_ready ||
        _denied ||
        _mustRefresh ||
        (publish && _dirty) ||
        _current.result?.publicationState == 'published') {
      return;
    }
    if (!publish && !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      final service = ref.read(teacherReviewServiceProvider);
      if (publish) {
        await service.publish(_current);
      } else {
        await service.save(_current,
            grade: _grade.text.trim().isEmpty
                ? null
                : double.parse(_grade.text.trim().replaceAll(',', '.')),
            feedback:
                _feedback.text.trim().isEmpty ? null : _feedback.text.trim());
      }
      if (!mounted) return;
      setState(() {
        _dirty = false;
        _message = publish
            ? 'Avaliação publicada e confirmada pela API.'
            : 'Correção salva. Resultado ainda não publicado.';
      });
      try {
        await _read();
      } catch (e) {
        if (mounted) {
          _failure(e);
          setState(() => _error =
              'Operação confirmada, mas a consulta não pôde ser atualizada. ${teacherReviewError(e)}');
        }
      }
    } catch (e) {
      if (mounted) _failure(e);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        if (_scroll.hasClients) _scroll.jumpTo(0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final review = _current.result;
    final published = review?.publicationState == 'published';
    return PopScope(
      canPop: !_dirty && !_busy,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && await _confirmExit() && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            if (_busy) const LinearProgressIndicator(),
            TextButton.icon(
                onPressed: _busy ? null : _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Atualizar entrega e avaliação')),
            if (_error != null)
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            if (_message != null && !_denied)
              Semantics(liveRegion: true, child: Text(_message!)),
            if (!_ready && _busy) const Text('Carregando entrega...'),
            if (_ready && !_denied) ...[
              AppCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Aluno: ${_current.studentId}'),
                    Text('Entrega: ${_current.id}'),
                    Text('Versão da resposta: ${_current.version}'),
                    Text('Enviada em: ${_current.submittedAt.toLocal()}'),
                    if (_current.isLate) const Text('Entrega em atraso'),
                    const SizedBox(height: AppSpacing.sm),
                    const Text('Resposta textual'),
                    Text(_current.answer),
                  ])),
              AppCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    Text(review == null
                        ? 'Sem avaliação'
                        : published
                            ? 'Avaliação publicada'
                            : 'Avaliação salva — não publicada'),
                    if (review != null) ...[
                      Text('Revisão da avaliação: ${review.revision}'),
                      Text(
                          'Nota registrada: ${review.grade?.toString() ?? 'Sem nota'}'),
                      if (review.feedback != null)
                        Text('Feedback registrado: ${review.feedback}'),
                    ],
                    if (published)
                      const Text(
                          'Resultado publicado. A API não permite retornar esta avaliação a rascunho.')
                    else
                      Form(
                          key: _form,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                    'Nota (0 a 10; em branco = sem nota)'),
                                TextFormField(
                                    controller: _grade,
                                    decoration: const InputDecoration(
                                        labelText: 'Nota'),
                                    enabled: !_busy && !_mustRefresh,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    onChanged: (_) =>
                                        setState(() => _dirty = true),
                                    validator: _validateGrade),
                                const SizedBox(height: AppSpacing.sm),
                                const Text('Feedback (opcional)'),
                                TextFormField(
                                    controller: _feedback,
                                    decoration: const InputDecoration(
                                        labelText: 'Devolutiva'),
                                    enabled: !_busy && !_mustRefresh,
                                    minLines: 3,
                                    maxLines: 8,
                                    onChanged: (_) =>
                                        setState(() => _dirty = true),
                                    validator: (v) =>
                                        (v?.trim().length ?? 0) > 20000
                                            ? 'Limite de 20000 caracteres.'
                                            : null),
                                const SizedBox(height: AppSpacing.md),
                                ElevatedButton(
                                    onPressed: _busy || _mustRefresh
                                        ? null
                                        : () => _mutate(publish: false),
                                    child: const Text('Salvar correção')),
                                if (review != null) ...[
                                  if (_dirty)
                                    const Text(
                                        'Salve as alterações antes de publicar.'),
                                  ElevatedButton(
                                      onPressed: _busy || _mustRefresh || _dirty
                                          ? null
                                          : () => _mutate(publish: true),
                                      child: const Text('Publicar avaliação')),
                                ],
                              ])),
                  ])),
            ],
          ]),
    );
  }
}
