import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../providers/auth_provider.dart';

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
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 18,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(Icons.school, color: Colors.white, size: 34),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'UniConnect',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}
