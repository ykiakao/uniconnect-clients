import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

class HelpTooltip extends StatelessWidget {
  const HelpTooltip({
    required this.message,
    required this.child,
    this.icon = Icons.info_outlined,
    super.key,
  });

  final String message;
  final Widget child;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: message,
      preferBelow: true,
      child: child,
    );
  }
}

class InlineHelp extends StatefulWidget {
  const InlineHelp({
    required this.message,
    required this.child,
    super.key,
  });

  final String message;
  final Widget child;

  @override
  State<InlineHelp> createState() => _InlineHelpState();
}

class _InlineHelpState extends State<InlineHelp> {
  bool _showHelp = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: widget.child),
            const SizedBox(width: AppSpacing.sm),
            GestureDetector(
              onTap: () => setState(() => _showHelp = !_showHelp),
              child: Icon(
                _showHelp ? Icons.help : Icons.help_outline,
                size: 18,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        if (_showHelp) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Text(
              widget.message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.primaryDark,
                  ),
            ),
          ),
        ],
      ],
    );
  }
}

class ContextualTip extends StatelessWidget {
  const ContextualTip({
    required this.title,
    required this.message,
    this.icon = Icons.lightbulb_outline,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.infoSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: AppColors.info,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.info,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.info,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
