import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/academic_content.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/error_state_widget.dart';
import '../../auth/models/app_user.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/communication_models.dart';
import '../providers/communication_providers.dart';
import 'communication_ui.dart';

class NoticesPage extends ConsumerStatefulWidget {
  const NoticesPage({super.key});

  @override
  ConsumerState<NoticesPage> createState() => _NoticesPageState();
}

class _NoticesPageState extends ConsumerState<NoticesPage> {
  String _view = 'active';

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(currentUserProvider)?.role;
    final isTeacher = role == UserRole.teacher;
    final views = isTeacher
        ? const [('active', 'Recebidos'), ('managed', 'Meus avisos')]
        : const [('active', 'Ativos'), ('history', 'Anteriores')];
    final notices = ref.watch(noticesProvider(_view));

    return Scaffold(
      appBar: AppHeader(title: 'Avisos', fallbackRoute: homeRouteFor(role)),
      body: SafeArea(
        child: AcademicContent(
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(noticesProvider(_view).future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageHorizontal,
                AppSpacing.pageTop,
                AppSpacing.pageHorizontal,
                AppSpacing.pageBottom,
              ),
              children: [
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final (value, label) in views)
                      ChoiceChip(
                        label: Text(label),
                        showCheckmark: false,
                        selected: _view == value,
                        onSelected: (_) => setState(() => _view = value),
                      ),
                  ],
                ),
                if (isTeacher) ...[
                  const SizedBox(height: AppSpacing.sm),
                  FilledButton.icon(
                    onPressed: () => context.push(AppRoutes.noticeNew),
                    icon: const Icon(LucideIcons.plus),
                    label: const Text('Novo aviso da turma'),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                notices.when(
                  skipLoadingOnRefresh: false,
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: LinearProgressIndicator(
                        semanticsLabel: 'Carregando avisos'),
                  ),
                  error: (error, _) => ErrorStateWidget(
                    title: 'Não foi possível carregar os avisos',
                    error: communicationErrorText(error),
                    onRetry: () => ref.invalidate(noticesProvider(_view)),
                  ),
                  data: (items) => items.isEmpty
                      ? EmptyStateWidget(
                          icon: LucideIcons.bell,
                          title: 'Nenhum aviso por aqui',
                          subtitle: _view == 'managed'
                              ? 'Os avisos que você criar para suas turmas aparecem aqui.'
                              : 'Quando a instituição ou seus professores publicarem avisos, eles aparecem aqui.',
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final notice in items)
                              _NoticeCard(notice: notice),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.notice});

  final AppNotice notice;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final date = notice.publishedAt ?? notice.createdAt;
    return AppCard(
      onTap: () => context.push('/avisos/${Uri.encodeComponent(notice.id)}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(notice.title, style: text.titleMedium)),
              if (notice.isUnread) ...[
                const SizedBox(width: AppSpacing.xs),
                const AppBadge(label: 'Novo', tone: AppBadgeTone.info),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text('${notice.audienceLabel} • ${formatCommunicationDate(date)}',
              style: text.bodySmall?.copyWith(color: AppColors.inkMuted)),
          if (notice.content.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(notice.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.bodyMedium?.copyWith(color: AppColors.inkMuted)),
          ],
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              NoticePriorityBadge(priority: notice.priority),
              if (!notice.isPublished)
                AppBadge(label: notice.stateLabel, tone: AppBadgeTone.neutral),
            ],
          ),
        ],
      ),
    );
  }
}
