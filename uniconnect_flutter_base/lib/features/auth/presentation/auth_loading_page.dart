import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../providers/auth_provider.dart';
import '../../../shared/widgets/brand_logo.dart';

class AuthLoadingPage extends ConsumerWidget {
  const AuthLoadingPage({super.key, this.showRetry = false});

  final bool showRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (showRetry) {
      final controller = ref.read(authControllerProvider.notifier);
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Não foi possível renovar a sessão.'),
                  FilledButton(
                    onPressed: controller.retryRenewal,
                    child: const Text('Tentar novamente'),
                  ),
                  TextButton(
                    onPressed: controller.logout,
                    child: const Text('Sair'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LoadingBrandMark(),
              SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingBrandMark extends StatelessWidget {
  const _LoadingBrandMark();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Restaurando sessão',
      child: const BrandLogo(height: 80),
    );
  }
}
