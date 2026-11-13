import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
// Keep the app's existing Material API until its SDK migration is addressed.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/notifications/push_auth_listener.dart';
import 'core/notifications/push_notification_navigation_provider.dart';
import 'core/notifications/push_notification_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_loading_page.dart';
import 'features/auth/providers/auth_provider.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  GoogleFonts.config.allowRuntimeFetching = false;

  final androidPush =
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  if (androidPush) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  runApp(const ProviderScope(child: UniConnectApp()));

  if (androidPush) await PushNotificationService.initialize();
}

class UniConnectApp extends ConsumerWidget {
  const UniConnectApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(pushAuthListenerProvider);
    final router = ref.watch(appRouterProvider);
    ref.watch(pushNotificationNavigationProvider);
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
