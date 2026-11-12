import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

/// Button styles that keep actions aligned with the content around them.
class AppButtonStyles {
  /// Text action with no side padding, so its label lines up with the text
  /// above it (the web `link` button). The height keeps the touch target.
  static final link = TextButton.styleFrom(
    padding: EdgeInsets.zero,
    minimumSize: const Size(0, AppSizes.buttonHeight),
    alignment: Alignment.centerLeft,
  );

  /// Bordered, compact action for rows of actions inside a card: its edge
  /// lines up with the card content and every action has the same height.
  static ButtonStyle compact({Color foreground = AppColors.primary}) {
    return TextButton.styleFrom(
      foregroundColor: foreground,
      backgroundColor: AppColors.surface,
      side: const BorderSide(color: AppColors.line),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      minimumSize: const Size(0, 40),
      textStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    );
  }
}
