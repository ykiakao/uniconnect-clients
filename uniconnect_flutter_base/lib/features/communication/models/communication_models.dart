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
  ConversationMessage.fromJson(Map<String, dynamic> row)
      : id = _text(row['id']),
        senderId = _text(row['senderId']),
        content = _text(row['content']),
        sequence = _count(row['sequence']),
        createdAt = _date(row['createdAt']) ?? DateTime.now(),
        readByRecipient = row['readByRecipient'] == true;

  final String id;
  final String senderId;
  final String content;
  final int sequence;
  final DateTime createdAt;
  final bool readByRecipient;
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
