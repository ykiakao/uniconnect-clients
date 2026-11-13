import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../academic/demo/synthetic_academic_providers.dart';
import '../../auth/models/app_user.dart';
import '../../auth/providers/auth_provider.dart';
import '../../grades/providers/grades_provider.dart';
import '../models/academic_activity.dart';
import '../providers/activity_provider.dart';
import '../providers/attachment_providers.dart';
import '../providers/student_submission_provider.dart';
import '../services/attachment_service.dart';
import '../services/student_submission_service.dart';
import 'submission_attachments.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
    if (!['published', 'closed'].contains(activity.publicationState)) {
      return const AppCard(
          child: Text('Envio indisponível para o estado atual da atividade.'));
    }
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;
    if (!auth.isAuthenticated || user == null || auth.accessToken == null) {
      return const AppCard(
          child: Text('Sessão inválida ou expirada. Entre novamente.'));
    }
    if (user.role != UserRole.student) {
      return const AppCard(
          child: Text(
              'Consulta e envio pessoais disponíveis apenas para alunos.'));
    }
    return _SubmissionEditor(
        key: ValueKey((
          activity.id,
          user.id,
          user.tenant.id,
          user.tenant.slug,
          auth.accessToken,
          ref.read(authControllerProvider.notifier).sessionGeneration
        )),
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
  final _drafts = AttachmentDraftController();
  final _form = GlobalKey<FormState>();
  int? _seededVersion;
  bool _dirty = false;
  bool _sending = false;
  bool _confirmingTextOnly = false;
  bool _attachmentsUnavailable = false;
  bool _refreshing = false;
  bool _mustRefresh = false;
  String? _error;
  String? _confirmation;
  bool get _busy => _sending || _refreshing || _confirmingTextOnly;
  String get _id => widget.activity.id;

  @override
  void initState() {
    super.initState();
    _drafts.addListener(_onDraftsChanged);
  }

  void _onDraftsChanged() {
    if (mounted) setState(() {});
  }

  AttachmentService? get _attachments {
    try {
      return ref.read(attachmentServiceProvider);
    } on Object {
      return null;
    }
  }

  void _pickFiles(StudentSubmission? previous) {
    if (_attachmentsUnavailable) return;
    final service = _attachments;
    if (service == null) return;
    _dirty = true;
    _drafts.pickAndUpload(
      pick: ref.read(attachmentPickerProvider),
      service: service,
      activityId: _id,
      expectedVersion: previous?.version ?? 0,
    );
  }

  @override
  void dispose() {
    _drafts
      ..removeListener(_onDraftsChanged)
      ..dispose();
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
      ref.invalidate(subjectGradesProvider);
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

  Future<void> _confirmTextOnly(StudentSubmission? previous) async {
    setState(() => _confirmingTextOnly = true);
    var confirmed = false;
    try {
      confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Enviar versão sem anexos?'),
              content: const Text(
                  'Esta nova versão não incluirá arquivos. Os anexos já enviados continuarão disponíveis nas versões anteriores do histórico. Confirma o envio somente do texto?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Voltar')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Enviar só o texto')),
              ],
            ),
          ) ??
          false;
    } finally {
      if (mounted) setState(() => _confirmingTextOnly = false);
    }
    if (mounted && confirmed) {
      await _submit(previous, textOnlyConfirmed: true);
    }
  }

  Future<void> _submit(StudentSubmission? previous,
      {bool textOnlyConfirmed = false}) async {
    if (_drafts.busy || _drafts.needsConfirmation) return;
    final activity = widget.activity;
    if (_busy ||
        !widget.activityIsCurrent ||
        _mustRefresh ||
        !activity.acceptsTextSubmission ||
        activity.publicationState != 'published' ||
        (activity.priorityAt(ref.read(activityClockProvider)) ==
                ActivityPriority.expired &&
            !activity.allowLate) ||
        (previous != null && !previous.canRevise)) {
      return;
    }
    if (!_form.currentState!.validate()) return;
    if (_attachmentsUnavailable && !textOnlyConfirmed) {
      await _confirmTextOnly(previous);
      return;
    }
    final text = _answer.text;
    setState(() {
      _sending = true;
      _error = null;
      _confirmation = null;
    });
    try {
      await ref.read(studentSubmissionServiceProvider).submit(_id,
          answer: text,
          expectedVersion: previous?.version ?? 0,
          attachmentIds: textOnlyConfirmed ? const [] : _drafts.readyIds);
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
          if (e is ApiException &&
              e.statusCode == 503 &&
              e.code == 'ACADEMIC_ATTACHMENTS_UNAVAILABLE' &&
              _drafts.readyIds.isNotEmpty) {
            _attachmentsUnavailable = true;
          }
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
    final expired = activity.priorityAt(ref.watch(activityClockProvider)) ==
        ActivityPriority.expired;
    return AppCard(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Sua entrega', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: AppSpacing.sm),
      if (!activity.acceptsTextSubmission)
        const Text('Esta atividade não aceita entrega textual.'),
      if (_confirmation != null)
        Semantics(liveRegion: true, child: Text(_confirmation!)),
      if (_error != null)
        Text(_error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
      if (_attachmentsUnavailable)
        const Text(
            'Os anexos não podem ser reenviados neste momento. Atualize sua entrega e confirme o envio de uma nova versão só em texto. Os arquivos anteriores permanecerão no histórico.'),
      if (_sending || _refreshing) const LinearProgressIndicator(),
      TextButton.icon(
          onPressed: _busy ? null : _reload,
          icon: const Icon(LucideIcons.refreshCw),
          label: const Text('Atualizar minha entrega')),
      own.when(
          skipLoadingOnRefresh: false,
          loading: () => const Text('Carregando sua entrega...'),
          error: (e, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                      'Erro ao consultar sua entrega. ${submissionErrorText(e)}'),
                  if (widget.activityIsCurrent &&
                      !activity.acceptsTextSubmission)
                    _PublishedActivityGrade(activityId: _id),
                ],
              ),
          data: (submission) {
            final version = submission?.version ?? 0;
            if (_seededVersion != version && !_dirty) {
              _answer.text = submission?.answer ?? '';
              _drafts.seed(submission?.attachments ?? const []);
              _seededVersion = version;
            }
            final closed = activity.publicationState != 'published';
            final deadline = expired && !activity.allowLate;
            final locked = submission != null && !submission.canRevise;
            final result = submission?.result;
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
                    if (submission.attachments.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text('Arquivos enviados',
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: AppSpacing.xxs),
                      AttachmentList(files: submission.attachments),
                    ],
                    if (submission.version > 1) ...[
                      const SizedBox(height: AppSpacing.sm),
                      VersionFilesHistory(
                          submissionId: submission.id,
                          currentVersion: submission.version),
                    ],
                    if (result != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(result.grade == null
                          ? 'Nota indisponível'
                          : 'Nota: ${result.grade}'),
                      if (result.feedback case final feedback?
                          when feedback.trim().isNotEmpty) ...[
                        const Text('Feedback:'),
                        Text(feedback),
                      ],
                    ],
                  ],
                  if (result == null && widget.activityIsCurrent)
                    _PublishedActivityGrade(activityId: _id),
                  if (closed)
                    const Text(
                        'Atividade encerrada ou indisponível para envio.')
                  else if (deadline)
                    const Text(
                        'Prazo encerrado. Esta atividade não permite envio em atraso.')
                  else if (locked)
                    const Text(
                        'Reenvio indisponível: a entrega está em avaliação ou atingiu o limite de versões.')
                  else if (activity.acceptsTextSubmission) ...[
                    if (expired && activity.allowLate)
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
                              const SizedBox(height: AppSpacing.md),
                              if (!_attachmentsUnavailable)
                                AttachmentDraftSection(
                                  controller: _drafts,
                                  enabled: !_busy &&
                                      !_mustRefresh &&
                                      widget.activityIsCurrent,
                                  onPick: () => _pickFiles(submission),
                                  allowPicking: !_attachmentsUnavailable,
                                  onRecover: (file) =>
                                      _drafts.recover(file, _attachments),
                                  onRemove: (file) {
                                    _dirty = true;
                                    _drafts.remove(file, _attachments);
                                  },
                                ),
                              const SizedBox(height: AppSpacing.sm),
                              ElevatedButton.icon(
                                  onPressed: _busy ||
                                          _drafts.busy ||
                                          _drafts.needsConfirmation ||
                                          _mustRefresh ||
                                          !widget.activityIsCurrent
                                      ? null
                                      : () => _submit(submission),
                                  icon: const Icon(LucideIcons.send),
                                  label: Text(_sending
                                      ? 'Enviando resposta...'
                                      : _attachmentsUnavailable
                                          ? 'Enviar nova versão só em texto'
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

class _PublishedActivityGrade extends ConsumerWidget {
  const _PublishedActivityGrade({required this.activityId});

  final String activityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(subjectGradesProvider).when(
          skipLoadingOnRefresh: false,
          skipLoadingOnReload: false,
          loading: () => const Text('Consultando avaliação publicada…'),
          error: (_, __) =>
              const Text('Avaliação individual indisponível para consulta.'),
          data: (grades) {
            for (final grade in grades) {
              if (grade.activityId != activityId) continue;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.sm),
                  const Text('Avaliação publicada'),
                  Text(grade.grade == null
                      ? 'Nota indisponível'
                      : 'Nota: ${grade.grade}'),
                  if (grade.feedback case final feedback?
                      when feedback.trim().isNotEmpty) ...[
                    const Text('Devolutiva'),
                    Text(feedback),
                  ],
                ],
              );
            }
            return const SizedBox.shrink();
          },
        );
  }
}
