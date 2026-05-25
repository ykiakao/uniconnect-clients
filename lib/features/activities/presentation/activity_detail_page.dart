import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/bottom_nav.dart';
import '../providers/activity_provider.dart';

class ActivityDetailPage extends ConsumerWidget {
  const ActivityDetailPage({super.key, required this.activityId});

  final String activityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(activityByIdProvider(activityId));

    if (activity == null) {
      return const Scaffold(
        appBar: AppHeader(
          title: 'Atividade',
          fallbackRoute: AppRoutes.activities,
        ),
        body: Center(child: Text('Atividade não encontrada.')),
      );
    }

    return Scaffold(
      appBar: const AppHeader(
        title: 'Detalhes da atividade',
        fallbackRoute: AppRoutes.activities,
      ),
      bottomNavigationBar: const UniBottomNav(currentIndex: 1),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          children: [
            Text(
              '${activity.subject.toUpperCase()} • MÓDULO 4',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .8,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              activity.title == 'Trabalho vence em 2 dias'
                  ? 'Padrões de Projeto e Microserviços: Estudo de Caso Avançado'
                  : activity.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    height: 1.12,
                  ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: _InfoPill(
                    icon: Icons.event_outlined,
                    label: 'Prazo',
                    value: activity.dueLabel,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Expanded(
                  child: _InfoPill(
                    icon: Icons.workspace_premium_outlined,
                    label: 'Valor',
                    value: '10.0 Pontos',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionLabel('Instruções da Atividade'),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    activity.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.muted,
                          height: 1.45,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const _ChecklistItem(
                    text:
                        'Identifique três gargalos de escalabilidade no diagrama anexo.',
                  ),
                  const _ChecklistItem(
                    text:
                        'Proponha a aplicação do padrão Circuit Breaker para serviços críticos.',
                  ),
                  const _ChecklistItem(
                    text:
                        'Elabore um relatório técnico em PDF (máximo 5 páginas).',
                  ),
                ],
              ),
            ),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionLabel('Material de Apoio'),
                  const SizedBox(height: AppSpacing.md),
                  ...activity.attachments.map(
                    (attachment) => _MaterialItem(
                      icon: Icons.picture_as_pdf_outlined,
                      title: attachment,
                      subtitle: 'Guia de padrões de projeto (4.2 MB)',
                    ),
                  ),
                  const _MaterialItem(
                    icon: Icons.play_circle_outline,
                    title: 'Vídeo Aula: Resiliência',
                    subtitle: 'Assista antes de começar (15 min)',
                  ),
                ],
              ),
            ),
            const _CountdownCard(),
            AppCard(
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.primary,
                    child: Icon(Icons.person_outline, color: Colors.white),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionLabel('PROFESSOR RESPONSÁVEL'),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          activity.teacher,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                        const Text(
                          'PhD em Engenharia de Software',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SecondaryButton(
              icon: Icons.chat_bubble_outline,
              label: 'Enviar Mensagem',
              onPressed: () {},
            ),
            const SizedBox(height: AppSpacing.sm),
            PrimaryButton(
              icon: Icons.play_arrow_rounded,
              label: 'Realizar Atividade',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Atividade iniciada.')),
                );
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Ao iniciar, você terá uma tentativa única para submissão dos arquivos.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Icon(icon, color: AppColors.secondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownCard extends StatelessWidget {
  const _CountdownCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      backgroundColor: AppColors.primary,
      child: Column(
        children: [
          Text(
            'CONTAGEM REGRESSIVA',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .8,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _TimeBlock(value: '03', label: 'DIAS'),
              _TimeBlock(value: '14', label: 'HORAS'),
              _TimeBlock(value: '42', label: 'MIN'),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Atividade expira em 25/10 às 23:59',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _TimeBlock extends StatelessWidget {
  const _TimeBlock({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white70,
                fontWeight: FontWeight.w900,
              ),
        ),
      ],
    );
  }
}

class _MaterialItem extends StatelessWidget {
  const _MaterialItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                Text(
                  subtitle,
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistItem extends StatelessWidget {
  const _ChecklistItem({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: .5,
          ),
    );
  }
}
