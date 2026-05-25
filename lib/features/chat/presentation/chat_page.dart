import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/bottom_nav.dart';
import '../models/chat_message.dart';
import '../providers/chat_provider.dart';

class ChatPage extends ConsumerWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(chatMessagesProvider);

    return Scaffold(
      appBar: const AppHeader(
        title: 'Conversas',
        fallbackRoute: AppRoutes.studentDashboard,
      ),
      bottomNavigationBar: const UniBottomNav(currentIndex: 2),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar mensagens...',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                SizedBox(height: AppSpacing.md),
                _ConversationStrip(),
              ],
            ),
          ),
          const _ChatHeader(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              itemCount: messages.length,
              itemBuilder: (context, index) =>
                  _MessageBubble(message: messages[index]),
            ),
          ),
          const _Composer(),
        ],
      ),
    );
  }
}

class _ConversationStrip extends StatelessWidget {
  const _ConversationStrip();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 86,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: const [
          _ConversationTile(
            initials: 'RS',
            name: 'Prof. Ricardo Silva',
            time: 'AGORA',
            preview: 'O arquivo do projeto foi enviado?',
          ),
          _ConversationTile(
            initials: 'AC',
            name: 'Ana Costa',
            time: '14:20',
            preview: 'Combinado! Nos vemos no laboratório.',
          ),
          _ConversationTile(
            initials: 'GT',
            name: 'Grupo de TCC - Eng.',
            time: 'ONTEM',
            preview: 'Lucas: Enviei as referências no drive.',
          ),
        ],
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.initials,
    required this.name,
    required this.time,
    required this.preview,
  });

  final String initials;
  final String name;
  final String time;
  final String preview;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 230,
      margin: const EdgeInsets.only(right: AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary,
              child:
                  Text(initials, style: const TextStyle(color: Colors.white)),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      Text(
                        time,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ],
                  ),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white,
            child: Text(
              'RS',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Prof. Ricardo Silva',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'ONLINE AGORA',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        constraints: const BoxConstraints(maxWidth: 310),
        decoration: BoxDecoration(
          color: message.isMine ? AppColors.primary : Colors.white,
          border: Border.all(
            color: message.isMine ? AppColors.primary : AppColors.border,
          ),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(message.isMine ? 16 : 4),
            bottomRight: Radius.circular(message.isMine ? 4 : 16),
          ),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: message.isMine ? Colors.white : AppColors.dark,
                height: 1.35,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message.time,
              style: TextStyle(
                color: message.isMine ? Colors.white70 : AppColors.muted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        color: Colors.white,
        child: Row(
          children: [
            IconButton(
              tooltip: 'Anexar arquivo',
              onPressed: () {},
              icon: const Icon(Icons.attach_file),
            ),
            const Expanded(
              child: TextField(
                decoration:
                    InputDecoration(hintText: 'Escreva sua mensagem...'),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            IconButton.filled(
              tooltip: 'Enviar mensagem',
              onPressed: () {},
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
