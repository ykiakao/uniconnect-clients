import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/academic_blocks.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/status_banner.dart';

import '../../../shared/widgets/app_card.dart';
import '../services/teacher_academic_service.dart';
import '../providers/teacher_review_provider.dart';
import 'academic_page_controls.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../shared/widgets/app_button_styles.dart';

class TeacherReportPanel extends StatefulWidget {
  const TeacherReportPanel(
      {super.key, required this.classId, required this.service});

  final String classId;
  final TeacherAcademicService service;

  @override
  State<TeacherReportPanel> createState() => _TeacherReportPanelState();
}

class _TeacherReportPanelState extends State<TeacherReportPanel> {
  String _stage = 'N1';
  int _summaryPage = 1;
  int _issuePage = 1;
  bool _busy = false;
  String? _message;
  late Future<AcademicStageStatus> _status =
      widget.service.stage(widget.classId, _stage);
  late Future<AcademicPage<TeacherReportCard>> _summary =
      _withNames(widget.service.summary(widget.classId));

  /// Student names seen in the report pages, to name closure issues.
  final _names = <String, String>{};

  Future<AcademicPage<TeacherReportCard>> _withNames(
          Future<AcademicPage<TeacherReportCard>> page) =>
      page.then((result) {
        final added = {
          for (final card in result.rows)
            if (card.studentName.trim().isNotEmpty)
              card.studentId: card.studentName,
        };
        if (mounted &&
            !mapEquals(added, {
              for (final key in added.keys) key: _names[key] ?? '',
            })) {
          setState(() => _names.addAll(added));
        }
        return result;
      });
  Future<TeacherReportCard>? _detail;

  void _loadSummary(int page) => setState(() {
        _summaryPage = page;
        _summary =
            _withNames(widget.service.summary(widget.classId, page: page));
        _detail = null;
      });

  void _loadStage(int page) => setState(() {
        _issuePage = page;
        _status = widget.service.stage(widget.classId, _stage, page: page);
      });

  void _refresh() {
    _loadStage(_issuePage);
    _loadSummary(_summaryPage);
  }

