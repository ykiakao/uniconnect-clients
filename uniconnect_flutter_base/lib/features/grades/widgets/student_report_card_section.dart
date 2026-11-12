import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/academic_blocks.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/error_state_widget.dart';
import '../../../shared/widgets/section_header.dart';
import '../models/student_report_card.dart';
import '../providers/student_report_card_provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class StudentReportCardSection extends ConsumerWidget {
  const StudentReportCardSection({super.key, required this.session});

  final StudentReportSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offeringsProvider = studentReportOfferingsProvider(session);
    final selection = ref.watch(studentReportSelectionProvider);
    final offerings = ref.watch(offeringsProvider);
    ref.listen(offeringsProvider, (_, next) {
      if (next.isLoading ||
          next.hasError ||
          ref.read(studentReportSessionProvider) != session) {
        return;
      }
      if (next.asData case final data?) {
        ref.read(studentReportSelectionProvider.notifier).reconcile(data.value);
      }
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Boletim acadêmico N1/N2'),
        offerings.when(
          skipLoadingOnRefresh: false,
          skipLoadingOnReload: false,
          loading: () => const _ReportLoading('Carregando disciplinas…'),
          error: (error, _) => ErrorStateWidget(
            title: 'Não foi possível carregar suas disciplinas',
            error: _errorMessage(error),
            onRetry: () => ref.invalidate(offeringsProvider),
          ),
          data: (rows) {
            if (rows.isEmpty) {
              return const EmptyStateWidget(
                icon: LucideIcons.graduationCap,
                title: 'Nenhuma disciplina disponível',
                subtitle: 'As ofertas autorizadas aparecerão nesta lista.',
              );
            }
            return _offerings(ref, rows, selection);
          },
        ),
      ],
    );
  }

  Widget _offerings(
      WidgetRef ref, List<StudentReportOffering> rows, String? selection) {
    final selected = rows.length == 1
        ? rows.single.id
        : rows.any((row) => row.id == selection)
            ? selection
            : null;
    final reportProvider = selected == null
        ? null
        : studentReportCardProvider((session, selected));
    final counts = <String, int>{};
    for (final row in rows) {
      final name = row.name.trim().toLowerCase();
      counts[name] = (counts[name] ?? 0) + 1;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey(selected),
          initialValue: selected,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Disciplina ou oferta'),
          items: rows.map((row) {
            final duplicate = counts[row.name.trim().toLowerCase()]! > 1;
            return DropdownMenuItem(
              value: row.id,
              child: Text(
                duplicate ? '${row.name} • Oferta ${row.id}' : row.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (ref.read(studentReportSessionProvider) == session) {
              ref.read(studentReportSelectionProvider.notifier).select(value);
            }
          },
        ),
        if (reportProvider == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text('Selecione uma oferta para consultar o boletim.'),
          )
        else ...[
          const SizedBox(height: AppSpacing.sm),
          TextButton.icon(
            onPressed: () => ref.invalidate(reportProvider),
            icon: const Icon(LucideIcons.refreshCw),
            label: const Text('Atualizar boletim'),
          ),
          ref.watch(reportProvider).when(
                skipLoadingOnRefresh: false,
                skipLoadingOnReload: false,
                loading: () => const _ReportLoading('Carregando boletim…'),
                error: (error, _) => ErrorStateWidget(
                  title: 'Não foi possível carregar o boletim',
                  error: _errorMessage(error),
                  onRetry: () => ref.invalidate(reportProvider),
                ),
                data: (card) => _ReportResults(card: card),
              ),
        ],
      ],
    );
  }
}

String _errorMessage(Object error) {
  if (error is ApiException) {
    if (error.statusCode == 401) return 'Sessão expirada. Entre novamente.';
    if (error.statusCode == 403 || error.statusCode == 404) {
      return 'O boletim não está disponível para seu vínculo acadêmico.';
    }
    if (error.statusCode == null) {
      if (error.message.startsWith('Não foi possível conectar à API.')) {
        return 'Confira sua conexão e tente novamente.';
      }
      return 'A API retornou uma resposta acadêmica inválida.';
    }
  }
  return 'A consulta está indisponível. Tente novamente.';
}

class _ReportLoading extends StatelessWidget {
  const _ReportLoading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Column(children: [
        const LinearProgressIndicator(),
        const SizedBox(height: AppSpacing.sm),
        Text(label),
      ]);
}

class _ReportResults extends StatelessWidget {
  const _ReportResults({required this.card});

  final StudentReportCard card;

  @override
  Widget build(BuildContext context) {
    if (!card.hasAssessments) {
      return const EmptyStateWidget(
        icon: LucideIcons.clipboardList,
        title: 'Oferta sem avaliações no boletim',
        subtitle: 'Quando houver avaliações N1/N2, elas aparecerão aqui.',
      );
    }
    final (result, tone) = switch (card.status) {
      ReportCardStatus.partial => (
          'Resultado semestral parcial',
          AppBadgeTone.neutral
        ),
      ReportCardStatus.approved => ('Aprovado', AppBadgeTone.success),
      ReportCardStatus.finalExamEligible => (
          'Elegível à prova final',
          AppBadgeTone.warning
        ),
      ReportCardStatus.belowMinimum => (
          'Abaixo da média mínima',
          AppBadgeTone.danger
        ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StageCard(name: 'N1', stage: card.n1),
        _StageCard(name: 'N2', stage: card.n2),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const IconTile(icon: LucideIcons.award, size: 36),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text('Resultado semestral',
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (card.average != null)
                InfoLine(
                    label: 'Média semestral',
                    value: _points(card.average),
                    strong: true),
              const SizedBox(height: AppSpacing.xs),
              Align(
                alignment: Alignment.centerLeft,
                child: AppBadge(label: result, tone: tone),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _points(String? value) => formatPoints(value, missing: 'Não disponível');

class _StageCard extends StatelessWidget {
  const _StageCard({required this.name, required this.stage});

  final String name;
  final StudentReportStage stage;

  @override
  Widget build(BuildContext context) => StageSummaryCard(
        title: name,
        closed: stage.closed,
        footer: stage.applies ? PendingBadge(count: stage.pendingCount) : null,
        children: !stage.applies
            ? [
                Text('Esta etapa não se aplica ao seu vínculo.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.inkMuted)),
              ]
            : [
                InfoLine(
                    label: 'Pontos de trabalhos',
                    value: _points(stage.activityPoints),
                    icon: LucideIcons.clipboardList),
                InfoLine(
                    label: 'Pontos de provas',
                    value: _points(stage.examPoints),
                    icon: LucideIcons.fileCheck),
                const Divider(height: AppSpacing.md),
                InfoLine(
                  label: switch (stage.status) {
                    ReportStageStatus.pending => 'Total',
                    ReportStageStatus.partial => 'Total parcial',
                    ReportStageStatus.definitive => 'Total definitivo',
                  },
                  value: stage.status == ReportStageStatus.pending
                      ? 'Não disponível'
                      : _points(stage.total),
                  strong: true,
                ),
              ],
      );
}
