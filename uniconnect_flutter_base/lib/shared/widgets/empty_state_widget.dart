import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'app_card.dart';

class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
    this.actionLabel,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? action;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    return StateLayout(
      tile: IconTile(icon: icon, size: 48),
      title: title,
      message: subtitle,
      action: action != null && actionLabel != null
          ? ElevatedButton(onPressed: action, child: Text(actionLabel!))
          : null,
    );
  }
}

/// Centered icon, title, message and optional action: shared by the empty
/// and error states.
class StateLayout extends StatelessWidget {
  const StateLayout({
    super.key,
    required this.tile,
    required this.title,
    required this.message,
    this.action,
  });

  final Widget tile;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                tile,
                const SizedBox(height: AppSpacing.md),
                Text(title,
                    style: text.titleMedium, textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  message,
                  style: text.bodyMedium?.copyWith(color: AppColors.inkMuted),
                  textAlign: TextAlign.center,
                ),
                if (action != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  action!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
