import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/activities/providers/activity_provider.dart';
import '../router/app_router.dart';
import 'push_notification_navigation.dart';

class FirebasePushOpenSource implements PushOpenSource {
  @override
  Future<PushOpenEvent?> getInitialMessage() async {
    final message = await FirebaseMessaging.instance.getInitialMessage();
    if (message == null) return null;
    debugPrint('FCM: abertura inicial por notificacao.');
    return PushOpenEvent(message.data, messageId: message.messageId);
  }

  @override
  Stream<PushOpenEvent> get onOpened =>
      FirebaseMessaging.onMessageOpenedApp.map((message) {
        debugPrint('FCM: notificação aberta por toque.');
        return PushOpenEvent(message.data, messageId: message.messageId);
      });
}

final pushOpenSourceProvider = Provider<PushOpenSource?>((ref) {
  if (kIsWeb ||
      defaultTargetPlatform != TargetPlatform.android ||
      Firebase.apps.isEmpty) {
    return null;
  }
  return FirebasePushOpenSource();
});

final pushNavigationHandlerProvider = Provider<void Function(String)>((ref) {
  final router = ref.watch(appRouterProvider);
  return (location) {
    // Load current data and authorization instead of showing a cached activity.
    ref.invalidate(activityByIdProvider(Uri.parse(location).pathSegments.last));
    router.go(location);
  };
});

final pushNotificationNavigationProvider =
    Provider<PushNotificationNavigator>((ref) {
  final controller = ref.watch(authControllerProvider.notifier);
  final navigator = PushNotificationNavigator(ref.watch(pushOpenSourceProvider),
      ref.watch(pushNavigationHandlerProvider));
  void sync() => navigator.updateAuth(ref.read(authControllerProvider),
      logoutGeneration: controller.logoutGeneration,
      renewal: controller.renewal.value);
  ref.listen(authControllerProvider, (_, __) => sync());
  controller.renewal.addListener(sync);
  ref.onDispose(() {
    controller.renewal.removeListener(sync);
    navigator.dispose();
  });
  sync();
  return navigator;
});
