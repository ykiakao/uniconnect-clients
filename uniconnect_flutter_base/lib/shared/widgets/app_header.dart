import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/constants/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../features/communication/providers/communication_providers.dart';
import 'app_back_button.dart';

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppHeader({
    super.key,
    required this.title,
    this.fallbackRoute,
    this.actions,
    this.showProfile = false,
  });

  final String title;
  final String? fallbackRoute;
  final List<Widget>? actions;
  final bool showProfile;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: fallbackRoute != null,
      leading: fallbackRoute == null
          ? null
          : AppBackButton(fallbackRoute: fallbackRoute!),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: [
        ...?actions,
        if (showProfile) const _NotificationsButton(),
        if (showProfile)
          IconButton(
            tooltip: 'Meu perfil',
            onPressed: () => GoRouter.maybeOf(context)?.push(AppRoutes.profile),
            icon: const Icon(LucideIcons.userRound),
          ),
        const SizedBox(width: 4),
      ],
    );
  }
}

/// Bell with the unread count; it stays quiet when the count is unknown.
class _NotificationsButton extends ConsumerWidget {
  const _NotificationsButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationsProvider).asData?.value ?? 0;
    final label =
        unread == 0 ? 'Notificações' : 'Notificações, $unread não lidas';
    return IconButton(
      tooltip: label,
      onPressed: () => GoRouter.maybeOf(context)?.push(AppRoutes.notifications),
      icon: Badge(
        isLabelVisible: unread > 0,
        backgroundColor: AppColors.danger,
        label: Text(unread > 99 ? '99+' : '$unread'),
        child: const Icon(LucideIcons.bell),
      ),
    );
  }
}
