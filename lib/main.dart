import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  runApp(const ProviderScope(child: UniConnectApp()));
}

class UniConnectApp extends ConsumerWidget {
  const UniConnectApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'UniConnect',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
