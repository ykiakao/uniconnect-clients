import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'push_device_registration.dart';

abstract interface class PushTokenSource {
  Future<String?> getToken();
  Stream<String> get onTokenRefresh;
}

class FirebasePushTokenSource implements PushTokenSource {
  // These APIs return the FCM token expected by Firebase Admin SDK.
  @override
  Future<String?> getToken() =>
      // ignore: deprecated_member_use
      FirebaseMessaging.instance.getToken();

  @override
  Stream<String> get onTokenRefresh =>
      // ignore: deprecated_member_use
      FirebaseMessaging.instance.onTokenRefresh;
}

class PushSession {
  const PushSession({
    required this.userId,
    required this.tenantId,
    required this.tenantSlug,
    required this.accessToken,
  });

  final String userId;
  final String tenantId;
  final String tenantSlug;
  final String accessToken;

  bool sameOwner(PushSession other) =>
      userId == other.userId &&
      tenantId == other.tenantId &&
      tenantSlug == other.tenantSlug;

  PushSession withAccessToken(String value) => PushSession(
        userId: userId,
        tenantId: tenantId,
        tenantSlug: tenantSlug,
        accessToken: value,
      );
}

class _PushBinding {
  _PushBinding(this.session, this.token);

  PushSession session;
  final String token;
  bool confirmed = false;
}

/// Owns one token subscription and serializes backend mutations for a container.
class PushRegistrationCoordinator {
  PushRegistrationCoordinator(this._registration, this._tokens) {
    try {
      _subscription = _tokens?.onTokenRefresh.listen(
        (token) {
          _tokenVersion++;
          _token = token.isEmpty ? null : token;
          unawaited(_enqueue());
        },
        onError: (Object error, StackTrace stack) => _reportFailure(),
      );
    } catch (_) {
      _reportFailure();
    }
  }

  final PushDeviceRegistration _registration;
  final PushTokenSource? _tokens;
  StreamSubscription<String>? _subscription;
  PushSession? _session;
  PushSession? _lastSession;
  _PushBinding? _binding;
  String? _token;
  int _lookupGeneration = 0;
  int _tokenVersion = 0;
  bool _disposed = false;
  Future<void>? _lookup;
  Future<void> _tail = Future<void>.value();

  Future<void> setSession(PushSession? session) {
    if (_disposed || _tokens == null) return Future<void>.value();
    final sameOwner =
        session != null && _session != null && session.sameOwner(_session!);
    _session = session;
    if (session != null) {
      _lastSession = session;
      if (_binding?.session.sameOwner(session) ?? false) {
        _binding!.session = session;
      }
    }
    if (!sameOwner) {
      _lookupGeneration++;
      _lookup = null;
      _token = null;
    }
    // Token lookup must not block a logout behind an unavailable Firebase SDK.
    final cleanup = _enqueue();
    if (session == null) return cleanup;
    if (_token != null) return cleanup;
    if (_lookup != null) return _lookup!;
    final lookup = _readToken(_lookupGeneration, _tokenVersion);
    _lookup = lookup;
    unawaited(lookup.whenComplete(() {
      if (identical(_lookup, lookup)) _lookup = null;
    }));
    return lookup;
  }

  Future<void> _readToken(int generation, int version) async {
    try {
      final token = await _tokens!.getToken();
      if (_disposed || generation != _lookupGeneration) return;
      // A refresh event is newer than a lookup that was already in flight.
      if (version == _tokenVersion) {
        _token = token == null || token.isEmpty ? null : token;
      }
      await _enqueue();
    } catch (_) {
      _reportFailure();
    }
  }

  Future<void> beforeRemoteLogout(String accessToken, String tenantSlug) {
    final owner = _session ?? _lastSession;
    if (_disposed || owner == null || owner.tenantSlug != tenantSlug) {
      return Future<void>.value();
    }
    if (_binding?.session.sameOwner(owner) ?? false) {
      // Logout may have awaited an access-token renewal after local sign-out.
      _binding!.session = owner.withAccessToken(accessToken);
    }
    return setSession(null);
  }

  Future<void> _enqueue() {
    return _tail = _tail.then((_) => _reconcile()).catchError((Object error) {
      // Keep uncertain bindings so a later event retries cleanup before reuse.
      _reportFailure();
    });
  }

  bool _isDesired(_PushBinding binding) =>
      _session != null &&
      binding.session.sameOwner(_session!) &&
      binding.token == _token;

  Future<void> _reconcile() async {
    if (_disposed) return;
    final previous = _binding;
    if (previous != null && !_isDesired(previous)) {
      await _remove(previous);
    }
    final session = _session;
    final token = _token;
    if (_disposed || session == null || token == null) return;
    final binding = _binding ??= _PushBinding(session, token);
    if (binding.confirmed) return;
    // Track even an unsuccessful POST: its response may have been lost.
    await _registration.register(
      accessToken: binding.session.accessToken,
      tenantSlug: binding.session.tenantSlug,
      token: binding.token,
    );
    binding.confirmed = true;
    if (!_disposed && !_isDesired(binding)) await _remove(binding);
  }

  Future<void> _remove(_PushBinding binding) async {
    await _registration.unregister(
      accessToken: binding.session.accessToken,
      tenantSlug: binding.session.tenantSlug,
      token: binding.token,
    );
    _binding = null;
  }

  void _reportFailure() {
    debugPrint('FCM: sincronização do dispositivo indisponível.');
  }

  void dispose() {
    _disposed = true;
    _lookupGeneration++;
    unawaited(_subscription?.cancel());
  }
}
