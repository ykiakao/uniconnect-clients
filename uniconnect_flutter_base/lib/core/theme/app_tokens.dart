import 'package:flutter/material.dart';

/// Corner radii from the design kit: controls `md`, cards `lg`, heroes `xl`.
class AppRadius {
  static const sm = 6.0;
  static const md = 10.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const pill = 999.0;
}

class AppSizes {
  /// The kit asks for 44px controls on the app; Material keeps a 48px
  /// touch target around them.
  static const buttonHeight = 44.0;
  static const secondaryButtonHeight = 44.0;
  static const inputMinHeight = 44.0;
  static const touchTarget = 48.0;
  static const avatar = 44.0;
  static const avatarLarge = 56.0;
  static const iconTile = 40.0;
  static const contentMaxWidth = 560.0;
}

class AppShadows {
  /// `shadow-sm`: cards at rest.
  static const card = [
    BoxShadow(color: Color(0x0F0F172A), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x140F172A), blurRadius: 3, offset: Offset(0, 1)),
  ];

  /// `shadow-md`: only for what floats (menus, sheets, dialogs).
  static const elevated = [
    BoxShadow(color: Color(0x1A0F172A), blurRadius: 24, offset: Offset(0, 8)),
  ];
}
