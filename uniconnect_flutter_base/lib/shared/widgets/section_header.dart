import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'app_button_styles.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: Text(title, style: text.titleLarge)),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: text.bodySmall?.copyWith(color: AppColors.inkMuted),
          ),
        ],
      ],
    );
    final action = actionLabel != null && onAction != null
        ? TextButton(
            style: AppButtonStyles.link,
            onPressed: onAction,
            child: Text(actionLabel!),
          )
        : null;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs, bottom: AppSpacing.sm),
      child: LayoutBuilder(builder: (context, constraints) {
        final narrow = constraints.maxWidth <
            280 * MediaQuery.textScalerOf(context).scale(1);
        if (action == null) return heading;
        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [heading, const SizedBox(height: AppSpacing.xxs), action],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: heading),
            const SizedBox(width: AppSpacing.xs),
            action,
          ],
        );
      }),
    );
  }
}
