import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/academic_content.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/error_state_widget.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/communication_models.dart';
import '../providers/communication_providers.dart';
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
  bool _sending = false;
  int _readUpTo = 0;

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _markRead(List<ConversationMessage> messages) {
    if (messages.isEmpty) return;
    final last = messages.last.sequence;
    if (last <= _readUpTo) return;
    _readUpTo = last;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref
            .read(communicationServiceProvider)
            .markConversationRead(widget.conversationId, last);
        ref.invalidate(unreadNotificationsProvider);
      } catch (_) {
        _readUpTo = 0;
      }
    });
  }

  Future<void> _send() async {
    final content = _input.text.trim();
    if (content.isEmpty || _sending) return;
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(communicationServiceProvider)
          .sendMessage(widget.conversationId, content);
      _input.clear();
      ref.invalidate(conversationMessagesProvider(widget.conversationId));
      ref.invalidate(conversationsProvider);
    } catch (error) {
      messenger
          .showSnackBar(SnackBar(content: Text(communicationErrorText(error))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final messages =
        ref.watch(conversationMessagesProvider(widget.conversationId));
    return Scaffold(
      appBar:
          AppHeader(title: 'Conversa', fallbackRoute: chatRouteFor(user?.role)),
      body: SafeArea(
        child: AcademicContent(
          child: Column(
            children: [
              Expanded(
                child: messages.when(
                  loading: () => const Center(
                      child: CircularProgressIndicator(
                          semanticsLabel: 'Carregando mensagens')),
                  error: (error, _) => ErrorStateWidget(
                    title: 'Não foi possível carregar a conversa',
                    error: communicationErrorText(error),
                    onRetry: () => ref.invalidate(
                        conversationMessagesProvider(widget.conversationId)),
                  ),
                  data: (items) {
                    _markRead(items);
                    if (items.isEmpty) {
                      return const EmptyStateWidget(
                        icon: LucideIcons.messageSquareMore,
                        title: 'Nenhuma mensagem ainda',
                        subtitle: 'Escreva a primeira mensagem abaixo.',
                      );
                    }
                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.pageHorizontal,
                        AppSpacing.md,
                        AppSpacing.pageHorizontal,
                        AppSpacing.md,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final message = items[items.length - 1 - index];
                        return _Bubble(
                          message: message,
                          isMine: message.senderId == user?.id,
                        );
                      },
                    );
                  },
                ),
              ),
              _Composer(
                controller: _input,
                sending: _sending,
                onSend: _send,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.isMine});

  final ConversationMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final foreground = isMine ? AppColors.onPrimary : AppColors.ink;
    const corner = Radius.circular(AppRadius.lg);
    const tail = Radius.circular(AppRadius.sm);
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .78),
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.xs),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
          decoration: BoxDecoration(
            color: isMine ? AppColors.primary : AppColors.surfaceRaised,
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
              Text(message.content,
                  style: text.bodyMedium?.copyWith(color: foreground)),
              const SizedBox(height: 2),
              Text(formatCommunicationDate(message.createdAt),
                  style: text.labelSmall?.copyWith(
                      letterSpacing: 0,
                      fontWeight: FontWeight.w400,
                      color: foreground.withValues(alpha: .75))),
            ],
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer(
      {required this.controller, required this.sending, required this.onSend});

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final canSend = controller.text.trim().isNotEmpty && !sending;
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
              enabled: !sending,
              minLines: 1,
              maxLines: 4,
              maxLength: _messageLimit,
              buildCounter: (_,
                      {required currentLength,
                      required isFocused,
                      maxLength}) =>
                  null,
              textInputAction: TextInputAction.newline,
              decoration:
                  const InputDecoration(hintText: 'Escreva sua mensagem'),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          IconButton.filled(
            tooltip: 'Enviar mensagem',
            onPressed: canSend ? onSend : null,
            icon: sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.onPrimary),
                  )
                : const Icon(LucideIcons.send),
          ),
        ],
      ),
    );
  }
}
