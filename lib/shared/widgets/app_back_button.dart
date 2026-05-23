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
