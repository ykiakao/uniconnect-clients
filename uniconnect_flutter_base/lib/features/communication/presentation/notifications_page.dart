import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/academic_content.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/error_state_widget.dart';
import '../../auth/models/app_user.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/communication_models.dart';
import '../providers/communication_providers.dart';
import 'communication_ui.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentUserProvider)?.role;
    final notifications = ref.watch(notificationsProvider);
    return Scaffold(
      appBar:
          AppHeader(title: 'Notificações', fallbackRoute: homeRouteFor(role)),
      body: SafeArea(
        child: AcademicContent(
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(notificationsProvider.future),
            child: notifications.when(
              skipLoadingOnRefresh: false,
              loading: () => const Center(
                  child: CircularProgressIndicator(
                      semanticsLabel: 'Carregando notificações')),
              error: (error, _) => ErrorStateWidget(
                title: 'Não foi possível carregar as notificações',
                error: communicationErrorText(error),
                onRetry: () => ref.invalidate(notificationsProvider),
              ),
              data: (items) => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageHorizontal,
                  AppSpacing.pageTop,
                  AppSpacing.pageHorizontal,
                  AppSpacing.pageBottom,
                ),
                children: [
                  if (items.isEmpty)
                    const EmptyStateWidget(
                      icon: LucideIcons.bell,
                      title: 'Tudo em dia',
                      subtitle:
                          'Avisos, atividades e mensagens novas aparecem aqui.',
                    )
                  else
                    for (final item in items)
                      _NotificationTile(item: item, role: role),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.item, required this.role});

  final AppNotification item;
  final UserRole? role;

  IconData get _icon => switch (item.resourceType) {
        'notice' => LucideIcons.bell,
        'activity' => LucideIcons.clipboardList,
        'grade' => LucideIcons.graduationCap,
        'message' => LucideIcons.messageSquareMore,
        _ => LucideIcons.info,
      };

  String? get _destination {
    final teacher = role == UserRole.teacher;
    return switch (item.resourceType) {
      'notice' => '/avisos/${Uri.encodeComponent(item.resourceId)}',
      'activity' => teacher
          ? AppRoutes.teacherActivities
          : '/atividades/${Uri.encodeComponent(item.resourceId)}',
      'grade' => teacher ? AppRoutes.teacherGrades : AppRoutes.grades,
      'message' => chatRouteFor(role),
      _ => null,
    };
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final router = GoRouter.maybeOf(context);
    if (item.isUnread) {
      try {
        await ref
            .read(communicationServiceProvider)
            .markNotificationRead(item.id);
        ref.invalidate(notificationsProvider);
        ref.invalidate(unreadNotificationsProvider);
      } catch (_) {
        // Opening the destination still helps even if marking failed.
      }
    }
    final destination = _destination;
    if (destination != null) router?.push(destination);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      backgroundColor: item.isUnread ? AppColors.surface : null,
      onTap: () => _open(context, ref),
      child: Row(
        children: [
          IconTile(
            icon: _icon,
            color: item.isUnread ? AppColors.primary : AppColors.inkMuted,
            background:
                item.isUnread ? AppColors.primaryTint : AppColors.surface200,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: text.titleSmall),
                Text(formatCommunicationDate(item.createdAt),
                    style: text.bodySmall?.copyWith(color: AppColors.inkMuted)),
              ],
            ),
          ),
          if (item.isUnread)
            Semantics(
              label: 'Não lida',
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                    color: AppColors.primary, shape: BoxShape.circle),
              ),
            ),
        ],
      ),
    );
  }
}
