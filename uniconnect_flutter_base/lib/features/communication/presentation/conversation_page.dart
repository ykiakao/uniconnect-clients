import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/academic_content.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_button_styles.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/error_state_widget.dart';
import '../../../shared/widgets/status_banner.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/communication_models.dart';
import '../providers/communication_providers.dart';
import '../realtime/chat_signal_source.dart';
import '../realtime/conversation_sync.dart';
import 'communication_ui.dart';

const _messageLimit = 10000;

class ConversationPage extends ConsumerStatefulWidget {
  const ConversationPage({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends ConsumerState<ConversationPage> {
  final _input = TextEditingController();
  ConversationSync? _sync;
  Object? _startError;

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
    try {
      final auth = ref.read(authControllerProvider);
      final sync = ConversationSync(
        conversationId: widget.conversationId,
        myId: auth.user?.id ?? '',
        service: ref.read(communicationServiceProvider),
        accessToken: auth.accessToken ?? '',
        signals: ref.read(chatSignalSourceProvider),
        onMarkedRead: () {
          if (mounted) ref.invalidate(unreadNotificationsProvider);
        },
      );
      _sync = sync..start();
    } on Object catch (error) {
      _startError = error;
    }
  }

  @override
  void dispose() {
    _sync?.dispose();
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final sync = _sync;
    final content = _input.text.trim();
    if (sync == null || content.isEmpty || !sync.canSend) return;
    _input.clear();
    await sync.send(content);
    ref.invalidate(conversationsProvider);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider.select((auth) => auth.accessToken),
        (_, token) {
      final sync = _sync;
      if (sync == null || token == null) return;
      sync.updateAccess(ref.read(communicationServiceProvider), token);
    });
    final role = ref.watch(currentUserProvider)?.role;
    final sync = _sync;
    return Scaffold(
      appBar: AppHeader(title: 'Conversa', fallbackRoute: chatRouteFor(role)),
      body: SafeArea(
        child: AcademicContent(
          child: sync == null
              ? ErrorStateWidget(
                  title: 'Não foi possível abrir a conversa',
                  error: communicationErrorText(_startError ?? ''),
                  onRetry: () => Navigator.of(context).maybePop(),
                )
              : ListenableBuilder(
                  listenable: sync,
                  builder: (context, _) => _body(sync),
                ),
        ),
      ),
    );
  }

  Widget _body(ConversationSync sync) {
    final messages = sync.messages;
    final pending = sync.pending;
    if (!sync.loaded) {
      return const Center(
          child: CircularProgressIndicator(
              semanticsLabel: 'Carregando mensagens'));
    }
    if (sync.error != null && messages.isEmpty && pending.isEmpty) {
      return ErrorStateWidget(
        title: 'Não foi possível carregar a conversa',
        error: communicationErrorText(sync.error!),
        onRetry: sync.reconcile,
      );
    }
    final window = sync.window;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ConnectionBar(sync: sync),
        if (window != null && !window.canSendNow)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.pageHorizontal,
                AppSpacing.xs, AppSpacing.pageHorizontal, 0),
            child: StatusBanner(
              title: 'Atendimento indisponível agora',
              message:
                  'Mensagens podem ser enviadas: ${window.description}. O histórico continua disponível.',
              tone: AppBadgeTone.warning,
              icon: LucideIcons.clock,
            ),
          ),
        if (sync.error != null && messages.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.pageHorizontal,
                AppSpacing.xs, AppSpacing.pageHorizontal, 0),
            child: StatusBanner(
              title: 'Não foi possível atualizar',
              message: communicationErrorText(sync.error!),
              tone: AppBadgeTone.danger,
              action: TextButton(
                style: AppButtonStyles.link,
                onPressed: sync.reconcile,
                child: const Text('Tentar novamente'),
              ),
            ),
          ),
        Expanded(
          child: messages.isEmpty && pending.isEmpty
              ? EmptyStateWidget(
                  icon: LucideIcons.messageSquareMore,
                  title: 'Nenhuma mensagem ainda',
                  subtitle: sync.canSend
                      ? 'Escreva a primeira mensagem abaixo.'
                      : 'As mensagens desta conversa aparecem aqui.',
                )
              : _MessageList(sync: sync, messages: messages, pending: pending),
        ),
        _Composer(
          controller: _input,
          enabled: sync.canSend,
          disabledHint: window == null
              ? 'Verificando horário de atendimento'
              : 'Envio fora do horário de atendimento',
          onSend: _send,
        ),
      ],
    );
  }
}

class _ConnectionBar extends StatelessWidget {
  const _ConnectionBar({required this.sync});

