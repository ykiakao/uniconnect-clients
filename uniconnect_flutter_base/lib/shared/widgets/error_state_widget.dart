import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import 'app_card.dart';
import 'empty_state_widget.dart';

class ErrorStateWidget extends StatelessWidget {
  const ErrorStateWidget({
    required this.error,
    required this.onRetry,
    this.title = 'Algo deu errado',
    super.key,
  });

  final String error;
  final String title;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return StateLayout(
      tile: const IconTile(
        icon: LucideIcons.circleAlert,
        color: AppColors.danger,
        background: AppColors.dangerTint,
        size: 48,
      ),
      title: title,
      message: error,
      action: OutlinedButton.icon(
        onPressed: onRetry,
        icon: const Icon(LucideIcons.refreshCw),
        label: const Text('Tentar novamente'),
      ),
    );
  }
}
