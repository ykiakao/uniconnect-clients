import 'package:flutter/material.dart';

import 'app_back_button.dart';

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppHeader({
    super.key,
    required this.title,
    this.fallbackRoute,
    this.actions,
  });

  final String title;
  final String? fallbackRoute;
  final List<Widget>? actions;

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
      actions: actions,
    );
  }
}
