import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

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
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w900)),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(subtitle!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.muted)),
        ],
      ],
    );
    final action = actionLabel != null && onAction != null
        ? TextButton(onPressed: onAction, child: Text(actionLabel!))
        : null;
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 10),
      child: LayoutBuilder(builder: (context, constraints) {
        final narrow = constraints.maxWidth <
            360 * MediaQuery.textScalerOf(context).scale(1);
        if (action == null) return heading;
        if (narrow) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                heading,
                const SizedBox(height: AppSpacing.xxs),
                action,
              ]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: heading),
          const SizedBox(width: AppSpacing.xs),
          action,
        ]);
      }),
    );
  }
}
