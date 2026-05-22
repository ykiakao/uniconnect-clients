import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppBackButton extends StatelessWidget {
  const AppBackButton({
    super.key,
    required this.fallbackRoute,
    this.tooltip = 'Voltar',
  });

  final String fallbackRoute;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: () => _goBack(context),
      icon: const Icon(Icons.arrow_back),
    );
  }

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }

    context.go(fallbackRoute);
  }
}

class AppBackTextButton extends StatelessWidget {
  const AppBackTextButton({
    super.key,
    required this.fallbackRoute,
    this.label = 'Voltar',
  });

  final String fallbackRoute;
  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => _goBack(context),
      icon: const Icon(Icons.arrow_back),
      label: Text(label),
    );
  }

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }

    context.go(fallbackRoute);
  }
}

class AppBackAction extends StatelessWidget {
  const AppBackAction({
    super.key,
    required this.fallbackRoute,
    this.label = 'Voltar',
  });

  final String fallbackRoute;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AppBackTextButton(
          fallbackRoute: fallbackRoute,
          label: label,
        ),
      ),
    );
  }
}
