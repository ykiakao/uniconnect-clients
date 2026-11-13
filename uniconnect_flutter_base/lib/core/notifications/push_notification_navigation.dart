import 'dart:async';

import 'package:flutter/foundation.dart';

import '../constants/app_routes.dart';
import '../../features/auth/models/app_user.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/services/session_storage.dart';
import 'push_notification_payload.dart';

class PushOpenEvent {
  const PushOpenEvent(this.data, {this.messageId});
  final Map<String, dynamic> data;
  final String? messageId;
}

abstract interface class PushOpenSource {
  Future<PushOpenEvent?> getInitialMessage();
  Stream<PushOpenEvent> get onOpened;
}

class PushNotificationNavigator {
  PushNotificationNavigator(PushOpenSource? source, this._navigate) {
    if (source == null) return;
    try {
      _subscription = source.onOpened.listen(_receive,
          onError: (Object error, StackTrace stack) => _reportFailure());
    } catch (_) {
      _reportFailure();
    }
    unawaited(_loadInitial(source));
  }

  final void Function(String) _navigate;
  StreamSubscription<PushOpenEvent>? _subscription;
  AuthState _auth = const AuthState.restoring();
  SessionRenewal _renewal = SessionRenewal.idle;
  int? _logoutGeneration;
  int _epoch = 0;
  bool _disposed = false;
  bool _scheduled = false;
  (String, String, String)? _lastOwner;
  (String, String, String)? _pendingOwner;
  PushNotificationPayload? _pending;
  final _seen = <String>{};

  (String, String, String)? _owner(AuthState auth) => auth.isAuthenticated
      ? (auth.user!.id, auth.user!.tenant.id, auth.user!.tenant.slug)
      : null;

  void updateAuth(AuthState auth,
      {required int logoutGeneration, required SessionRenewal renewal}) {
    if (_disposed) return;
    final owner = _owner(auth);
    if ((_logoutGeneration != null && _logoutGeneration != logoutGeneration) ||
        (owner != null && _lastOwner != null && owner != _lastOwner)) {
      _epoch++;
      _pending = null;
      _pendingOwner = null;
    }
    _logoutGeneration = logoutGeneration;
    if (owner != null) _lastOwner = owner;
    _auth = auth;
    _renewal = renewal;
    _flush();
  }

  Future<void> _loadInitial(PushOpenSource source) async {
    final epoch = _epoch;
    try {
      final initial = await source.getInitialMessage();
      if (!_disposed && epoch == _epoch && initial != null) _receive(initial);
    } catch (_) {
      _reportFailure();
    }
  }

  void _receive(PushOpenEvent event) {
    if (_disposed) return;
    final data = event.data;
    if (data['type'] != 'activity_published' ||
        data['tenantId'] is! String ||
        (data['tenantId'] as String).isEmpty ||
        data['activityId'] is! String ||
        !_activityId.hasMatch(data['activityId'] as String) ||
        (data.containsKey('tenantSlug') && data['tenantSlug'] is! String)) {
      return;
    }
    final payload = PushNotificationPayload.fromMap(data);
    final key = event.messageId ??
        '${payload.type}:${payload.tenantId}:${payload.activityId}';
    if (!_seen.add(key)) return;
    if (_seen.length > 100) _seen.remove(_seen.first);
    _pending = payload;
    _pendingOwner = _owner(_auth);
    _flush();
  }

  void _flush() {
    if (_disposed ||
        _scheduled ||
        _pending == null ||
        !_auth.isAuthenticated ||
        _renewal != SessionRenewal.idle) {
      return;
    }
    _scheduled = true;
    // Avoid changing the router during a widget/provider build. Recheck the
    // session at delivery time so logout cannot race a queued navigation.
    scheduleMicrotask(() {
      _scheduled = false;
      if (_disposed ||
          !_auth.isAuthenticated ||
          _renewal != SessionRenewal.idle) {
        return;
      }
      final pending = _pending;
      if (pending == null) return;
      _pending = null;
      final owner = _owner(_auth);
      final sameOwner = _pendingOwner == null || _pendingOwner == owner;
      _pendingOwner = null;
      if (!sameOwner ||
          _auth.role != UserRole.student ||
          pending.tenantId != _auth.user!.tenant.id ||
          (pending.tenantSlug != null &&
              pending.tenantSlug != _auth.user!.tenant.slug)) {
        return;
      }
      try {
        _navigate(AppRoutes.activityDetails
            .replaceFirst(':id', Uri.encodeComponent(pending.activityId!)));
        debugPrint('FCM: destino de atividade solicitado.');
      } catch (_) {
        _reportFailure();
      }
    });
  }

  static final _activityId = RegExp(r'^[a-zA-Z0-9-]{1,128}$');

  void _reportFailure() {
    debugPrint('FCM: abertura de notificacao indisponivel.');
  }

  void dispose() {
    _disposed = true;
    _epoch++;
    _pending = null;
    _pendingOwner = null;
    _seen.clear();
    unawaited(_subscription?.cancel());
  }
}
