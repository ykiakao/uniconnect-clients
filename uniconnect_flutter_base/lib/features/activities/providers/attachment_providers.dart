import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/academic_attachment.dart';
import '../services/attachment_service.dart';

typedef PickedFile = ({
  String name,
  int size,
  Future<Uint8List> Function() read
});

final attachmentServiceProvider = Provider<AttachmentService>((ref) {
  final auth = ref.watch(authControllerProvider);
  final user = auth.user;
  final token = auth.accessToken;
  if (user == null || token == null) {
    throw const ApiException('Sessão inválida. Entre novamente.',
        statusCode: 401);
  }
  return AttachmentService(ref.watch(apiClientProvider),
      accessToken: token, tenantSlug: user.tenant.slug);
});

/// Opens the system file picker filtered to the accepted formats.
final attachmentPickerProvider =
    Provider<Future<List<PickedFile>> Function()>((ref) => () async {
          final files = await FilePicker.pickFiles(
            type: FileType.custom,
            allowedExtensions: attachmentContentTypes.keys.toList(),
          );
          return [
            for (final file in files)
              (
                name: file.name,
                size: file.lengthSync() ?? await file.length() ?? 0,
                read: file.readAsBytes,
              ),
          ];
        });

/// Opens a signed download link outside the app (new tab on the web).
final linkOpenerProvider =
    Provider<Future<void> Function(Uri)>((ref) => (url) async {
          if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
            throw const ApiException('Não foi possível abrir o arquivo.');
          }
        });

/// Files of one version of a submission.
final submissionVersionFilesProvider = FutureProvider.autoDispose
    .family<List<AcademicAttachment>, ({String submissionId, int version})>(
        (ref, key) => ref
            .watch(attachmentServiceProvider)
            .versionFiles(key.submissionId, key.version),
        retry: (_, __) => null);
