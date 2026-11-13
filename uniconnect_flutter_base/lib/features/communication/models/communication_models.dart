import '../../../core/network/api_client.dart';

String _text(Object? value) {
  if (value is String && value.isNotEmpty) return value;
  throw const ApiException('A API retornou uma comunicação inválida.');
}

int _count(Object? value) {
  if (value is int && value >= 0) return value;
  throw const ApiException('A API retornou uma comunicação inválida.');
}

DateTime? _date(Object? value) {
  if (value == null) return null;
  final parsed = value is String ? DateTime.tryParse(value) : null;
  if (parsed == null) {
    throw const ApiException('A API retornou uma data inválida.');
  }
  return parsed.toLocal();
}

enum NoticePriority {
  low('Baixa'),
  medium('Média'),
  high('Alta');

  const NoticePriority(this.label);
  final String label;

  static NoticePriority parse(Object? value) => switch (value) {
        'low' => NoticePriority.low,
        'high' => NoticePriority.high,
        _ => NoticePriority.medium,
      };
}

/// A notice from the institution, a course or a class.
class AppNotice {
  AppNotice.fromJson(Map<String, dynamic> row)
      : id = _text(row['id']),
        authorId = _text(row['authorId']),
        title = _text(row['title']),
        content = row['content'] is String ? row['content'] as String : '',
        audienceType = _text(row['audienceType']),
        classId = row['classId'] as String?,
        state = _text(row['state']),
        priority = NoticePriority.parse(row['priority']),
        revision = _count(row['revision']),
        publishedAt = _date(row['publishedAt']),
        createdAt = _date(row['createdAt']) ?? DateTime.now(),
        readAt = _date(row['readAt']),
        readRevision =
            row['readRevision'] is int ? row['readRevision'] as int : 0;

  final String id;
  final String authorId;
  final String title;
  final String content;
  final String audienceType;
  final String? classId;
  final String state;
  final NoticePriority priority;
  final int revision;
  final DateTime? publishedAt;
  final DateTime createdAt;
  final DateTime? readAt;
  final int readRevision;

  bool get isPublished => state == 'published';
  bool get isDraft => state == 'draft';

  /// A published notice counts as unread until its current revision is read.
  bool get isUnread =>
      isPublished && (readAt == null || readRevision < revision);

  String get audienceLabel => switch (audienceType) {
        'institution' => 'Toda a instituição',
        'course' => 'Curso',
        _ => 'Turma',
      };

  String get stateLabel => switch (state) {
        'draft' => 'Rascunho',
        'archived' => 'Arquivado',
        _ => 'Publicado',
      };
}

class Conversation {
  Conversation.fromJson(Map<String, dynamic> row)
      : id = _text(row['id']),
        classId = _text(row['classId']),
        studentId = _text(row['studentId']),
        teacherId = _text(row['teacherId']),
        lastSequence = _count(row['lastSequence']),
        updatedAt = _date(row['updatedAt']) ?? DateTime.now();

  final String id;
  final String classId;
  final String studentId;
  final String teacherId;
  final int lastSequence;
  final DateTime updatedAt;
}

class ConversationMessage {
  const ConversationMessage({
    required this.id,
    required this.senderId,
    required this.content,
    required this.sequence,
    required this.createdAt,
    this.readByRecipient = false,
    this.conversationId,
    this.clientMessageId,
  });

  ConversationMessage.fromJson(Map<String, dynamic> row)
      : id = _text(row['id']),
        senderId = _text(row['senderId']),
        content = _text(row['content']),
        sequence = _count(row['sequence']),
        createdAt = _date(row['createdAt']) ?? DateTime.now(),
        readByRecipient = row['readByRecipient'] == true,
        conversationId = row['conversationId'] as String?,
        clientMessageId = row['clientMessageId'] as String?;

  final String id;
  final String senderId;
  final String content;
  final int sequence;
  final DateTime createdAt;
  final bool readByRecipient;
  final String? conversationId;
  final String? clientMessageId;

  ConversationMessage markRead() => readByRecipient
      ? this
      : ConversationMessage(
          id: id,
          senderId: senderId,
          content: content,
          sequence: sequence,
          createdAt: createdAt,
          readByRecipient: true,
          conversationId: conversationId,
          clientMessageId: clientMessageId,
        );
}

/// One page of `GET /conversations/:id/messages`.
class MessagePage {
  const MessagePage(
      {required this.messages,
      required this.hasMore,
      required this.nextAfterSequence});

  final List<ConversationMessage> messages;
  final bool hasMore;
  final int nextAfterSequence;
}

/// Sending window decided by the server (`serviceWindow`).
class ChatServiceWindow {
  const ChatServiceWindow({
    required this.canSendNow,
    this.timeZone = 'America/Rio_Branco',
    this.weekdays = const [1, 2, 3, 4, 5],
    this.opensAt = '13:00',
    this.closesAt = '18:00',
  });

