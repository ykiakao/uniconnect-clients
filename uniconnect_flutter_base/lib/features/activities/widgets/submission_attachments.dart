import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_button_styles.dart';
import '../models/academic_attachment.dart';
import '../providers/attachment_providers.dart';
import '../services/attachment_service.dart';

enum DraftFileState {
  uploading,
  validating,
  awaitingConfirmation,
  ready,
  failed
}

/// A file chosen for the next version of a submission.
class DraftFile {
  DraftFile(this.name, this.sizeBytes,
      {this.state = DraftFileState.uploading,
      this.attachment,
      this.kept = false});

  final String name;
  final int sizeBytes;
  DraftFileState state;
  AcademicAttachment? attachment;
  String? fileId;
  String? error;

  /// Comes from the current version; kept unless the student removes it.
  final bool kept;
}

/// Files of the next submission version. Only files confirmed by the API
/// (`ready`) are sent; nothing is shown as sent before the API confirms.
class AttachmentDraftController extends ChangeNotifier {
  final _files = <DraftFile>[];
  String? notice;
  bool _disposed = false;

  List<DraftFile> get files => List.unmodifiable(_files);
  bool get busy => _files.any((file) =>
      file.state == DraftFileState.uploading ||
      file.state == DraftFileState.validating);
  bool get isFull => _files.length >= attachmentMaxFiles;
  bool get needsConfirmation =>
      _files.any((file) => file.state == DraftFileState.awaitingConfirmation);
  List<String> get readyIds => [
        for (final file in _files)
          if (file.state == DraftFileState.ready && file.attachment != null)
            file.attachment!.id,
      ];

  /// Starts from the files of the current version (resubmission keeps them).
  /// Called while the panel builds, so it does not notify.
  void seed(List<AcademicAttachment> current) {
    _files
      ..clear()
      ..addAll([
        for (final file in current)
          DraftFile(file.name, file.sizeBytes,
              state: DraftFileState.ready, attachment: file, kept: true),
      ]);
    notice = null;
  }

  Future<void> pickAndUpload({
    required Future<List<PickedFile>> Function() pick,
    required AttachmentService service,
    required String activityId,
    required int expectedVersion,
  }) async {
    notice = null;
    final List<PickedFile> picked;
    try {
      picked = await pick();
    } on Object {
      notice = 'Não foi possível abrir os arquivos.';
      _notify();
      return;
    }
    for (final file in picked) {
      if (isFull) {
        notice = 'Limite de $attachmentMaxFiles arquivos por entrega.';
        break;
      }
      final problem = attachmentValidationError(file.name, file.size);
      if (problem != null) {
        notice = '${file.name}: $problem';
        continue;
      }
      final draft = DraftFile(file.name, file.size);
      _files.add(draft);
      _notify();
      await _upload(draft, file, service, activityId, expectedVersion);
    }
    _notify();
  }

  Future<void> _upload(DraftFile draft, PickedFile file,
      AttachmentService service, String activityId, int version) async {
    try {
      final reservation = await service.reserveSubmissionFile(activityId,
          fileName: file.name,
          sizeBytes: file.size,
          expectedVersion: version,
          idempotencyKey: newIdempotencyKey());
      draft.fileId = reservation.id;
      final ticket = reservation.ticket;
      if (ticket == null) {
        throw const _RetryReservation();
      }
      await service.uploadBytes(ticket, await file.read());
    } on Object catch (error) {
      if (draft.fileId != null && isAttachmentOutcomeUncertain(error)) {
        draft.state = DraftFileState.awaitingConfirmation;
        draft.error = AttachmentConfirmationPending(draft.fileId!).message;
        _notify();
        return;
      }
      draft
        ..state = DraftFileState.failed
        ..error = error is _RetryReservation
            ? 'Selecione o arquivo novamente.'
            : attachmentErrorText(error);
      final fileId = draft.fileId;
      if (fileId != null) unawaited(_cancelQuietly(service, fileId));
      _notify();
      return;
    }
    await _confirm(draft, service);
  }

