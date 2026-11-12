import 'dart:math';

import '../../../core/network/api_client.dart';
import '../models/communication_models.dart';

const _pageSize = 50;
const _maxMessagePages = 10;

/// Notices, conversations and notifications of the signed-in user.
class CommunicationService {
  const CommunicationService(this.client,
      {required this.accessToken, required this.tenantSlug});

  final ApiClient client;
  final String accessToken;
  final String tenantSlug;

  String get _base => '/tenants/${Uri.encodeComponent(tenantSlug)}';

  Future<Map<String, dynamic>> _get(String path,
          [Map<String, String>? query]) =>
      client.get('$_base$path',
          queryParams: query, accessToken: accessToken, tenantSlug: tenantSlug);

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) =>
      client.post('$_base$path', body,
          accessToken: accessToken, tenantSlug: tenantSlug);

  List<Map<String, dynamic>> _rows(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is! List) {
      throw const ApiException('A API retornou uma lista inválida.');
    }
    return data.whereType<Map<String, dynamic>>().toList();
  }

  Future<List<AppNotice>> notices({String view = 'active'}) async {
    final response = await _get(
        '/notices', {'view': view, 'page': '1', 'limit': '$_pageSize'});
    return _rows(response).map(AppNotice.fromJson).toList();
  }

  Future<AppNotice> notice(String id) async =>
      AppNotice.fromJson(await _get('/notices/${Uri.encodeComponent(id)}'));

  Future<void> markNoticeRead(AppNotice notice) => _post(
      '/notices/${Uri.encodeComponent(notice.id)}/read',
      {'expectedRevision': notice.revision});

  /// Creates a draft for one class; [publish] also publishes it.
  Future<AppNotice> createClassNotice({
    required String classId,
    required String title,
    required String content,
    required NoticePriority priority,
    bool publish = false,
  }) async {
    final draft = AppNotice.fromJson(await _post('/notices', {
      'title': title,
      'content': content,
      'priority': priority.name,
      'audienceType': 'class',
      'classId': classId,
    }));
    return publish ? publishNotice(draft) : draft;
  }

  Future<AppNotice> publishNotice(AppNotice notice) async =>
      AppNotice.fromJson(await _post(
          '/notices/${Uri.encodeComponent(notice.id)}/publish',
          {'expectedRevision': notice.revision}));

  Future<List<Conversation>> conversations() async {
    final response =
        await _get('/conversations', {'page': '1', 'limit': '$_pageSize'});
    return _rows(response).map(Conversation.fromJson).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<List<ConversationMessage>> messages(String conversationId) async {
    final path =
        '/conversations/${Uri.encodeComponent(conversationId)}/messages';
    final all = <ConversationMessage>[];
    var after = 0;
    for (var page = 0; page < _maxMessagePages; page++) {
      final response =
          await _get(path, {'afterSequence': '$after', 'limit': '100'});
      all.addAll(_rows(response).map(ConversationMessage.fromJson));
      final meta = response['meta'];
      if (meta is! Map || meta['hasMore'] != true) break;
      after = _nextSequence(meta['nextAfterSequence'], after);
    }
    return all;
  }

  int _nextSequence(Object? value, int current) {
    if (value is int && value > current) return value;
    throw const ApiException('A API retornou uma paginação inválida.');
  }

  Future<ConversationMessage> sendMessage(
          String conversationId, String content) async =>
      ConversationMessage.fromJson(await _post(
          '/conversations/${Uri.encodeComponent(conversationId)}/messages',
          {'content': content, 'clientMessageId': _uuidV4()}));

  Future<void> markConversationRead(String conversationId, int upToSequence) =>
      _post('/conversations/${Uri.encodeComponent(conversationId)}/read',
          {'upToSequence': upToSequence});

  Future<int> unreadNotifications() async {
    final count = (await _get('/notifications/unread-count'))['unreadCount'];
    return count is int && count >= 0 ? count : 0;
  }

  Future<List<AppNotification>> notifications() async {
    final response = await _get('/notifications',
        {'page': '1', 'limit': '$_pageSize', 'unreadOnly': 'false'});
    return _rows(response).map(AppNotification.fromJson).toList();
  }

  Future<void> markNotificationRead(String id) =>
      _post('/notifications/${Uri.encodeComponent(id)}/read', const {});
}

/// Random UUID v4, used as the idempotency id of a sent message.
String _uuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
