import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/services/session_storage.dart';
import 'push_device_registration.dart';
import 'push_registration_coordinator.dart';

final pushTokenSourceProvider = Provider<PushTokenSource?>((ref) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
  return FirebasePushTokenSource();
});

final pushDeviceRegistrationProvider = Provider<PushDeviceRegistration>((ref) {
  return PushDeviceRegistration(ref.watch(apiClientProvider));
});

final pushRegistrationCoordinatorProvider =
    Provider<PushRegistrationCoordinator>((ref) {
  final coordinator = PushRegistrationCoordinator(
    ref.watch(pushDeviceRegistrationProvider),
    ref.watch(pushTokenSourceProvider),
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

final pushAuthListenerProvider = Provider<void>((ref) {
  final coordinator = ref.watch(pushRegistrationCoordinatorProvider);

  void handleAuthState(AuthState next) {
    if (!next.isAuthenticated ||
        next.accessToken == null ||
        next.user == null ||
        next.tenantSlug == null) {
      unawaited(coordinator.setSession(null));
      return;
    }

    unawaited(
      coordinator.setSession(PushSession(
        userId: next.user!.id,
        tenantId: next.user!.tenant.id,
        tenantSlug: next.tenantSlug!,
        accessToken: next.accessToken!,
      )),
    );
  }

  ref.listen(authControllerProvider, (previous, next) {
    handleAuthState(next);
  });

  handleAuthState(ref.read(authControllerProvider));
});
