import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import 'error_state_widget.dart';

class LoadingState<T> extends StatelessWidget {
  const LoadingState({
    required this.asyncValue,
    required this.onData,
    this.onLoading,
    this.onError,
    this.retryCallback,
    super.key,
  });

  final AsyncValue<T> asyncValue;
  final Widget Function(T data) onData;
  final Widget Function()? onLoading;
  final Widget Function(Object error, StackTrace stack)? onError;
  final VoidCallback? retryCallback;

  @override
  Widget build(BuildContext context) {
    return asyncValue.when(
      data: onData,
      loading: () => onLoading?.call() ?? const _DefaultLoadingWidget(),
      error: (error, stack) =>
          onError?.call(error, stack) ??
          ErrorStateWidget(
            error: error.toString(),
            onRetry: retryCallback ?? () {},
          ),
    );
  }
}

class _DefaultLoadingWidget extends StatelessWidget {
  const _DefaultLoadingWidget();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Carregando...',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}
