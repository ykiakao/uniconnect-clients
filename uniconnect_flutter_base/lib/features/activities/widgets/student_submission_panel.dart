import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../academic/demo/synthetic_academic_providers.dart';
import '../../auth/models/app_user.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/academic_activity.dart';
import '../providers/activity_provider.dart';
import '../providers/student_submission_provider.dart';
import '../services/student_submission_service.dart';

class StudentSubmissionPanel extends ConsumerWidget {
  const StudentSubmissionPanel(
      {super.key, required this.activity, this.activityIsCurrent = true});
  final AcademicActivity activity;
  final bool activityIsCurrent;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(syntheticDemoEnabledProvider)) {
      return const AppCard(
          child: Text(
              'Dados sintéticos: consulta e envio de entregas persistentes indisponíveis neste modo.'));
    }
    if (activity.publicationState == null) {
      return const AppCard(
          child: Text(
              'Envio indisponível: o estado da atividade não foi informado.'));
    }
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;
    if (user == null || auth.accessToken == null) {
      return const AppCard(
          child: Text('Sessão inválida ou expirada. Entre novamente.'));
    }
    if (user.role != UserRole.student) {
      return const AppCard(
          child: Text(
              'Consulta e envio pessoais disponíveis apenas para alunos.'));
    }
    return _SubmissionEditor(
        key: ValueKey(
            (activity.id, user.id, user.tenant.slug, auth.accessToken)),
        activity: activity,
        activityIsCurrent: activityIsCurrent);
  }
}

class _SubmissionEditor extends ConsumerStatefulWidget {
  const _SubmissionEditor(
      {super.key, required this.activity, required this.activityIsCurrent});
  final AcademicActivity activity;
  final bool activityIsCurrent;
  @override
  ConsumerState<_SubmissionEditor> createState() => _SubmissionEditorState();
}

