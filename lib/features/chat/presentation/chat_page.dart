import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
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
        title: 'Chat acadêmico',
        fallbackRoute: AppRoutes.studentDashboard,
        actions: [
          Padding(
            padding: EdgeInsets.only(right: AppSpacing.sm),
            child: CircleAvatar(
              backgroundColor: AppColors.primary,
              child: Icon(Icons.person_outline, color: Colors.white),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const UniBottomNav(currentIndex: 2),
      body: Column(
        children: [
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
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.xs,
                AppSpacing.sm,
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
                      decoration: InputDecoration(
                        hintText: 'Escreva sua mensagem...',
                      ),
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
        padding: const EdgeInsets.all(AppSpacing.sm),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: message.isMine ? AppColors.primary : Colors.white,
          border: Border.all(
            color: message.isMine ? AppColors.primary : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: message.isMine ? Colors.white : AppColors.dark,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
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
