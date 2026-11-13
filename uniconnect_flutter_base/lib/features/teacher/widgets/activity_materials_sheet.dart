import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button_styles.dart';
import '../../activities/models/academic_attachment.dart';
import '../../activities/providers/attachment_providers.dart';
import '../../activities/services/attachment_service.dart';
import '../../activities/widgets/submission_attachments.dart';
import '../providers/teacher_activity_provider.dart';
import '../services/teacher_activity_service.dart';

/// Materials can change while the work takes no submission yet; the API
/// has the final word (409 after the first submission or closing).
bool canManageMaterials(TeacherActivity work) =>
    !work.isExam && work.workflowEnabled && work.state != 'closed';

Future<void> showActivityMaterials(
    BuildContext context, WidgetRef ref, TeacherActivity work) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: .85,
      child: ActivityMaterialsSheet(work: work),
    ),
  );
  // Linking and removing change the activity revision.
  ref.invalidate(teacherActivitiesProvider(work.classId));
  ref.invalidate(teacherActivityPreviewProvider(work.classId));
}

/// Teacher materials of one activity: list, add (reserve → Storage →
/// confirm → link with the activity revision) and remove.
class ActivityMaterialsSheet extends ConsumerStatefulWidget {
  const ActivityMaterialsSheet({super.key, required this.work});

  final TeacherActivity work;

  @override
  ConsumerState<ActivityMaterialsSheet> createState() =>
      _ActivityMaterialsSheetState();
}

class _Upload {
  _Upload(this.name, this.sizeBytes);
  final String name;
  final int sizeBytes;
  String status = 'Enviando…';
  String? error;
  String? fileId;
  int? linkRevision;
  bool confirmationPending = false;
}

