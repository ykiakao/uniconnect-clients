import 'package:flutter/material.dart';

import '../../../shared/widgets/app_badge.dart';
import '../models/academic_activity.dart';

class PriorityBadge extends StatelessWidget {
  const PriorityBadge({super.key, required this.priority});

  final ActivityPriority priority;

  @override
  Widget build(BuildContext context) {
    final (label, tone, icon) = switch (priority) {
      ActivityPriority.critical => (
          'URGENTE',
          AppBadgeTone.danger,
          Icons.priority_high,
        ),
      ActivityPriority.medium => (
          'MEDIA',
          AppBadgeTone.warning,
          Icons.schedule,
        ),
      ActivityPriority.low => (
          'BAIXA',
          AppBadgeTone.success,
          Icons.check_circle_outline,
        ),
    };

    return AppBadge(label: label, tone: tone, icon: icon, compact: true);
  }
}