  Future<void> _close() async {
    if (_busy) return;
    final stage = _stage;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final pending = await widget.service.stage(widget.classId, stage);
      if (!mounted) return;
      setState(() {
        _issuePage = 1;
        _status = Future.value(pending);
      });
      if (!pending.canClose) {
        _message = pending.closed
            ? '$stage já está fechada.'
            : 'Confira os bloqueios de $stage antes de fechar.';
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Fechar $stage?'),
          content: const Text(
              'O fechamento é definitivo e bloqueia alterações nas avaliações e notas desta etapa.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirmar fechamento')),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
      await widget.service.close(widget.classId, stage);
      if (!mounted) return;
      _message = '$stage fechada pela API.';
      _refresh();
    } catch (error) {
      if (!mounted) return;
      _message = error is ApiException && error.statusCode == 409
          ? 'O fechamento não foi confirmado. Confira o estado e os bloqueios atualizados. ${error.message}'
          : teacherReviewError(error);
      _refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _points(String? value) => value?.replaceAll('.', ',') ?? '—';

  Widget _report(TeacherReportCard card, {bool detail = false}) {
    final (_, tone) = semesterResult(card.status);
    final text = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PersonTile(
            name: card.studentName,
            subtitle: card.average == null
                ? 'Média semestral ainda não disponível'
                : 'Média semestral: ${_points(card.average)}',
            badges: [AppBadge(label: card.statusLabel, tone: tone)],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final (name, stage) in [('N1', card.n1), ('N2', card.n2)]) ...[
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.xs),
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xxs,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(name, style: text.titleSmall),
                            StageStateBadge(closed: stage.closed),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Flexible(
                        child: Text(_points(stage.total),
                            textAlign: TextAlign.end,
                            style: text.titleMedium
                                ?.copyWith(color: AppColors.primary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    stage.applies
                        ? switch (stage.pendingCount) {
                            0 => 'Sem pendências',
                            1 => '1 pendência',
                            final count => '$count pendências',
                          }
                        : 'Não se aplica',
                    style: text.bodySmall?.copyWith(
                        color: stage.applies && stage.pendingCount > 0
                            ? AppColors.warning
                            : AppColors.inkMuted),
                  ),
                  if (detail) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    InfoLine(
                        label: 'Provas',
                        value: _points(stage.examPoints),
                        icon: LucideIcons.fileCheck),
                    InfoLine(
                        label: 'Atividades',
                        value: _points(stage.activityPoints),
                        icon: LucideIcons.clipboardList),
                  ],
                ],
              ),
            ),
          ],
          if (!detail)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: AppButtonStyles.link,
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _detail = widget.service
                              .studentReport(widget.classId, card.studentId);
                        }),
                icon: const Icon(LucideIcons.fileText, size: 18),
                label: const Text('Consultar boletim individual'),
              ),
            ),
        ],
      ),
    );
  }

  String _reason(String reason) => switch (reason) {
        'assessment_unavailable' => 'Avaliação indisponível',
        'draft_grade' => 'Nota em rascunho',
        _ => 'Nota publicada ausente',
      };

  String _blocker(String reason) => switch (reason) {
        'no_assessments' => 'Nenhuma avaliação vinculada à etapa.',
        'no_eligible_students' => 'Nenhum aluno elegível na oferta.',
        _ => 'Existem avaliações ou notas pendentes.',
      };

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionHeader(
        title: 'Boletim da oferta',
        subtitle: 'Fechamento das etapas N1 e N2',
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          style: AppButtonStyles.link,
          onPressed: _busy ? null : _refresh,
          icon: const Icon(LucideIcons.refreshCw, size: 18),
          label: const Text('Atualizar boletim e pendências'),
        ),
      ),
      const SizedBox(height: AppSpacing.xs),
      if (_message != null)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: StatusBanner(
              title: 'Fechamento', message: _message!, tone: AppBadgeTone.info),
        ),
      DropdownButtonFormField<String>(
        initialValue: _stage,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Etapa para fechamento'),
        items: const [
          DropdownMenuItem(value: 'N1', child: Text('N1')),
          DropdownMenuItem(value: 'N2', child: Text('N2')),
        ],
        onChanged: _busy
            ? null
            : (value) {
                _stage = value!;
                _message = null;
                _loadStage(1);
              },
      ),
      const SizedBox(height: AppSpacing.sm),
      FutureBuilder<AcademicStageStatus>(
        future: _status,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LinearProgressIndicator();
          }
          if (snapshot.hasError) {
            return Text(teacherReviewError(snapshot.error!));
          }
          final status = snapshot.requireData;
          return StageSummaryCard(
            title: status.stage,
            closed: status.closed,
            footer: status.closed
                ? null
                : FilledButton(
                    onPressed: !_busy && status.canClose ? _close : null,
                    child: Text('Fechar ${status.stage}'),
                  ),
            children: [
              InfoLine(
                  label: 'Alunos elegíveis',
                  value: '${status.eligibleCount}',
                  icon: LucideIcons.users),
              InfoLine(
                  label: 'Avaliações',
                  value: '${status.assessmentCount}',
                  icon: LucideIcons.clipboardList),
              for (final blocker in status.blockers)
                _Notice(
                    icon: LucideIcons.triangleAlert,
                    color: AppColors.warning,
                    text: _blocker(blocker)),
              for (final issue in status.issues.rows)
                _Notice(
                    icon: LucideIcons.circleAlert,
                    color: AppColors.danger,
                    text:
                        '${issue.title} • ${_reason(issue.reason)} • ${_names[issue.studentId] ?? 'Aluno ${issue.studentId}'}'),
              AcademicPageControls(
                  page: status.issues, onPage: _busy ? null : _loadStage),
            ],
          );
        },
      ),
      const SizedBox(height: AppSpacing.md),
      const SectionHeader(
          title: 'Resumo da turma', subtitle: 'Situação de cada aluno'),
      if (_detail != null) ...[
        TextButton(
          style: AppButtonStyles.link,
          onPressed: _busy ? null : () => setState(() => _detail = null),
          child: const Text('Voltar ao resumo da turma'),
        ),
        FutureBuilder<TeacherReportCard>(
          future: _detail,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const LinearProgressIndicator();
            }
            if (snapshot.hasError) {
              return Text(teacherReviewError(snapshot.error!));
            }
            return _report(snapshot.requireData, detail: true);
          },
        ),
      ] else
        FutureBuilder<AcademicPage<TeacherReportCard>>(
          future: _summary,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const LinearProgressIndicator();
            }
            if (snapshot.hasError) {
              return Text(teacherReviewError(snapshot.error!));
            }
            final page = snapshot.requireData;
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (page.rows.isEmpty)
                    const Text('Nenhum boletim nesta página.'),
                  for (final card in page.rows) _report(card),
                  AcademicPageControls(
                      page: page, onPage: _busy ? null : _loadSummary),
                ]);
          },
        ),
    ]);
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
                child:
                    Text(text, style: Theme.of(context).textTheme.bodySmall)),
          ],
        ),
      );
}
