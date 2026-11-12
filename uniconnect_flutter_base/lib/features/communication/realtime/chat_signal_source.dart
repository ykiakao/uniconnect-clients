import 'dart:async';

import 'package:realtime_client/realtime_client.dart';

import '../../../core/config/realtime_config.dart';

const chatSignalEvents = ['message.created', 'conversation.read'];

enum ChatConnection { connecting, live, unavailable, failed }

/// A live subscription to one private chat topic.
abstract class ChatSubscription {
  /// Sends the refreshed access JWT to the channel.
  Future<void> updateToken(String accessToken);
  Future<void> close();
}

/// Delivers Broadcast signals of one topic. Signals are hints: the history
/// over HTTP stays the source of truth.
abstract class ChatSignalSource {
  ChatSubscription subscribe({
    required String topic,
    required String accessToken,
    required void Function(String event, Map<String, dynamic> payload) onSignal,
    required void Function(ChatConnection state) onState,
  });
}

/// Supabase Realtime Broadcast on a private channel. Only the access JWT of
/// the API session is used; there is no Supabase login in the app.
class SupabaseChatSignalSource implements ChatSignalSource {
  SupabaseChatSignalSource({String? endpoint, String? anonKey})
      : _endpoint = endpoint ?? RealtimeConfig.endpoint,
        _anonKey = anonKey ?? RealtimeConfig.supabaseAnonKey;

  final String _endpoint;
  final String _anonKey;
  RealtimeClient? _client;

  RealtimeClient get _socket => _client ??= RealtimeClient(
        _endpoint,
        params: {'apikey': _anonKey},
        headers: {'apikey': _anonKey},
      );

  @override
  ChatSubscription subscribe({
    required String topic,
    required String accessToken,
    required void Function(String event, Map<String, dynamic> payload) onSignal,
    required void Function(ChatConnection state) onState,
  }) {
    final socket = _socket;
    unawaited(socket.setAuth(accessToken));
    final channel =
        socket.channel(topic, const RealtimeChannelConfig(private: true));
    for (final event in chatSignalEvents) {
      channel.onBroadcast(
          event: event, callback: (payload) => onSignal(event, payload));
    }
    onState(ChatConnection.connecting);
    channel.subscribe((status, _) {
      onState(switch (status) {
        RealtimeSubscribeStatus.subscribed => ChatConnection.live,
        RealtimeSubscribeStatus.closed => ChatConnection.unavailable,
        RealtimeSubscribeStatus.channelError ||
        RealtimeSubscribeStatus.timedOut =>
          ChatConnection.failed,
      });
    });
    return _SupabaseSubscription(socket, channel);
  }
}

class _SupabaseSubscription implements ChatSubscription {
  _SupabaseSubscription(this._socket, this._channel);

  final RealtimeClient _socket;
  final RealtimeChannel _channel;

  @override
  Future<void> updateToken(String accessToken) => _socket.setAuth(accessToken);

  @override
  Future<void> close() async {
    await _socket.removeChannel(_channel);
  }
}
