import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_tokens.dart';
import 'app_badge.dart';

/// Kit alert: a status always pairs color with an icon and words.
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
    final (foreground, background) = badgeColors(tone);
    final text = Theme.of(context).textTheme;

    return Semantics(
      liveRegion: tone == AppBadgeTone.danger,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: foreground.withValues(alpha: .24)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon ?? _defaultIcon(tone), color: foreground, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: text.titleSmall?.copyWith(color: foreground),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: text.bodySmall?.copyWith(color: AppColors.ink),
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
      AppBadgeTone.success => LucideIcons.circleCheck,
      AppBadgeTone.warning => LucideIcons.triangleAlert,
      AppBadgeTone.danger => LucideIcons.circleAlert,
      AppBadgeTone.info => LucideIcons.info,
      AppBadgeTone.primary => LucideIcons.graduationCap,
      AppBadgeTone.neutral => LucideIcons.fileText,
    };
  }
}
