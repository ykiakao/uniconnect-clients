import '../../../core/network/api_client.dart';

/// Limits of the academic attachments contract (phase A).
const attachmentMaxBytes = 10000000;
const attachmentMaxFiles = 5;
const attachmentMaxNameLength = 180;

/// Accepted extensions and their canonical MIME type.
const attachmentContentTypes = {
  'pdf': 'application/pdf',
  'docx':
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
};

String? attachmentContentType(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot < 0) return null;
  return attachmentContentTypes[fileName.substring(dot + 1).toLowerCase()];
}

/// Client-side check before reserving; the API inspects the bytes anyway.
String? attachmentValidationError(String fileName, int sizeBytes) {
  if (attachmentContentType(fileName) == null) {
    return 'Formato não aceito. Envie PDF, DOCX, PNG ou JPG.';
  }
  if (fileName.length > attachmentMaxNameLength) {
    return 'O nome do arquivo passa de 180 caracteres.';
  }
  if (sizeBytes <= 0) return 'O arquivo está vazio.';
  if (sizeBytes > attachmentMaxBytes) return 'O arquivo passa de 10 MB.';
  return null;
}

String formatFileSize(int bytes) {
  if (bytes < 1000) return '$bytes B';
  if (bytes < 1000000) return '${(bytes / 1000).toStringAsFixed(0)} KB';
  return '${(bytes / 1000000).toStringAsFixed(1).replaceAll('.', ',')} MB';
}

/// A confirmed file: material of an activity or part of a submission.
class AcademicAttachment {
  const AcademicAttachment({
    required this.id,
    required this.name,
    required this.contentType,
    required this.sizeBytes,
    this.createdAt,
  });

  factory AcademicAttachment.fromJson(Object? json) {
    if (json is! Map<String, dynamic> ||
        json['id'] is! String ||
        json['name'] is! String ||
        json['contentType'] is! String ||
        json['sizeBytes'] is! int) {
      throw const ApiException('A API retornou um anexo inválido.');
    }
    return AcademicAttachment(
      id: json['id'] as String,
      name: json['name'] as String,
      contentType: json['contentType'] as String,
      sizeBytes: json['sizeBytes'] as int,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    );
  }

  /// Missing `attachments` in older answers means no attachment.
  static List<AcademicAttachment> listFrom(Object? json) => json is List
      ? List.unmodifiable(json.map(AcademicAttachment.fromJson))
      : const [];

  final String id;
  final String name;
  final String contentType;
  final int sizeBytes;
  final DateTime? createdAt;

  bool get isImage => contentType.startsWith('image/');
}

/// Signed upload capability returned once per reservation.
class UploadTicket {
  const UploadTicket(
      {required this.url, required this.method, required this.headers});

  final Uri url;
  final String method;
  final Map<String, String> headers;
}

class UploadReservation {
  const UploadReservation({required this.id, required this.state, this.ticket});

  factory UploadReservation.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final state = json['state'];
    if (id is! String || state is! String) {
      throw const ApiException(
          'A API retornou uma reserva de upload inválida.');
    }
    final upload = json['upload'];
    UploadTicket? ticket;
    if (upload is Map<String, dynamic>) {
      final url = Uri.tryParse(upload['url'] as String? ?? '');
      final headers = upload['headers'];
      if (url == null || headers is! Map) {
        throw const ApiException(
            'A API retornou um destino de upload inválido.');
      }
      ticket = UploadTicket(
        url: url,
        method: (upload['method'] as String? ?? 'PUT').toUpperCase(),
        headers: {
          for (final entry in headers.entries) '${entry.key}': '${entry.value}',
        },
      );
    }
    return UploadReservation(id: id, state: state, ticket: ticket);
  }

  final String id;
  final String state;

  /// Absent when the API replays a reservation; the capability is not
  /// issued twice.
  final UploadTicket? ticket;
}
