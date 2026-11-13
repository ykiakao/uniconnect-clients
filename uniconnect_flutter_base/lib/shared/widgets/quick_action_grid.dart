import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_tokens.dart';
import 'app_card.dart';

/// One shortcut of the home screens; every item has a real destination.
typedef QuickActionItem = ({
  IconData icon,
  String label,
  VoidCallback onTap,
});

/// Two-column grid of shortcut cards shared by the student and teacher
/// home screens (one column with large text or narrow screens).
class QuickActionGrid extends StatelessWidget {
  const QuickActionGrid({super.key, required this.items});

  final List<QuickActionItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(1);
      final columns = constraints.maxWidth >= 300 * scale ? 2 : 1;
      final width =
          (constraints.maxWidth - AppSpacing.md * (columns - 1)) / columns;
      return Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        children: [
          for (final item in items)
            SizedBox(width: width, child: _QuickActionCard(item: item)),
        ],
      );
    });
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({required this.item});

  final QuickActionItem item;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.lg);
    return DecoratedBox(
      decoration:
          BoxDecoration(borderRadius: radius, boxShadow: AppShadows.card),
      child: Material(
        color: AppColors.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: const BorderSide(color: AppColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: item.onTap,
          child: Semantics(
            button: true,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 112),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconTile(icon: item.icon, size: 36),
                    const SizedBox(height: AppSpacing.sm),
                    Text(item.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
