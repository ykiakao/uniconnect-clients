import 'package:flutter/material.dart';

/// Light theme tokens from the UniConnect design kit (`tokens.json`).
///
/// The older names (`primarySoft`, `muted`, `dark`...) are kept as aliases
/// so every screen picks up the kit palette without changing its API.
class AppColors {
  // Brand.
  static const navy = Color(0xFF052453);
  static const blue = Color(0xFF277AFC);
  static const blueSoft = Color(0xFF60A5FA);

  // Surfaces and text.
  static const surface = Color(0xFFFFFFFF);
  static const surfaceRaised = Color(0xFFF8FAFC);
  static const surface200 = Color(0xFFE2E8F0);
  static const line = Color(0xFFE2E8F0);
  static const lineStrong = Color(0xFF64748B);
  static const ink = Color(0xFF0F172A);
  static const inkMuted = Color(0xFF475569);

  // Interaction.
  static const primary = Color(0xFF1A5FD6);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryTint = Color(0xFFDBEAFE);
  static const focusRing = Color(0xFF1A5FD6);

  // Status.
  static const success = Color(0xFF15803D);
  static const successTint = Color(0xFFDCFCE7);
  static const warning = Color(0xFFB45309);
  static const warningTint = Color(0xFFFEF3C7);
  static const danger = Color(0xFFB91C1C);
  static const dangerTint = Color(0xFFFEE2E2);

  // Aliases kept for existing screens.
  static const primaryDark = navy;
  static const primarySoft = primaryTint;
  static const secondary = blue;
  static const secondarySoft = primaryTint;
  static const dark = ink;
  static const muted = inkMuted;
  static const background = surface;
  static const card = surfaceRaised;
  static const border = line;
  static const shadow = Color(0x140F172A);
  static const successSoft = successTint;
  static const warningSoft = warningTint;
  static const dangerSoft = dangerTint;
  static const info = primary;
  static const infoSoft = primaryTint;
}
