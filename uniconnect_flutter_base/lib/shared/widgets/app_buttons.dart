import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final loadingIcon = SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(
        strokeWidth: 2.4,
        color: Theme.of(context).colorScheme.onPrimary,
      ),
    );

    final button = isLoading
        ? ElevatedButton.icon(
            onPressed: null,
            icon: loadingIcon,
            label: Text(label),
          )
        : icon == null
            ? ElevatedButton(onPressed: onPressed, child: Text(label))
            : ElevatedButton.icon(
                onPressed: onPressed,
                icon: Icon(icon),
                label: Text(label),
              );

    return SizedBox(width: double.infinity, child: button);
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final button = icon == null
        ? OutlinedButton(onPressed: onPressed, child: Text(label))
        : OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
          );

    return SizedBox(width: double.infinity, child: button);
  }
}

class DestructiveButton extends StatelessWidget {
  const DestructiveButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.subtle = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Outlined in `danger` for actions that are not destructive, like
  /// signing out; the filled style is for actions that delete data.
  final bool subtle;

  @override
  Widget build(BuildContext context) {
    final style = subtle
        ? ElevatedButton.styleFrom(
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.danger,
            side: const BorderSide(color: AppColors.line),
          )
        : ElevatedButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: AppColors.onPrimary,
          );
    final button = icon == null
        ? ElevatedButton(
            onPressed: onPressed,
            style: style,
            child: Text(label),
          )
        : ElevatedButton.icon(
            onPressed: onPressed,
            style: style,
            icon: Icon(icon),
            label: Text(label),
          );

    return SizedBox(width: double.infinity, child: button);
  }
}
