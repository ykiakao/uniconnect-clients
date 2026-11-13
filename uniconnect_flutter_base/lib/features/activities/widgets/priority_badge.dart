import 'package:flutter/material.dart';

import '../../../shared/widgets/app_badge.dart';
import '../models/academic_activity.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class PriorityBadge extends StatelessWidget {
  const PriorityBadge({super.key, required this.priority});

  final ActivityPriority priority;

  @override
  Widget build(BuildContext context) {
    final (label, tone, icon) = switch (priority) {
      ActivityPriority.critical => (
          'Crítica',
          AppBadgeTone.danger,
          LucideIcons.flag,
        ),
      ActivityPriority.medium => (
          'Média',
          AppBadgeTone.warning,
          LucideIcons.clock,
        ),
      ActivityPriority.low => (
          'Baixa',
          AppBadgeTone.success,
          LucideIcons.circleCheck,
        ),
      ActivityPriority.expired => (
          'Expirada',
          AppBadgeTone.neutral,
          LucideIcons.calendarX,
        ),
      ActivityPriority.noDeadline => (
          'Sem prazo',
          AppBadgeTone.neutral,
          LucideIcons.calendar,
        ),
    };

    return AppBadge(label: label, tone: tone, icon: icon, compact: true);
  }
}
