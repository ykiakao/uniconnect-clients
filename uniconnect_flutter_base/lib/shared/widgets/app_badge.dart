import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

enum AppBadgeTone { primary, success, warning, danger, info, neutral }

/// Kit `Badge`: one or two words of status; the text carries the meaning.
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.tone = AppBadgeTone.primary,
    this.icon,
    this.compact = false,
  });

  final String label;
  final AppBadgeTone tone;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (foreground, background) = badgeColors(tone);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: foreground,
                    letterSpacing: 0,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Foreground and background for each tone, shared by badges and alerts.
(Color, Color) badgeColors(AppBadgeTone tone) {
  return switch (tone) {
    AppBadgeTone.primary => (AppColors.primary, AppColors.primaryTint),
    AppBadgeTone.info => (AppColors.primary, AppColors.primaryTint),
    AppBadgeTone.success => (AppColors.success, AppColors.successTint),
    AppBadgeTone.warning => (AppColors.warning, AppColors.warningTint),
    AppBadgeTone.danger => (AppColors.danger, AppColors.dangerTint),
    AppBadgeTone.neutral => (AppColors.inkMuted, AppColors.surface200),
  };
}
