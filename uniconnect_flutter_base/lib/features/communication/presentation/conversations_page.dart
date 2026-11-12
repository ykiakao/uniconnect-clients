import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/academic_content.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/bottom_nav.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/error_state_widget.dart';
import '../../academic/demo/synthetic_academic_providers.dart';
import '../../academic/providers/academic_records_providers.dart';
import '../../auth/models/app_user.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chat/presentation/chat_page.dart';
import '../../teacher/providers/teacher_activity_provider.dart';
import '../models/communication_models.dart';
import '../providers/communication_providers.dart';
import 'communication_ui.dart';
import 'new_conversation_sheet.dart';

/// The demo build keeps its illustrative chat; real sessions use the API.
class ChatEntryPage extends ConsumerWidget {
  const ChatEntryPage({super.key, this.isTeacher = false});

  final bool isTeacher;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isTeacher && ref.watch(syntheticDemoEnabledProvider)) {
      return const ChatPage();
    }
    return ConversationsPage(isTeacher: isTeacher);
  }
}

class ConversationsPage extends ConsumerWidget {
  const ConversationsPage({super.key, this.isTeacher = false});

  final bool isTeacher;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(conversationsProvider);
    final role = ref.watch(currentUserProvider)?.role;
    return Scaffold(
      appBar: const AppHeader(title: 'Conversas', showProfile: true),
      bottomNavigationBar: UniBottomNav(currentIndex: 2, isTeacher: isTeacher),
      body: SafeArea(
        child: AcademicContent(
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(conversationsProvider.future),
            child: conversations.when(
              skipLoadingOnRefresh: false,
              loading: () => const Center(
                  child: CircularProgressIndicator(
                      semanticsLabel: 'Carregando conversas')),
              error: (error, _) => ErrorStateWidget(
                title: 'Não foi possível carregar as conversas',
                error: communicationErrorText(error),
                onRetry: () => ref.invalidate(conversationsProvider),
              ),
              data: (items) => items.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.pageHorizontal,
                        AppSpacing.pageTop,
                        AppSpacing.pageHorizontal,
                        AppSpacing.pageBottom,
                      ),
                      children: [
                        if (isTeacher) const _NewConversationButton(),
                        EmptyStateWidget(
                          icon: LucideIcons.messageSquareMore,
                          title: 'Nenhuma conversa ainda',
                          subtitle: role == UserRole.teacher
                              ? 'Inicie uma conversa com um aluno das suas turmas.'
                              : 'Quando o professor de uma turma conversar com você, a conversa aparece aqui.',
                        ),
                      ],
                    )
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.pageHorizontal,
                        AppSpacing.pageTop,
                        AppSpacing.pageHorizontal,
                        AppSpacing.pageBottom,
                      ),
                      children: [
                        if (isTeacher) const _NewConversationButton(),
                        for (final conversation in items)
                          _ConversationTile(
                            conversation: conversation,
                            role: role,
                          ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  const _ConversationTile({required this.conversation, required this.role});

  final Conversation conversation;
  final UserRole? role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final isTeacher = role == UserRole.teacher;
    final String? classLabel;
    final String title;
    if (isTeacher) {
      classLabel = ref
          .watch(teacherOfferingsProvider)
          .asData
          ?.value
          .where((offer) => offer.id == conversation.classId)
          .firstOrNull
          ?.label;
      title = ref
              .watch(classStudentsProvider(conversation.classId))
              .asData
              ?.value
              .where((student) => student.id == conversation.studentId)
              .firstOrNull
              ?.name ??
          'Aluno da turma';
    } else {
      classLabel = _subjectOf(ref, conversation.classId);
      title = 'Professor da turma';
    }
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () => context.push(
          '${chatRouteFor(role)}/${Uri.encodeComponent(conversation.id)}'),
      child: Row(
        children: [
          const IconTile(icon: LucideIcons.messageSquareMore),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleSmall),
                if (classLabel != null)
                  Text(classLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          text.bodySmall?.copyWith(color: AppColors.inkMuted)),
                Text(
                    'Atualizada em ${formatCommunicationDate(conversation.updatedAt)}',
                    style: text.bodySmall?.copyWith(color: AppColors.inkMuted)),
              ],
            ),
          ),
          const Icon(LucideIcons.chevronRight,
              size: 20, color: AppColors.inkMuted),
        ],
      ),
    );
  }
}

/// Subject name of a class for the student, from the academic history.
String? _subjectOf(WidgetRef ref, String classId) {
  final history = ref.watch(academicHistoryProvider).asData?.value;
  if (history == null) return null;
  for (final period in history.periods) {
    for (final subject in period.subjects) {
      if (subject.classId == classId) return subject.title;
    }
  }
  return null;
}

class _NewConversationButton extends StatelessWidget {
  const _NewConversationButton();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: FilledButton.icon(
          onPressed: () => showNewConversationSheet(context),
          icon: const Icon(LucideIcons.messageSquarePlus),
          label: const Text('Nova conversa'),
        ),
      );
}