class _SubmissionEditorState extends ConsumerState<_SubmissionEditor>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final _answer = TextEditingController();
  final _form = GlobalKey<FormState>();
  int? _seededVersion;
  bool _dirty = false;
  bool _sending = false;
  bool _refreshing = false;
  bool _mustRefresh = false;
  String? _error;
  String? _confirmation;
  bool get _busy => _sending || _refreshing;
  String get _id => widget.activity.id;

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    if (_busy) return;
    setState(() {
      _refreshing = true;
      _error = null;
    });
    try {
      ref.invalidate(ownSubmissionProvider(_id));
      ref.invalidate(activityByIdProvider(_id));
      await Future.wait<Object?>([
        ref.read(ownSubmissionProvider(_id).future),
        ref.read(activityByIdProvider(_id).future)
      ]);
      if (mounted) setState(() => _mustRefresh = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = submissionErrorText(e);
          _mustRefresh = true;
        });
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _submit(StudentSubmission? previous) async {
    final activity = widget.activity;
    if (_busy ||
        !widget.activityIsCurrent ||
        _mustRefresh ||
        activity.publicationState != 'published' ||
        (activity.isExpired && !activity.allowLate) ||
        (previous != null && !previous.canRevise)) {
      return;
    }
    if (!_form.currentState!.validate()) return;
    final text = _answer.text;
    setState(() {
      _sending = true;
      _error = null;
      _confirmation = null;
    });
    try {
      await ref
          .read(studentSubmissionServiceProvider)
          .submit(_id, answer: text, expectedVersion: previous?.version ?? 0);
      if (!mounted) return;
      setState(() {
        _confirmation = 'Resposta enviada e confirmada pela API.';
        _dirty = false;
        _seededVersion = null;
      });
      ref.invalidate(ownSubmissionProvider(_id));
      ref.invalidate(activityByIdProvider(_id));
      ref.invalidate(activitiesProvider);
      try {
        await Future.wait<Object?>([
          ref.read(ownSubmissionProvider(_id).future),
          ref.read(activityByIdProvider(_id).future)
        ]);
      } catch (e) {
        if (mounted) {
          setState(() {
            _error =
                'Envio confirmado, mas não foi possível atualizar os dados. ${submissionErrorText(e)}';
            _mustRefresh = true;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error =
              '${submissionErrorText(e)} Consulte sua entrega antes de repetir o envio.';
          _mustRefresh = true;
        });
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final own = ref.watch(ownSubmissionProvider(_id));
    final activity = widget.activity;
    return AppCard(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Sua entrega', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: AppSpacing.sm),
      if (_confirmation != null) Text(_confirmation!),
      if (_error != null)
        Text(_error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
      if (_busy) const LinearProgressIndicator(),
      TextButton.icon(
          onPressed: _busy ? null : _reload,
          icon: const Icon(Icons.refresh),
          label: const Text('Atualizar minha entrega')),
      own.when(
          skipLoadingOnRefresh: false,
          loading: () => const Text('Carregando sua entrega...'),
          error: (e, _) =>
              Text('Erro ao consultar sua entrega. ${submissionErrorText(e)}'),
          data: (submission) {
            final version = submission?.version ?? 0;
            if (_seededVersion != version && !_dirty) {
              _answer.text = submission?.answer ?? '';
              _seededVersion = version;
            }
            final closed = activity.publicationState != 'published';
            final deadline = activity.isExpired && !activity.allowLate;
            final locked = submission != null && !submission.canRevise;
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (submission == null)
                    const Text('Nenhuma entrega enviada.')
                  else ...[
                    Text(
                        '${submission.statusLabel} • Versão ${submission.version}'),
                    Text('Enviada em: ${submission.submittedAt.toLocal()}'),
                    if (submission.isLate)
                      const Text('Entrega registrada com atraso.'),
                    const SizedBox(height: AppSpacing.sm),
                    const Text('Resposta registrada:'),
                    Text(submission.answer),
                  ],
                  if (closed)
                    const Text(
                        'Atividade encerrada ou indisponível para envio.')
                  else if (deadline)
                    const Text(
                        'Prazo encerrado. Esta atividade não permite envio em atraso.')
                  else if (locked)
                    const Text(
                        'Reenvio indisponível: a entrega está em avaliação ou atingiu o limite de versões.')
                  else ...[
                    if (activity.isExpired && activity.allowLate)
                      const Text(
                          'O prazo passou, mas a atividade permite envio em atraso.'),
                    const SizedBox(height: AppSpacing.md),
                    Form(
                        key: _form,
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(submission == null
                                  ? 'Resposta textual'
                                  : 'Revisar resposta textual'),
                              const SizedBox(height: AppSpacing.xs),
                              Semantics(
                                  label: 'Resposta textual',
                                  child: TextFormField(
                                      controller: _answer,
                                      enabled: !_busy &&
                                          !_mustRefresh &&
                                          widget.activityIsCurrent,
                                      minLines: 4,
                                      maxLines: 10,
                                      onChanged: (_) => _dirty = true,
                                      validator: (v) {
                                        final text = v?.trim() ?? '';
                                        if (text.isEmpty) {
                                          return 'Informe sua resposta.';
                                        }
                                        if (text.length > 20000) {
                                          return 'Limite de 20000 caracteres.';
                                        }
                                        return null;
                                      })),
                              const SizedBox(height: AppSpacing.sm),
                              ElevatedButton.icon(
                                  onPressed: _busy ||
                                          _mustRefresh ||
                                          !widget.activityIsCurrent
                                      ? null
                                      : () => _submit(submission),
                                  icon: const Icon(Icons.send_outlined),
                                  label: Text(_sending
                                      ? 'Enviando resposta...'
                                      : submission == null
                                          ? 'Enviar resposta'
                                          : 'Reenviar resposta')),
                            ])),
                  ],
                ]);
          }),
    ]));
  }
}
