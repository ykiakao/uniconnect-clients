import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/bottom_nav.dart';
import '../providers/activity_provider.dart';
import '../widgets/priority_badge.dart';

class ActivityDetailPage extends ConsumerWidget {
  const ActivityDetailPage({super.key, required this.activityId});

  final String activityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(activityByIdProvider(activityId));

    if (activity == null) {
      return Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(fallbackRoute: AppRoutes.activities),
          title: const Text('Atividade'),
        ),
        body: const Center(child: Text('Atividade não encontrada.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackRoute: AppRoutes.activities),
        title: const Text('Detalhes da atividade'),
      ),
      bottomNavigationBar: const UniBottomNav(currentIndex: 1),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: PriorityBadge(priority: activity.priority),
          ),
          const SizedBox(height: 10),
          Text(
            activity.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            activity.subject,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 18),
          AppCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event, color: AppColors.secondary),
              title: const Text('Prazo final'),
              subtitle: Text(activity.dueLabel),
            ),
          ),
          AppCard(
            child: Text(activity.description),
          ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Critérios',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 8),
                ...activity.criteria.map(
                  (criterion) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(criterion)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Anexos',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 8),
                if (activity.attachments.isEmpty)
                  const Text('Nenhum anexo publicado.')
                else
                  ...activity.attachments.map(
                    (attachment) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.attach_file),
                      title: Text(attachment),
                    ),
                  ),
              ],
            ),
          ),
          AppCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: AppColors.primary,
                child: Icon(Icons.person_outline, color: Colors.white),
              ),
              title: Text(activity.teacher),
              subtitle: const Text('Professor responsável'),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Atividade marcada como concluída.'),
                ),
              );
            },
            icon: const Icon(Icons.task_alt),
            label: const Text('Marcar como concluída'),
          ),
          const SizedBox(height: 10),
          const AppBackTextButton(fallbackRoute: AppRoutes.activities),
        ],
      ),
    );
  }
}
