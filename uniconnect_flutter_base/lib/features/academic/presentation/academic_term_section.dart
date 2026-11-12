import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/section_header.dart';
import '../demo/synthetic_academic_providers.dart';
import '../providers/academic_records_providers.dart';

class AcademicTermSection extends ConsumerWidget {
  const AcademicTermSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final isDemo = ref.watch(syntheticDemoEnabledProvider);
    final dateFormat = DateFormat('dd/MM/yyyy');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Período letivo'),
        if (isDemo)
          const AppCard(
              child: Text(
                  'Datas do período não disponíveis no modo de demonstração.'))
        else
          ref.watch(academicTermDatesProvider).when(
                skipLoadingOnReload: false,
                loading: () => const LinearProgressIndicator(
                    semanticsLabel: 'Carregando período letivo'),
                error: (error, _) => AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(academicRecordsErrorText(error)),
                      TextButton(
                        onPressed: () =>
                            ref.invalidate(academicTermDatesProvider),
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                ),
                data: (terms) => terms.isEmpty
                    ? const AppCard(
                        child: Text('Nenhum período letivo ativo disponível.'))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final term in terms)
                            AppCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(term.period.label,
                                      style: text.titleSmall),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                      'Início: ${term.startDate == null ? 'Não informado' : dateFormat.format(term.startDate!)}'),
                                  Text(
                                      'Fim: ${term.endDate == null ? 'Não informado' : dateFormat.format(term.endDate!)}'),
                                ],
                              ),
                            ),
                        ],
                      ),
              ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Horários semanais e eventos institucionais ainda indisponíveis.',
          style: text.bodySmall?.copyWith(color: AppColors.inkMuted),
        ),
      ],
    );
  }
}
