import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../models/communication_models.dart';
import '../services/communication_service.dart';
import 'chat_signal_source.dart';

const _maxCatchUpPages = 50;
const _receiptWindow = 30;
const outsideServiceHoursCode = 'CHAT_OUTSIDE_SERVICE_HOURS';

/// A message typed here and not yet confirmed by the API.
class PendingMessage {
  PendingMessage(this.clientMessageId, this.content, this.createdAt);

  final String clientMessageId;
  final String content;
  final DateTime createdAt;
  bool sending = true;
  String? error;
}

/// Keeps one conversation in sync with the API.
///
/// * The HTTP history is the source of truth; Realtime signals only ask for
///   a catch-up, and a periodic reconciliation repairs lost signals.
/// * [cursor] is the highest sequence confirmed by the history, never taken
///   from a signal or a send response.
/// * Messages merge by id and sequence; a pending message disappears when
///   the API returns its `clientMessageId`, so nothing shows twice.
class ConversationSync extends ChangeNotifier {
  ConversationSync({
    required this.conversationId,
    required this.myId,
    required CommunicationService service,
    required String accessToken,
    this.signals,
    this.reconcileEvery = const Duration(seconds: 30),
    this.onMarkedRead,
  })  : _service = service,
        _accessToken = accessToken;

  final String conversationId;
  final String myId;
  final ChatSignalSource? signals;
  final Duration reconcileEvery;
  final VoidCallback? onMarkedRead;

  CommunicationService _service;
  String _accessToken;
  final _byId = <String, ConversationMessage>{};
  final _pending = <PendingMessage>[];
  ChatSubscription? _subscription;
  Timer? _timer;
  bool _syncing = false;
  bool _syncAgain = false;
  bool _disposed = false;
  int _generation = 0;
  int _readMarked = 0;

  int cursor = 0;
  bool loaded = false;
  Object? error;
  ChatServiceWindow? window;
  ChatConnection connection = ChatConnection.connecting;

  bool get canSend => window?.canSendNow ?? false;
  bool get hasRealtime => signals != null;

  List<ConversationMessage> get messages =>
      _byId.values.toList()..sort((a, b) => a.sequence.compareTo(b.sequence));

  List<PendingMessage> get pending => List.unmodifiable(_pending);

  Future<void> start() async {
    if (signals == null) connection = ChatConnection.unavailable;
    await _refreshDescriptor(subscribe: true);
    await requestSync();
    _timer = Timer.periodic(reconcileEvery, (_) => unawaited(reconcile()));
  }

  /// New session token (refresh) or service: resubscribe and catch up.
  Future<void> updateAccess(
      CommunicationService service, String accessToken) async {
    if (accessToken == _accessToken) return;
    _service = service;
    _accessToken = accessToken;
    await _subscription?.updateToken(accessToken);
    await requestSync();
  }

  /// Periodic repair: sending window, missed messages and read receipts.
  Future<void> reconcile() async {
    await _refreshDescriptor();
    await requestSync();
    await _refreshReceipts();
  }

  /// Runs one catch-up at a time; a request during it schedules another.
  Future<void> requestSync() async {
    if (_disposed) return;
    if (_syncing) {
      _syncAgain = true;
      return;
    }
    _syncing = true;
    try {
      do {
        _syncAgain = false;
        await _catchUp();
      } while (_syncAgain && !_disposed);
      error = null;
    } on Object catch (failure) {
      error = failure;
      _handleAccessLoss(failure);
    } finally {
      _syncing = false;
      loaded = true;
      _notify();
    }
    unawaited(_markRead());
  }

  Future<void> send(String content) async {
    final text = content.trim();
    if (text.isEmpty) return;
    final message = PendingMessage(newClientMessageId(), text, DateTime.now());
    _pending.add(message);
    await _deliver(message);
  }

  /// Same `clientMessageId` and content: the API answers with the message
  /// it may already have stored.
  Future<void> retry(PendingMessage message) => _deliver(message);

  void discard(PendingMessage message) {
    _pending.remove(message);
    _notify();
  }

  Future<void> _deliver(PendingMessage message) async {
    final generation = _generation;
    message
      ..sending = true
      ..error = null;
    _notify();
    try {
      final saved = await _service.sendMessage(conversationId, message.content,
          clientMessageId: message.clientMessageId);
      if (generation != _generation) return;
      _merge([saved]);
      _pending.remove(message);
      unawaited(requestSync());
    } on ApiException catch (failure) {
      if (generation != _generation) return;
      message.error = _sendError(failure);
      if (failure.code == outsideServiceHoursCode) {
        window =
            (window ?? const ChatServiceWindow(canSendNow: false)).closed();
      }
      // The API may have stored it before the answer was lost.
      if (failure.statusCode == null) unawaited(requestSync());
    } finally {
      message.sending = false;
      _notify();
    }
  }

