import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../core/config/realtime_config.dart';
import '../../../core/network/api_client.dart';
import '../models/academic_attachment.dart';

const _completeAttempts = 10;
const _storageTimeout = Duration(minutes: 2);

/// The reservation is retained until its outcome can be confirmed.
class AttachmentConfirmationPending extends ApiException {
  const AttachmentConfirmationPending(this.fileId, {this.state})
      : super(
          state == null
              ? 'Não foi possível confirmar o arquivo. Verifique novamente antes de reenviar.'
              : 'O arquivo ainda está em verificação. Verifique novamente em instantes.',
          code: 'ATTACHMENT_CONFIRMATION_PENDING',
        );

  final String fileId;
  final String? state;
}

bool isAttachmentOutcomeUncertain(Object error) =>
    error is TimeoutException ||
    error is http.ClientException ||
    (error is ApiException &&
        (error.statusCode == null ||
            error.statusCode == 429 ||
            error.statusCode! >= 500));

/// Academic attachments (phase A): reserve → PUT to Storage → complete,
/// then use the file id in the academic operation. The UniConnect token is
/// only sent to the API, never to the Storage URL.
class AttachmentService {
  AttachmentService(
    this.client, {
    required this.accessToken,
    required this.tenantSlug,
    http.Client? storageClient,
    String? storageHost,
    this.retryDelay = const Duration(seconds: 2),
  })  : _storage = storageClient ?? http.Client(),
        _storageHost =
            storageHost ?? Uri.parse(RealtimeConfig.supabaseUrl).host;

  final ApiClient client;
  final String accessToken;
  final String tenantSlug;
  final Duration retryDelay;
  final http.Client _storage;
  final String _storageHost;

  String get _base => '/tenants/${Uri.encodeComponent(tenantSlug)}';
  String _activity(String id) => '$_base/activities/${Uri.encodeComponent(id)}';
  String _upload(String id) =>
      '$_base/attachment-uploads/${Uri.encodeComponent(id)}';

  /// Reserves a file for the next version of the student's submission.
  Future<UploadReservation> reserveSubmissionFile(
    String activityId, {
    required String fileName,
    required int sizeBytes,
    required int expectedVersion,
    required String idempotencyKey,
  }) =>
      _reserve('${_activity(activityId)}/submissions/attachment-uploads',
          fileName: fileName,
          sizeBytes: sizeBytes,
          idempotencyKey: idempotencyKey,
          extra: {'expectedVersion': expectedVersion});

  /// Reserves a support material for an activity (teacher). The activity
  /// must already exist as a draft or published without submissions.
  Future<UploadReservation> reserveMaterial(
    String activityId, {
    required String fileName,
    required int sizeBytes,
    required String idempotencyKey,
  }) =>
      _reserve('${_activity(activityId)}/attachment-uploads',
          fileName: fileName,
          sizeBytes: sizeBytes,
          idempotencyKey: idempotencyKey);

  Future<UploadReservation> _reserve(
    String path, {
    required String fileName,
    required int sizeBytes,
    required String idempotencyKey,
    Map<String, dynamic> extra = const {},
  }) async {
    final contentType = attachmentContentType(fileName);
    final problem = attachmentValidationError(fileName, sizeBytes);
    if (contentType == null || problem != null) {
      throw ApiException(problem ?? 'Formato não aceito.');
    }
    return UploadReservation.fromJson(await client.post(
      path,
      {
        'fileName': fileName,
        'sizeBytes': sizeBytes,
        'contentType': contentType,
        ...extra,
      },
      accessToken: accessToken,
      tenantSlug: tenantSlug,
      headers: {'Idempotency-Key': idempotencyKey},
    ));
  }

  /// Materials linked to an activity (ready and active only).
  Future<List<AcademicAttachment>> materials(String activityId) async {
    final row = await client.get('${_activity(activityId)}/attachments',
        accessToken: accessToken, tenantSlug: tenantSlug);
    return AcademicAttachment.listFrom(row['data']);
  }

  /// Links a ready file; [expectedRevision] is the activity revision, not a
  /// submission version. Returns the new revision.
  Future<({AcademicAttachment attachment, int revision})> linkMaterial(
      String activityId, String fileId, int expectedRevision) async {
    final row = await client.post('${_activity(activityId)}/attachments',
        {'fileId': fileId, 'expectedVersion': expectedRevision},
        accessToken: accessToken, tenantSlug: tenantSlug);
    final revision = row['revision'];
    if (revision is! int) {
      throw const ApiException('A API não confirmou o material.');
    }
    return (
      attachment: AcademicAttachment.fromJson(row['attachment']),
      revision: revision
    );
  }

  /// Removes a material (logically); returns the new activity revision.
  Future<int> removeMaterial(
      String activityId, String fileId, int expectedRevision) async {
    final row = await client.delete(
        '${_activity(activityId)}/attachments/${Uri.encodeComponent(fileId)}',
        queryParams: {'expectedVersion': '$expectedRevision'},
        accessToken: accessToken,
        tenantSlug: tenantSlug);
    final revision = row['revision'];
    if (revision is! int) {
      throw const ApiException('A API não confirmou a remoção.');
    }
    return revision;
  }

  /// Sends the bytes to the signed Storage URL, with exactly the method and
  /// headers of the descriptor. A Storage 200 is not an accepted attachment.
  Future<void> uploadBytes(UploadTicket ticket, Uint8List bytes) async {
    final url = ticket.url;
    if (url.scheme != 'https' || url.host != _storageHost) {
      throw const ApiException('Destino de upload não autorizado.');
    }
    if (ticket.method != 'PUT') {
      throw const ApiException('Método de upload não suportado.');
    }
    final http.Response response;
    try {
      response = await _storage
          .put(url, headers: ticket.headers, body: bytes)
          .timeout(_storageTimeout);
    } on TimeoutException {
      throw const ApiException('O envio do arquivo demorou demais.');
    } on http.ClientException {
      throw const ApiException('Não foi possível enviar o arquivo.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('O armazenamento recusou o arquivo.',
          statusCode: response.statusCode);
    }
  }

