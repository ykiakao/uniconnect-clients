import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/academic_activity.dart';

class PriorityBadge extends StatelessWidget {
  const PriorityBadge({super.key, required this.priority});

  final ActivityPriority priority;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (priority) {
      ActivityPriority.critical => (
          'URGENTE',
          AppColors.danger,
          Icons.priority_high
        ),
      ActivityPriority.medium => ('MÉDIA', AppColors.warning, Icons.schedule),
      ActivityPriority.low => (
          'BAIXA',
          AppColors.success,
          Icons.check_circle_outline
        ),
    };

    return Chip(
      avatar: Icon(icon, color: color, size: 18),
      label: Text(label),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w900),
      backgroundColor: switch (priority) {
        ActivityPriority.critical => AppColors.dangerSoft,
        ActivityPriority.medium => AppColors.warningSoft,
        ActivityPriority.low => AppColors.successSoft,
      },
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }
}
