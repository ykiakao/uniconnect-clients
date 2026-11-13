import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/academic_content.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/error_state_widget.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/communication_models.dart';
import '../providers/communication_providers.dart';
import 'communication_ui.dart';

class NoticeDetailPage extends ConsumerStatefulWidget {
  const NoticeDetailPage({super.key, required this.noticeId});

  final String noticeId;

  @override
  ConsumerState<NoticeDetailPage> createState() => _NoticeDetailPageState();
}

class _NoticeDetailPageState extends ConsumerState<NoticeDetailPage> {
  int? _readRevision;
  bool _publishing = false;

  /// Reading the current revision once marks it as read for this person.
  void _markRead(AppNotice notice, String? userId) {
    if (!notice.isUnread ||
        notice.authorId == userId ||
        _readRevision == notice.revision) {
      return;
    }
    _readRevision = notice.revision;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref.read(communicationServiceProvider).markNoticeRead(notice);
        ref.invalidate(noticesProvider);
        ref.invalidate(unreadNotificationsProvider);
      } catch (_) {
        _readRevision = null;
      }
    });
  }

  Future<void> _publish(AppNotice notice) async {
    setState(() => _publishing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(communicationServiceProvider).publishNotice(notice);
      ref.invalidate(noticeProvider(widget.noticeId));
      ref.invalidate(noticesProvider);
      messenger.showSnackBar(
          const SnackBar(content: Text('Aviso publicado para a turma.')));
    } catch (error) {
      messenger
          .showSnackBar(SnackBar(content: Text(communicationErrorText(error))));
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final notice = ref.watch(noticeProvider(widget.noticeId));
    return Scaffold(
      appBar: const AppHeader(title: 'Aviso', fallbackRoute: AppRoutes.notices),
      body: SafeArea(
        child: AcademicContent(
          child: notice.when(
            loading: () => const Center(
                child: CircularProgressIndicator(
                    semanticsLabel: 'Carregando aviso')),
            error: (error, _) => ErrorStateWidget(
              title: 'Não foi possível abrir o aviso',
              error: communicationErrorText(error),
              onRetry: () => ref.invalidate(noticeProvider(widget.noticeId)),
            ),
            data: (notice) {
              _markRead(notice, user?.id);
              return _NoticeBody(
                notice: notice,
                canPublish: notice.isDraft && notice.authorId == user?.id,
                publishing: _publishing,
                onPublish: () => _publish(notice),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NoticeBody extends StatelessWidget {
  const _NoticeBody({
    required this.notice,
    required this.canPublish,
    required this.publishing,
    required this.onPublish,
  });

  final AppNotice notice;
  final bool canPublish;
  final bool publishing;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final date = notice.publishedAt ?? notice.createdAt;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.pageTop,
        AppSpacing.pageHorizontal,
        AppSpacing.pageBottom,
      ),
      children: [
        Text(notice.audienceLabel.toUpperCase(),
            style: text.labelSmall?.copyWith(color: AppColors.primary)),
        const SizedBox(height: AppSpacing.xxs),
        Text(notice.title, style: text.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            NoticePriorityBadge(priority: notice.priority),
            AppBadge(
              label: notice.stateLabel,
              tone: notice.isPublished
                  ? AppBadgeTone.success
                  : AppBadgeTone.neutral,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            const Icon(LucideIcons.calendar,
                size: 16, color: AppColors.inkMuted),
            const SizedBox(width: AppSpacing.xxs),
            Text(formatCommunicationDate(date),
                style: text.bodySmall?.copyWith(color: AppColors.inkMuted)),
          ],
        ),
        const Divider(height: AppSpacing.xl),
        SelectableText(notice.content, style: text.bodyLarge),
        if (canPublish) ...[
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: 'Publicar aviso',
            icon: LucideIcons.send,
            isLoading: publishing,
            onPressed: publishing ? null : onPublish,
          ),
        ],
      ],
    );
  }
}