class _ActivityMaterialsSheetState
    extends ConsumerState<ActivityMaterialsSheet> {
  late int _revision = widget.work.revision;
  List<AcademicAttachment>? _materials;
  final _uploads = <_Upload>[];
  String? _error;
  bool _working = false;

  AttachmentService get _service => ref.read(attachmentServiceProvider);
  String get _id => widget.work.id;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final materials = await _service.materials(_id);
      if (mounted) setState(() => _materials = materials);
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _materials = const [];
          _error = attachmentErrorText(error);
        });
      }
    }
  }

  Future<void> _add() async {
    if (_working) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final picked = await ref.read(attachmentPickerProvider)();
      for (final file in picked) {
        final used = (_materials?.length ?? 0) +
            _uploads
                .where((upload) =>
                    upload.error == null || upload.confirmationPending)
                .length;
        if (used >= attachmentMaxFiles) {
          _error = 'Limite de $attachmentMaxFiles materiais por atividade.';
          break;
        }
        final problem = attachmentValidationError(file.name, file.size);
        if (problem != null) {
          _error = '${file.name}: $problem';
          continue;
        }
        await _upload(file);
      }
    } on Object {
      _error = 'Não foi possível abrir os arquivos.';
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _upload(PickedFile file) async {
    final upload = _Upload(file.name, file.size);
    setState(() => _uploads.add(upload));
    try {
      final reservation = await _service.reserveMaterial(_id,
          fileName: file.name,
          sizeBytes: file.size,
          idempotencyKey: newIdempotencyKey());
      upload.fileId = reservation.id;
      final ticket = reservation.ticket;
      if (ticket == null) {
        throw const _Reselect();
      }
      await _service.uploadBytes(ticket, await file.read());
    } on Object catch (error) {
      final id = upload.fileId;
      final uncertain = id != null && isAttachmentOutcomeUncertain(error);
      if (id != null && !uncertain) unawaited(_cancelQuietly(id));
      if (mounted) {
        setState(() {
          upload.confirmationPending = uncertain;
          upload.error = uncertain
              ? AttachmentConfirmationPending(id).message
              : error is _Reselect
                  ? 'Selecione o arquivo novamente.'
                  : attachmentErrorText(error);
        });
      }
      return;
    }
    await _confirmAndLink(upload);
  }

  /// Drops a file whose confirmation stays pending. An unlinked
  /// reservation is cancelled; a linked one is refused by the API (409).
  void _dismiss(_Upload upload) {
    final id = upload.fileId;
    if (id != null) unawaited(_cancelQuietly(id));
    setState(() => _uploads.remove(upload));
  }

  Future<void> _recover(_Upload upload) async {
    if (_working || !upload.confirmationPending) return;
    setState(() => _working = true);
    try {
      await _confirmAndLink(upload, resume: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _confirmAndLink(_Upload upload, {bool resume = false}) async {
    if (!mounted) return;
    final id = upload.fileId!;
    if (mounted) {
      setState(() {
        upload.error = null;
        upload.confirmationPending = false;
      });
    }
    try {
      if (mounted) setState(() => upload.status = 'Verificando arquivo…');
      await (resume ? _service.recover(id) : _service.complete(id));
      if (!mounted) return;
      if (mounted) setState(() => upload.status = 'Vinculando à atividade…');
      upload.linkRevision ??= _revision;
      final linked = await _service.linkMaterial(_id, id, upload.linkRevision!);
      if (!mounted) return;
      setState(() {
        if (linked.revision > _revision) _revision = linked.revision;
        if (!(_materials ?? const <AcademicAttachment>[])
            .any((file) => file.id == id)) {
          _materials = [...?_materials, linked.attachment];
        }
        _uploads.remove(upload);
      });
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          upload.confirmationPending = error is AttachmentConfirmationPending ||
              isAttachmentOutcomeUncertain(error);
          upload.error = upload.confirmationPending
              ? (error is AttachmentConfirmationPending
                  ? error.message
                  : AttachmentConfirmationPending(id).message)
              : attachmentErrorText(error);
        });
      }
    }
  }

  Future<void> _cancelQuietly(String fileId) async {
    try {
      await _service.cancel(fileId);
    } on Object {
      // An unlinked file expires on the server.
    }
  }

  Future<void> _remove(AcademicAttachment file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover material?'),
        content: Text(
            '“${file.name}” deixará de aparecer para os alunos. O registro é mantido no histórico.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remover')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final revision = await _service.removeMaterial(_id, file.id, _revision);
      if (!mounted) return;
      setState(() {
        _revision = revision;
        _materials = [
          for (final row in _materials ?? const <AcademicAttachment>[])
            if (row.id != file.id) row,
        ];
      });
    } on Object catch (error) {
      if (mounted) setState(() => _error = attachmentErrorText(error));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = text.bodySmall?.copyWith(color: AppColors.inkMuted);
    final materials = _materials;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.pageHorizontal, 0,
          AppSpacing.pageHorizontal, AppSpacing.md),
      child: ListView(
        children: [
          Text('Materiais da atividade', style: text.titleLarge),
          const SizedBox(height: AppSpacing.xxs),
          Text(widget.work.title, style: text.titleSmall),
          const SizedBox(height: AppSpacing.xxs),
          Text(
              'PDF, DOCX, PNG ou JPG, até 10 MB cada e no máximo $attachmentMaxFiles. Depois da primeira entrega dos alunos, os materiais não podem mais ser alterados.',
              style: muted),
          const SizedBox(height: AppSpacing.md),
          if (materials == null)
            const LinearProgressIndicator(
                semanticsLabel: 'Carregando materiais')
          else if (materials.isEmpty && _uploads.isEmpty)
            Text('Nenhum material anexado.', style: muted)
          else
            AttachmentList(
              files: materials,
              onRemove: _working ? null : _remove,
            ),
          for (final upload in _uploads)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: upload.confirmationPending
                  ? const Icon(LucideIcons.hourglass, color: AppColors.inkMuted)
                  : upload.error == null
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(LucideIcons.circleAlert,
                          color: AppColors.danger),
              title: Text(upload.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                  '${formatFileSize(upload.sizeBytes)} • ${upload.error ?? upload.status}',
                  style: upload.error == null
                      ? muted
                      : muted?.copyWith(color: AppColors.danger)),
              trailing: upload.confirmationPending
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: _working ? null : () => _recover(upload),
                          child: const Text('Verificar arquivo'),
                        ),
                        IconButton(
                          tooltip: 'Dispensar ${upload.name}',
                          onPressed: _working ? null : () => _dismiss(upload),
                          icon: const Icon(LucideIcons.x, size: 18),
                        ),
                      ],
                    )
                  : upload.error == null
                      ? null
                      : IconButton(
                          tooltip: 'Dispensar ${upload.name}',
                          onPressed: () =>
                              setState(() => _uploads.remove(upload)),
                          icon: const Icon(LucideIcons.x, size: 18),
                        ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(_error!,
                  style: text.bodySmall?.copyWith(color: AppColors.danger)),
            ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _working || materials == null ? null : _add,
              icon: const Icon(LucideIcons.paperclip, size: 18),
              label: const Text('Adicionar material'),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: AppButtonStyles.link,
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Concluir'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Reselect implements Exception {
  const _Reselect();
}
