import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/realtime_config.dart';
import '../../../core/network/api_client.dart';
import '../../academic/demo/synthetic_academic_providers.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/communication_models.dart';
import '../realtime/chat_signal_source.dart';
import '../services/communication_service.dart';

final communicationServiceProvider = Provider<CommunicationService>((ref) {
  if (ref.watch(syntheticDemoEnabledProvider)) {
    throw const ApiException('Indisponível no modo de demonstração.');
  }
  final auth = ref.watch(authControllerProvider);
  final user = auth.user;
  if (user == null || auth.accessToken == null) {
    throw const ApiException('Sessão inválida. Entre novamente.',
        statusCode: 401);
  }
  return CommunicationService(ref.watch(apiClientProvider),
      accessToken: auth.accessToken!, tenantSlug: user.tenant.slug);
});

/// Realtime signals for the chat; `null` when the build has no Supabase
/// URL/publishable key, and the chat falls back to periodic HTTP sync.
final chatSignalSourceProvider = Provider<ChatSignalSource?>(
    (ref) => RealtimeConfig.isConfigured ? SupabaseChatSignalSource() : null);

/// `view` is `active`, `history` or `managed` (teachers' own notices).
final noticesProvider = FutureProvider.autoDispose
    .family<List<AppNotice>, String>(
        (ref, view) =>
            ref.watch(communicationServiceProvider).notices(view: view),
        retry: (_, __) => null);

final noticeProvider = FutureProvider.autoDispose.family<AppNotice, String>(
    (ref, id) => ref.watch(communicationServiceProvider).notice(id),
    retry: (_, __) => null);

final conversationsProvider = FutureProvider.autoDispose<List<Conversation>>(
    (ref) => ref.watch(communicationServiceProvider).conversations(),
    retry: (_, __) => null);

final conversationMessagesProvider = FutureProvider.autoDispose
    .family<List<ConversationMessage>, String>(
        (ref, id) => ref.watch(communicationServiceProvider).messages(id),
        retry: (_, __) => null);

final unreadNotificationsProvider = FutureProvider.autoDispose<int>(
    (ref) => ref.watch(communicationServiceProvider).unreadNotifications(),
    retry: (_, __) => null);

final notificationsProvider = FutureProvider.autoDispose<List<AppNotification>>(
    (ref) => ref.watch(communicationServiceProvider).notifications(),
    retry: (_, __) => null);

String communicationErrorText(Object error) {
  if (error is ApiException) {
    return switch (error.statusCode) {
      401 => 'Sessão inválida ou expirada. Entre novamente.',
      403 => 'Acesso negado para este conteúdo.',
      404 => 'Conteúdo indisponível ou removido.',
      409 => 'O conteúdo mudou. Atualize e tente novamente.',
      _ => error.message,
    };
  }
  return 'Não foi possível concluir. Confira sua conexão e tente novamente.';
}