  Future<void> recover(DraftFile draft, AttachmentService? service) async {
    if (_disposed ||
        service == null ||
        !_files.contains(draft) ||
        draft.state != DraftFileState.awaitingConfirmation) {
      return;
    }
    await _confirm(draft, service, resume: true);
  }

  Future<void> _confirm(DraftFile draft, AttachmentService service,
      {bool resume = false}) async {
    if (_disposed || !_files.contains(draft)) return;
    final id = draft.fileId;
    if (id == null) return;
    draft.state = DraftFileState.validating;
    draft.error = null;
    _notify();
    try {
      final attachment =
          await (resume ? service.recover(id) : service.complete(id));
      if (_disposed || !_files.contains(draft)) return;
      draft.attachment = attachment;
      draft.state = DraftFileState.ready;
    } on AttachmentConfirmationPending catch (error) {
      if (_disposed || !_files.contains(draft)) return;
      draft.state = DraftFileState.awaitingConfirmation;
      draft.error = error.message;
    } on Object catch (error) {
      if (_disposed || !_files.contains(draft)) return;
      draft.state = DraftFileState.failed;
      draft.error = attachmentErrorText(error);
    }
    _notify();
  }

  /// Removes from the next version. New, unlinked files are also cancelled
  /// in the API; files of previous versions stay in their history.
  Future<void> remove(DraftFile file, AttachmentService? service) async {
    _files.remove(file);
    _notify();
    final fileId = file.attachment?.id ?? file.fileId;
    if (!file.kept && fileId != null && service != null) {
      await _cancelQuietly(service, fileId);
    }
  }

  Future<void> _cancelQuietly(AttachmentService service, String fileId) async {
    try {
      await service.cancel(fileId);
    } on Object {
      // Unlinked files expire on the server; nothing to undo here.
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class _RetryReservation implements Exception {
  const _RetryReservation();
}

/// Editable list of files for the next version.
class AttachmentDraftSection extends StatelessWidget {
  const AttachmentDraftSection({
    super.key,
    required this.controller,
    required this.enabled,
    required this.onPick,
    required this.onRemove,
    this.onRecover,
  });

  final AttachmentDraftController controller;
  final bool enabled;
  final VoidCallback onPick;
  final void Function(DraftFile file) onRemove;
  final void Function(DraftFile file)? onRecover;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Arquivos (opcional)', style: text.titleSmall),
          Text(
              'PDF, DOCX, PNG ou JPG, até 10 MB cada e no máximo $attachmentMaxFiles.',
              style: text.bodySmall?.copyWith(color: AppColors.inkMuted)),
          const SizedBox(height: AppSpacing.xs),
          for (final file in controller.files)
            _FileRow(
              name: file.name,
              sizeBytes: file.sizeBytes,
              status: switch (file.state) {
                DraftFileState.uploading => 'Enviando…',
                DraftFileState.validating => 'Verificando arquivo…',
                DraftFileState.awaitingConfirmation =>
                  file.error ?? 'Confirmação pendente. Verifique novamente.',
                DraftFileState.ready =>
                  file.kept ? 'Da versão atual' : 'Pronto para enviar',
                DraftFileState.failed => file.error ?? 'Não enviado',
              },
              failed: file.state == DraftFileState.failed,
              working: file.state == DraftFileState.uploading ||
                  file.state == DraftFileState.validating,
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                if (file.state == DraftFileState.awaitingConfirmation &&
                    onRecover != null)
                  IconButton(
                    tooltip: 'Verificar ${file.name}',
                    onPressed: enabled && !controller.busy
                        ? () => onRecover!(file)
                        : null,
                    icon: const Icon(LucideIcons.refreshCw, size: 18),
                  ),
                IconButton(
                  tooltip: 'Remover ${file.name}',
                  onPressed: enabled &&
                          file.state != DraftFileState.uploading &&
                          file.state != DraftFileState.validating
                      ? () => onRemove(file)
                      : null,
                  icon: const Icon(LucideIcons.x, size: 18),
                ),
              ]),
            ),
          if (controller.notice case final notice?)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxs),
              child: Text(notice,
                  style: text.bodySmall?.copyWith(color: AppColors.danger)),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: AppButtonStyles.link,
              onPressed: enabled && !controller.busy && !controller.isFull
                  ? onPick
                  : null,
              icon: const Icon(LucideIcons.paperclip, size: 18),
              label: const Text('Adicionar arquivo'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Read-only files with a download action that asks the API for a fresh
/// signed link at click time.
class AttachmentList extends ConsumerStatefulWidget {
  const AttachmentList({super.key, required this.files, this.onRemove});

  final List<AcademicAttachment> files;

  /// When set, each row also offers removal (teacher materials).
  final void Function(AcademicAttachment file)? onRemove;

  @override
  ConsumerState<AttachmentList> createState() => _AttachmentListState();
}

class _AttachmentListState extends ConsumerState<AttachmentList> {
  String? _opening;
  String? _error;

  Future<void> _open(AcademicAttachment file) async {
    if (_opening != null) return;
    setState(() {
      _opening = file.id;
      _error = null;
    });
    try {
      final url =
          await ref.read(attachmentServiceProvider).downloadUrl(file.id);
      await ref.read(linkOpenerProvider)(url);
    } on Object catch (error) {
      if (mounted) setState(() => _error = attachmentErrorText(error));
    } finally {
      if (mounted) setState(() => _opening = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final file in widget.files)
          _FileRow(
            name: file.name,
            sizeBytes: file.sizeBytes,
            image: file.isImage,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_opening == file.id)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else
                  IconButton(
                    tooltip: 'Baixar ${file.name}',
                    onPressed: () => _open(file),
                    icon: const Icon(LucideIcons.download, size: 18),
                  ),
                if (widget.onRemove case final remove?)
                  IconButton(
                    tooltip: 'Remover ${file.name}',
                    onPressed: () => remove(file),
                    icon: const Icon(LucideIcons.trash2,
                        size: 18, color: AppColors.danger),
                  ),
              ],
            ),
          ),
        if (_error != null)
          Text(_error!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.danger)),
      ],
    );
  }
}

