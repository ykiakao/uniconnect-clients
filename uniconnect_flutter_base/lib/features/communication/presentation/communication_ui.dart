import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_routes.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../auth/models/app_user.dart';
import '../models/communication_models.dart';

final _dateFormat = DateFormat('dd/MM/yyyy • HH:mm');

String formatCommunicationDate(DateTime date) => _dateFormat.format(date);

String homeRouteFor(UserRole? role) => role == UserRole.teacher
    ? AppRoutes.teacherDashboard
    : AppRoutes.studentDashboard;

String chatRouteFor(UserRole? role) =>
    role == UserRole.teacher ? AppRoutes.teacherChat : AppRoutes.chat;

class NoticePriorityBadge extends StatelessWidget {
  const NoticePriorityBadge({super.key, required this.priority});

  final NoticePriority priority;

  @override
  Widget build(BuildContext context) => AppBadge(
        label: 'Prioridade ${priority.label.toLowerCase()}',
        tone: switch (priority) {
          NoticePriority.high => AppBadgeTone.danger,
          NoticePriority.medium => AppBadgeTone.warning,
          NoticePriority.low => AppBadgeTone.neutral,
        },
      );
}
