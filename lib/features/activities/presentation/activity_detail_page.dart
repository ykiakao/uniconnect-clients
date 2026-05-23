import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/bottom_nav.dart';
import '../../../shared/widgets/info_card.dart';
import '../providers/activity_provider.dart';
import '../widgets/activity_detail_items.dart';
import '../widgets/priority_badge.dart';

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
            Align(
              alignment: Alignment.centerLeft,
              child: PriorityBadge(priority: activity.priority),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              activity.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              activity.subject,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: AppSpacing.lg),
            InfoCard(
              icon: Icons.event_outlined,
              title: 'Prazo final',
              subtitle: activity.dueLabel,
              color: AppColors.secondary,
            ),
            AppCard(
              child: Text(
                activity.description,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            AppCard(
              child: _DetailSection(
                title: 'Critérios',
                children: activity.criteria
                    .map((criterion) => CriteriaItem(label: criterion))
                    .toList(),
              ),
            ),
            AppCard(
              child: _DetailSection(
                title: 'Anexos',
                emptyText: 'Nenhum anexo publicado.',
                children: activity.attachments
                    .map((attachment) => AttachmentItem(fileName: attachment))
                    .toList(),
              ),
            ),
            InfoCard(
              icon: Icons.person_outline,
              title: activity.teacher,
              subtitle: 'Professor responsável',
              color: AppColors.primary,
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              icon: Icons.task_alt,
              label: 'Marcar como concluída',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Atividade marcada como concluída.'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.children,
    this.emptyText,
  });

  final String title;
  final List<Widget> children;
  final String? emptyText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (children.isEmpty)
          Text(
            emptyText ?? 'Nenhum item disponível.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.muted,
                ),
          )
        else
          ...children,
      ],
    );
  }
}
