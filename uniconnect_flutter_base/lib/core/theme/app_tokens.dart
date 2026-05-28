import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const pill = 999.0;
}

class AppSizes {
  static const buttonHeight = 52.0;
  static const secondaryButtonHeight = 48.0;
  static const inputMinHeight = 56.0;
  static const touchTarget = 48.0;
  static const avatar = 48.0;
  static const avatarLarge = 64.0;
  static const iconTile = 44.0;
  static const contentMaxWidth = 560.0;
}

class AppShadows {
  static const card = [
    BoxShadow(
      color: AppColors.shadow,
      blurRadius: 14,
      offset: Offset(0, 6),
    ),
  ];

  static const elevated = [
    BoxShadow(
      color: AppColors.shadow,
      blurRadius: 18,
      offset: Offset(0, 10),
    ),
  ];
}
