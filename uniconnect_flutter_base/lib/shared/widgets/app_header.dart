import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_routes.dart';

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
      title: Text(title),
      actions: [
        ...?actions,
        if (showProfile)
          IconButton(
            tooltip: 'Meu perfil',
            onPressed: () => GoRouter.maybeOf(context)?.push(AppRoutes.profile),
            icon: const Icon(Icons.person_outline),
          ),
      ],
    );
  }
}