  factory ChatServiceWindow.fromJson(Object? json) {
    if (json is! Map<String, dynamic> || json['canSendNow'] is! bool) {
      throw const ApiException(
          'A API retornou um horário de atendimento inválido.');
    }
    final weekdays = json['weekdays'];
    return ChatServiceWindow(
      canSendNow: json['canSendNow'] as bool,
      timeZone: json['timeZone'] as String? ?? 'America/Rio_Branco',
      weekdays: weekdays is List
          ? List.unmodifiable(weekdays.whereType<int>())
          : const [1, 2, 3, 4, 5],
      opensAt: json['opensAt'] as String? ?? '13:00',
      closesAt: json['closesAt'] as String? ?? '18:00',
    );
  }

  final bool canSendNow;
  final String timeZone;
  final List<int> weekdays;
  final String opensAt;
  final String closesAt;

  ChatServiceWindow closed() => ChatServiceWindow(
      canSendNow: false,
      timeZone: timeZone,
      weekdays: weekdays,
      opensAt: opensAt,
      closesAt: closesAt);

  /// "Segunda a sexta, das 13h às 18h (horário do Acre)".
  String get description {
    final days = _sameList(weekdays, const [1, 2, 3, 4, 5])
        ? 'Segunda a sexta'
        : 'Dias úteis';
    final zone = timeZone == 'America/Rio_Branco' ? ' (horário do Acre)' : '';
    return '$days, das ${_hour(opensAt)} às ${_hour(closesAt)}$zone';
  }

  static String _hour(String value) {
    final parts = value.split(':');
    if (parts.length < 2) return value;
    final minutes = parts[1] == '00' ? '' : parts[1];
    return '${int.tryParse(parts[0]) ?? parts[0]}h$minutes';
  }

  static bool _sameList(List<int> a, List<int> b) =>
      a.length == b.length &&
      [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((x) => x);
}

/// Answer of `GET /conversations/:id/realtime`: where to listen for signals.
class ChatRealtimeDescriptor {
  const ChatRealtimeDescriptor({
    required this.topic,
    required this.isPrivate,
    required this.lastSequence,
    required this.window,
  });

  factory ChatRealtimeDescriptor.fromJson(Map<String, dynamic> json) {
    final topic = json['topic'];
    if (json['transport'] != 'supabase-broadcast' ||
        topic is! String ||
        !topic.startsWith('uc:chat:')) {
      throw const ApiException('A API retornou um canal de chat inválido.');
    }
    return ChatRealtimeDescriptor(
      topic: topic,
      isPrivate: json['private'] == true,
      lastSequence: _count(json['lastSequence']),
      window: ChatServiceWindow.fromJson(json['serviceWindow']),
    );
  }

  final String topic;
  final bool isPrivate;
  final int lastSequence;
  final ChatServiceWindow window;
}

/// Payload of a Broadcast signal; it never carries message text.
sealed class ChatSignal {
  const ChatSignal(this.conversationId);
  final String conversationId;

  /// Accepts the SDK envelope (`{payload: {...}}`) or the bare payload.
  /// Unknown versions, events or malformed payloads return `null`.
  static ChatSignal? parse(String event, Map<String, dynamic> raw,
      {required String conversationId}) {
    final inner = raw['payload'];
    final payload = inner is Map<String, dynamic> ? inner : raw;
    if (payload['version'] != 1 ||
        payload['conversationId'] != conversationId) {
      return null;
    }
    final sequence = payload['sequence'];
    final upTo = payload['upToSequence'];
    final reader = payload['readerId'];
    return switch (event) {
      'message.created' when sequence is int =>
        MessageCreatedSignal(conversationId, sequence),
      'conversation.read' when upTo is int && reader is String =>
        ConversationReadSignal(conversationId, reader, upTo),
      _ => null,
    };
  }
}

class MessageCreatedSignal extends ChatSignal {
  const MessageCreatedSignal(super.conversationId, this.sequence);
  final int sequence;
}

class ConversationReadSignal extends ChatSignal {
  const ConversationReadSignal(
      super.conversationId, this.readerId, this.upToSequence);
  final String readerId;
  final int upToSequence;
}

class AppNotification {
  AppNotification.fromJson(Map<String, dynamic> row)
      : id = _text(row['id']),
        type = _text(row['type']),
        resourceType = _text(row['resourceType']),
        resourceId = _text(row['resourceId']),
        createdAt = _date(row['createdAt']) ?? DateTime.now(),
        readAt = _date(row['readAt']);

  final String id;
  final String type;
  final String resourceType;
  final String resourceId;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isUnread => readAt == null;

  String get title => switch (type) {
        'notice_published' => 'Novo aviso publicado',
        'activity_published' => 'Nova atividade publicada',
        'activity_result_published' => 'Resultado publicado',
        'message_received' => 'Nova mensagem',
        'activity_due_soon' => 'Prazo próximo',
        _ => 'Atualização',
      };
}
