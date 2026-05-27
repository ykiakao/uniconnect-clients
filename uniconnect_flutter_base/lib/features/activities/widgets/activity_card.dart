import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_card.dart';
import '../models/academic_activity.dart';
import 'priority_badge.dart';

class ActivityCard extends StatelessWidget {
  const ActivityCard({
    super.key,
    required this.activity,
    this.onTap,
    this.compact = false,
  });

  final AcademicActivity activity;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final priorityColor = switch (activity.priority) {
      ActivityPriority.critical => AppColors.danger,
      ActivityPriority.medium => AppColors.warning,
      ActivityPriority.low => AppColors.success,
    };

    return AppCard(
      onTap: onTap,
      accentColor: priorityColor,
      padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  activity.subject,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              PriorityBadge(priority: activity.priority),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            activity.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          if (!compact) ...[
            const SizedBox(height: 6),
            Text(
              activity.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.muted,
                  ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.event_outlined, size: 18, color: priorityColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  activity.dueLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ],
      ),
    );
  }
}
