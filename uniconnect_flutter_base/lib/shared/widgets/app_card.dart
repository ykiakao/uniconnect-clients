import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_tokens.dart';

/// Kit `Card`: `surface-raised`, `line` border, `shadow-sm` and `radius-lg`.
///
/// The optional header mirrors the web card: an uppercase [eyebrow], an
/// [icon] in a `primary-tint` square and a [title]. When [onTap] is set the
/// whole card is the action, so it should not hold other buttons.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.cardPadding),
    this.onTap,
    this.accentColor,
    this.backgroundColor,
    this.eyebrow,
    this.title,
    this.icon,
    this.trailing,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? accentColor;
  final Color? backgroundColor;
  final String? eyebrow;
  final String? title;
  final IconData? icon;
  final Widget? trailing;

  bool get _hasHeader => title != null || eyebrow != null;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.lg);
    final body = _hasHeader
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _CardHeader(
                eyebrow: eyebrow,
                title: title,
                icon: icon,
                trailing: trailing,
              ),
              const SizedBox(height: AppSpacing.md),
              child,
            ],
          )
        : child;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: AppShadows.card,
        ),
        child: Material(
          color: backgroundColor ?? AppColors.surfaceRaised,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: const BorderSide(color: AppColors.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                if (accentColor != null)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: ColoredBox(
                      color: accentColor!,
                      child: const SizedBox(width: 4),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: Padding(padding: padding, child: body),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({this.eyebrow, this.title, this.icon, this.trailing});

  final String? eyebrow;
  final String? title;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        if (icon != null) ...[
          IconTile(icon: icon!),
          const SizedBox(width: AppSpacing.sm),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null)
                Text(
                  eyebrow!.toUpperCase(),
                  style: text.labelSmall?.copyWith(color: AppColors.inkMuted),
                ),
              if (title != null) Text(title!, style: text.titleMedium),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.xs),
          trailing!,
        ],
      ],
    );
  }
}

/// Icon on a soft square, as in the kit card header and list items.
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    this.color = AppColors.primary,
    this.background = AppColors.primaryTint,
    this.size = AppSizes.iconTile,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }
}