/// Files of previous versions, loaded when a version is opened.
class VersionFilesHistory extends ConsumerWidget {
  const VersionFilesHistory(
      {super.key, required this.submissionId, required this.currentVersion});

  final String submissionId;
  final int currentVersion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Versões anteriores', style: text.titleSmall),
        for (var version = currentVersion - 1; version >= 1; version--)
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('Versão $version', style: text.bodyMedium),
              children: [
                _VersionFiles(submissionId: submissionId, version: version),
              ],
            ),
          ),
      ],
    );
  }
}

class _VersionFiles extends ConsumerWidget {
  const _VersionFiles({required this.submissionId, required this.version});

  final String submissionId;
  final int version;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: AppColors.inkMuted);
    return ref
        .watch(submissionVersionFilesProvider(
            (submissionId: submissionId, version: version)))
        .when(
          loading: () => const LinearProgressIndicator(
              semanticsLabel: 'Carregando arquivos da versão'),
          error: (error, _) => Text(attachmentErrorText(error), style: muted),
          data: (files) => files.isEmpty
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Sem arquivos nesta versão.', style: muted))
              : AttachmentList(files: files),
        );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.name,
    required this.sizeBytes,
    required this.trailing,
    this.status,
    this.failed = false,
    this.working = false,
    this.image = false,
  });

  final String name;
  final int sizeBytes;
  final Widget trailing;
  final String? status;
  final bool failed;
  final bool working;
  final bool image;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final meta =
        [formatFileSize(sizeBytes), if (status != null) status!].join(' • ');
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.only(left: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: failed ? AppColors.danger : AppColors.line),
      ),
      child: Row(
        children: [
          Icon(image ? LucideIcons.image : LucideIcons.fileText,
              size: 20, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium),
                  Text(meta,
                      style: text.bodySmall?.copyWith(
                          color:
                              failed ? AppColors.danger : AppColors.inkMuted)),
                  if (working)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                ],
              ),
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