  String _sendError(ApiException failure) {
    if (failure.code == outsideServiceHoursCode) {
      return 'Fora do horário de atendimento. A mensagem não foi enviada.';
    }
    return switch (failure.statusCode) {
      null => 'Sem conexão. Toque para reenviar.',
      403 => 'Você não pode mais enviar mensagens nesta conversa.',
      409 => 'Esta mensagem conflita com outra já enviada.',
      _ => 'Não foi possível enviar. Toque para reenviar.',
    };
  }

  Future<void> _refreshDescriptor({bool subscribe = false}) async {
    final generation = _generation;
    try {
      final descriptor = await _service.realtime(conversationId);
      if (generation != _generation) return;
      window = descriptor.window;
      final source = signals;
      if (subscribe && source != null && _subscription == null) {
        _subscription = source.subscribe(
          topic: descriptor.topic,
          accessToken: _accessToken,
          onSignal: _onSignal,
          onState: _onState,
        );
      }
    } on Object catch (failure) {
      if (generation != _generation) return;
      _handleAccessLoss(failure);
      if (!loaded) error = failure;
    }
    _notify();
  }

  void _onState(ChatConnection state) {
    if (_disposed) return;
    connection = state;
    _notify();
    // SUBSCRIBED does not mean synced: catch up after every (re)join.
    if (state == ChatConnection.live) unawaited(requestSync());
  }

  void _onSignal(String event, Map<String, dynamic> payload) {
    if (_disposed) return;
    final signal =
        ChatSignal.parse(event, payload, conversationId: conversationId);
    switch (signal) {
      case MessageCreatedSignal():
        unawaited(requestSync());
      case ConversationReadSignal(:final readerId, :final upToSequence)
          when readerId != myId:
        _applyReceipt(upToSequence);
      case _:
        break;
    }
  }

  Future<void> _catchUp() async {
    final generation = _generation;
    var after = cursor;
    for (var page = 0; page < _maxCatchUpPages; page++) {
      final result =
          await _service.messagePage(conversationId, afterSequence: after);
      if (generation != _generation) return;
      _merge(result.messages);
      if (result.messages.isNotEmpty) after = result.messages.last.sequence;
      cursor = after;
      if (!result.hasMore) return;
      after = result.nextAfterSequence;
    }
  }

  Future<void> _refreshReceipts() async {
    final unread = _byId.values
        .any((message) => message.senderId == myId && !message.readByRecipient);
    if (!unread || cursor == 0) return;
    final generation = _generation;
    try {
      final from = cursor > _receiptWindow ? cursor - _receiptWindow : 0;
      final result =
          await _service.messagePage(conversationId, afterSequence: from);
      if (generation != _generation) return;
      _merge(result.messages);
      _notify();
    } on Object {
      // The next reconciliation tries again; the history stays as it is.
    }
  }

  void _merge(List<ConversationMessage> incoming) {
    for (final message in incoming) {
      _byId.removeWhere((id, existing) =>
          id != message.id && existing.sequence == message.sequence);
      final previous = _byId[message.id];
      _byId[message.id] = previous != null &&
              previous.readByRecipient &&
              !message.readByRecipient
          ? message.markRead()
          : message;
      final clientId = message.clientMessageId;
      if (clientId != null) {
        _pending.removeWhere((pending) => pending.clientMessageId == clientId);
      }
    }
  }

  void _applyReceipt(int upToSequence) {
    for (final entry in _byId.entries.toList()) {
      final message = entry.value;
      if (message.senderId == myId && message.sequence <= upToSequence) {
        _byId[entry.key] = message.markRead();
      }
    }
    _notify();
  }

  Future<void> _markRead() async {
    final latest = cursor;
    final fromOther = _byId.values.any((message) =>
        message.senderId != myId && message.sequence > _readMarked);
    if (latest <= _readMarked || !fromOther) return;
    _readMarked = latest;
    try {
      await _service.markConversationRead(conversationId, latest);
      onMarkedRead?.call();
    } on Object {
      _readMarked = 0;
    }
  }

  /// 403/404: no longer a participant; stop listening to the channel.
  void _handleAccessLoss(Object failure) {
    if (failure is ApiException &&
        (failure.statusCode == 403 || failure.statusCode == 404) &&
        failure.code != outsideServiceHoursCode) {
      unawaited(_subscription?.close());
      _subscription = null;
      connection = ChatConnection.unavailable;
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _timer?.cancel();
    unawaited(_subscription?.close());
    _subscription = null;
    super.dispose();
  }
}