  /// Asks the API to verify the bytes; waits while another validation holds
  /// the file (202) and returns the confirmed attachment.
  Future<AcademicAttachment> complete(String fileId) async {
    return _confirm(fileId, await _completeOrStatus(fileId));
  }

  /// Resumes the same reservation, without another reservation or PUT.
  Future<AcademicAttachment> recover(String fileId) async {
    return _confirm(fileId, await _statusOrPending(fileId));
  }

  Future<Map<String, dynamic>> _statusOrPending(String fileId) async {
    try {
      return await client.get(_upload(fileId),
          accessToken: accessToken, tenantSlug: tenantSlug);
    } on Object {
      throw AttachmentConfirmationPending(fileId);
    }
  }

  Future<Map<String, dynamic>> _completeOrStatus(String fileId) async {
    try {
      return await client.post('${_upload(fileId)}/complete', const {},
          accessToken: accessToken, tenantSlug: tenantSlug);
    } on Object catch (error) {
      if (!isAttachmentOutcomeUncertain(error)) rethrow;
      return _statusOrPending(fileId);
    }
  }

  Future<AcademicAttachment> _confirm(
      String fileId, Map<String, dynamic> row) async {
    for (var attempt = 0;; attempt++) {
      if (row['id'] != fileId) throw AttachmentConfirmationPending(fileId);
      final state = row['state'];
      if (state == 'ready') {
        try {
          final attachment = AcademicAttachment.fromJson(row['attachment']);
          if (attachment.id != fileId) {
            throw AttachmentConfirmationPending(fileId);
          }
          return attachment;
        } on Object {
          throw AttachmentConfirmationPending(fileId);
        }
      }
      if (const ['cancelled', 'rejected', 'expired', 'deleting', 'deleted']
          .contains(state)) {
        throw ApiException('O arquivo não foi aceito ($state).',
            code: 'ATTACHMENT_UPLOAD_INELIGIBLE');
      }
      if (state != 'pending' && state != 'validating') {
        throw AttachmentConfirmationPending(fileId);
      }
      if (attempt == _completeAttempts) {
        throw AttachmentConfirmationPending(fileId, state: state as String);
      }
      await Future<void>.delayed(retryDelay);
      row = await _statusOrPending(fileId);
      if (row['id'] == fileId && row['state'] == 'pending') {
        row = await _completeOrStatus(fileId);
      }
    }
  }

  /// Cancels a reservation that is not linked to anything.
  Future<void> cancel(String fileId) => client.delete(_upload(fileId),
      accessToken: accessToken, tenantSlug: tenantSlug);

  /// Files of one version of a submission.
  Future<List<AcademicAttachment>> versionFiles(
      String submissionId, int version) async {
    final row = await client.get(
        '$_base/submissions/${Uri.encodeComponent(submissionId)}/versions/$version/attachments',
        accessToken: accessToken,
        tenantSlug: tenantSlug);
    return AcademicAttachment.listFrom(row['data']);
  }

  /// Short-lived signed download link, requested at click time.
  Future<Uri> downloadUrl(String fileId) async {
    final row = await client.post(
        '$_base/attachments/${Uri.encodeComponent(fileId)}/download-url',
        const {},
        accessToken: accessToken,
        tenantSlug: tenantSlug);
    final url = Uri.tryParse(row['url'] as String? ?? '');
    if (url == null || url.scheme != 'https') {
      throw const ApiException('A API retornou um link de download inválido.');
    }
    return url;
  }
}

/// Idempotency key for one reservation intent (ASCII, 8–128 chars).
String newIdempotencyKey() {
  final random = Random.secure();
  final hex = List.generate(16, (_) => random.nextInt(256))
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
  return 'att-$hex';
}

/// Message for attachment failures, including the disabled feature.
String attachmentErrorText(Object error) {
  if (error is ApiException) {
    return switch (error.code) {
      'ACADEMIC_ATTACHMENTS_UNAVAILABLE' ||
      'ATTACHMENT_STORAGE_UNAVAILABLE' ||
      'DATABASE_MIGRATION_REQUIRED' =>
        'O envio de arquivos ainda não está disponível nesta instituição. A resposta em texto continua funcionando.',
      'ATTACHMENT_FORMAT_REJECTED' =>
        'Arquivo recusado: inválido, protegido ou com recursos não permitidos.',
      'ATTACHMENT_SIZE_MISMATCH' =>
        'O tamanho enviado não confere. Selecione o arquivo novamente.',
      'ATTACHMENT_TOO_LARGE' => 'O arquivo passa de 10 MB.',
      'ATTACHMENT_LIMIT_EXCEEDED' => 'Limite de arquivos atingido.',
      'ATTACHMENT_RATE_LIMIT' ||
      'RATE_LIMIT_EXCEEDED' ||
      'ATTACHMENT_PROCESSING_LIMIT' =>
        'Muitos envios em sequência. Aguarde um pouco e tente novamente.',
      _ => switch (error.statusCode) {
          503 =>
            'O envio de arquivos está indisponível no momento. A resposta em texto continua funcionando.',
          403 || 404 => 'Envio de arquivos não autorizado para esta atividade.',
          409 =>
            'A atividade ou a entrega mudou, ou já não aceita alterações de arquivo. Atualize e tente de novo.',
          _ => error.message,
        },
    };
  }
  return 'Não foi possível enviar o arquivo. Tente novamente.';
}
