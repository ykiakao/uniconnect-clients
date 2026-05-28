import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_tokens.dart';
import 'app_badge.dart';

class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    required this.title,
    required this.message,
    this.tone = AppBadgeTone.info,
    this.icon,
    this.action,
  });

  final String title;
  final String message;
  final AppBadgeTone tone;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = _toneColors(tone);

    return Semantics(
      liveRegion: tone == AppBadgeTone.danger,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: colors.$2,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: colors.$1.withValues(alpha: .26)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon ?? _defaultIcon(tone), color: colors.$1, size: 22),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: colors.$1,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.$1,
                          height: 1.35,
                        ),
                  ),
                  if (action != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    action!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _defaultIcon(AppBadgeTone tone) {
    return switch (tone) {
      AppBadgeTone.success => Icons.check_circle_outline,
      AppBadgeTone.warning => Icons.warning_amber_outlined,
      AppBadgeTone.danger => Icons.error_outline,
      AppBadgeTone.info => Icons.info_outline,
      AppBadgeTone.primary => Icons.school_outlined,
      AppBadgeTone.neutral => Icons.notes_outlined,
    };
  }

  (Color, Color) _toneColors(AppBadgeTone tone) {
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
