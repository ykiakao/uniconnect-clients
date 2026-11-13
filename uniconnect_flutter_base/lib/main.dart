import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_loading_page.dart';
import 'features/auth/providers/auth_provider.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  runApp(const ProviderScope(child: UniConnectApp()));
}

class UniConnectApp extends ConsumerWidget {
  const UniConnectApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final renewal = ref.watch(authControllerProvider.notifier).renewal;

    return MaterialApp.router(
      title: 'UniConnect',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
      builder: (context, child) => ValueListenableBuilder<SessionRenewal>(
        valueListenable: renewal,
        child: child,
        builder: (context, status, child) {
          final waiting = status != SessionRenewal.idle;
          return Stack(
            fit: StackFit.expand,
            children: [
              ExcludeFocus(
                excluding: waiting,
                child: Offstage(
                  offstage: waiting,
                  child: TickerMode(enabled: !waiting, child: child!),
                ),
              ),
              if (waiting)
                AuthLoadingPage(showRetry: status == SessionRenewal.failed),
            ],
          );
        },
      ),
    );
  }
}
