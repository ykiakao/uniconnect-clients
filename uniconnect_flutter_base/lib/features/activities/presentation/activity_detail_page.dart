import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/bottom_nav.dart';
import '../../../shared/widgets/error_state_widget.dart';
import '../models/academic_activity.dart';
import '../providers/activity_provider.dart';

class ActivityDetailPage extends ConsumerWidget {
  const ActivityDetailPage({super.key, required this.activityId});

  final String activityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(activityByIdProvider(activityId));

    return activityAsync.when(
      loading: () => const Scaffold(
        appBar: AppHeader(
          title: 'Atividade',
          fallbackRoute: AppRoutes.activities,
        ),
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: const AppHeader(
          title: 'Atividade',
          fallbackRoute: AppRoutes.activities,
        ),
        body: ErrorStateWidget(
          error: error.toString(),
          onRetry: () => ref.invalidate(activityByIdProvider(activityId)),
        ),
      ),
      data: (activity) {
        if (activity == null) {
          return const Scaffold(
            appBar: AppHeader(
              title: 'Atividade',
              fallbackRoute: AppRoutes.activities,
            ),
            body: Center(child: Text('Atividade nao encontrada.')),
          );
        }

        return _ActivityDetailContent(activity: activity);
      },
    );
  }
}

class _ActivityDetailContent extends StatelessWidget {
  const _ActivityDetailContent({required this.activity});

  final AcademicActivity activity;

  @override
  Widget build(BuildContext context) {
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
              activity.subject.toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .8,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              activity.title,
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
                    value: '10.0 pontos',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionLabel('Instrucoes da atividade'),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    activity.description.isEmpty
                        ? 'Leia as orientacoes da disciplina antes de iniciar.'
                        : activity.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.muted,
                          height: 1.45,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (final criterion in activity.criteria)
                    _ChecklistItem(text: criterion),
                  if (activity.criteria.isEmpty) ...const [
                    _ChecklistItem(text: 'Revise o conteudo da aula.'),
                    _ChecklistItem(text: 'Prepare sua entrega com clareza.'),
                    _ChecklistItem(
                        text: 'Confira os arquivos antes de enviar.'),
                  ],
                ],
              ),
            ),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionLabel('Material de apoio'),
                  const SizedBox(height: AppSpacing.md),
                  if (activity.attachments.isEmpty)
                    const Text(
                      'Nenhum material anexo para esta atividade.',
                      style: TextStyle(color: AppColors.muted),
                    )
                  else
                    ...activity.attachments.map(
                      (attachment) => _MaterialItem(
                        icon: Icons.insert_drive_file_outlined,
                        title: attachment,
                        subtitle: 'Material da atividade',
                      ),
                    ),
                ],
              ),
            ),
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
                        const _SectionLabel('Professor responsavel'),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          activity.teacher,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SecondaryButton(
              icon: Icons.chat_bubble_outline,
              label: 'Enviar mensagem',
              onPressed: () {},
            ),
            const SizedBox(height: AppSpacing.sm),
            PrimaryButton(
              icon: Icons.play_arrow_rounded,
              label: 'Realizar atividade',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Atividade iniciada.')),
                );
              },
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
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
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