  final ConversationSync sync;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (sync.connection) {
      ChatConnection.live => ('Conectado em tempo real', AppColors.success),
      ChatConnection.connecting => ('Conectando…', AppColors.warning),
      ChatConnection.unavailable || ChatConnection.failed => (
          'Atualização automática a cada 30 segundos',
          AppColors.inkMuted
        ),
    };
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.pageHorizontal,
            AppSpacing.xs, AppSpacing.pageHorizontal, 0),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(label,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.inkMuted)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList(
      {required this.sync, required this.messages, required this.pending});

  final ConversationSync sync;
  final List<ConversationMessage> messages;
  final List<PendingMessage> pending;

  @override
  Widget build(BuildContext context) {
    final total = messages.length + pending.length;
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(AppSpacing.pageHorizontal,
          AppSpacing.md, AppSpacing.pageHorizontal, AppSpacing.md),
      itemCount: total,
      itemBuilder: (context, index) {
        final position = total - 1 - index;
        if (position >= messages.length) {
          final item = pending[position - messages.length];
          return _Bubble(
            content: item.content,
            createdAt: item.createdAt,
            isMine: true,
            footer: _PendingFooter(sync: sync, message: item),
          );
        }
        final message = messages[position];
        final isMine = message.senderId == sync.myId;
        return _Bubble(
          content: message.content,
          createdAt: message.createdAt,
          isMine: isMine,
          read: isMine && message.readByRecipient,
        );
      },
    );
  }
}

class _PendingFooter extends StatelessWidget {
  const _PendingFooter({required this.sync, required this.message});

  final ConversationSync sync;
  final PendingMessage message;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (message.sending) {
      return Text('Enviando…',
          style: text.labelSmall?.copyWith(color: AppColors.inkMuted));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(message.error ?? 'Não enviada',
            textAlign: TextAlign.end,
            style: text.labelSmall?.copyWith(color: AppColors.danger)),
        Wrap(
          spacing: AppSpacing.xs,
          children: [
            TextButton(
              style: AppButtonStyles.link,
              onPressed: sync.canSend ? () => sync.retry(message) : null,
              child: const Text('Reenviar'),
            ),
            TextButton(
              style: AppButtonStyles.link,
              onPressed: () => sync.discard(message),
              child: const Text('Descartar'),
            ),
          ],
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.content,
    required this.createdAt,
    required this.isMine,
    this.read = false,
    this.footer,
  });

  final String content;
  final DateTime createdAt;
  final bool isMine;
  final bool read;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final foreground = isMine ? AppColors.onPrimary : AppColors.ink;
    final meta = text.labelSmall?.copyWith(
        letterSpacing: 0,
        fontWeight: FontWeight.w400,
        color: foreground.withValues(alpha: .8));
    const corner = Radius.circular(AppRadius.lg);
    const tail = Radius.circular(AppRadius.sm);
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .78),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.xxs),
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
              decoration: BoxDecoration(
                color: isMine
                    ? (footer == null
                        ? AppColors.primary
                        : AppColors.primary.withValues(alpha: .7))
                    : AppColors.surfaceRaised,
                border: isMine ? null : Border.all(color: AppColors.line),
                borderRadius: BorderRadius.only(
                  topLeft: corner,
                  topRight: corner,
                  bottomLeft: isMine ? corner : tail,
                  bottomRight: isMine ? tail : corner,
                ),
              ),
              child: Column(
                crossAxisAlignment:
                    isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(content,
                      style: text.bodyMedium?.copyWith(color: foreground)),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(formatCommunicationDate(createdAt), style: meta),
                      if (read) ...[
                        const SizedBox(width: AppSpacing.xxs),
                        Icon(LucideIcons.checkCheck,
                            size: 14, color: meta?.color),
                        const SizedBox(width: 2),
                        Text('Lida', style: meta),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: footer,
              )
            else
              const SizedBox(height: AppSpacing.xxs),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.disabledHint,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool enabled;
  final String disabledHint;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final canSend = enabled && controller.text.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.pageHorizontal,
          AppSpacing.xs, AppSpacing.xs, AppSpacing.xs),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              minLines: 1,
              maxLines: 4,
              maxLength: _messageLimit,
              buildCounter: (_,
                      {required currentLength,
                      required isFocused,
                      maxLength}) =>
                  null,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                  hintText: enabled ? 'Escreva sua mensagem' : disabledHint),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          IconButton.filled(
            tooltip: 'Enviar mensagem',
            onPressed: canSend ? onSend : null,
            icon: const Icon(LucideIcons.send),
          ),
        ],
      ),
    );
  }
}
