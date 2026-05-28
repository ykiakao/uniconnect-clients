import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_tokens.dart';

enum AppBadgeTone { primary, success, warning, danger, info, neutral }

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
    final colors = _badgeColors(tone);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.xs : AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.$2,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: colors.$1),
            const SizedBox(width: AppSpacing.xxs),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.$1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .3,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color) _badgeColors(AppBadgeTone tone) {
    return switch (tone) {
      AppBadgeTone.primary => (AppColors.primary, AppColors.primarySoft),
      AppBadgeTone.success => (AppColors.success, AppColors.successSoft),
      AppBadgeTone.warning => (AppColors.warning, AppColors.warningSoft),
      AppBadgeTone.danger => (AppColors.danger, AppColors.dangerSoft),
      AppBadgeTone.info => (AppColors.info, AppColors.infoSoft),
      AppBadgeTone.neutral => (AppColors.muted, AppColors.background),
    };
  }
}
