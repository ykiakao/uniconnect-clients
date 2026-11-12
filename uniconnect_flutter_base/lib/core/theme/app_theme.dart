import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'app_colors.dart';
import 'app_tokens.dart';

const _fontFamily = 'Inter';

/// Kit weights: titles 600/700, text 400. Inter SemiBold is not bundled yet,
/// so 600 currently resolves to the closest bundled weight.
const _semibold = FontWeight.w600;

class AppTheme {
  static ThemeData get lightTheme {
    final scheme = _colorScheme;
    final text = _textTheme;
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: _fontFamily,
      textTheme: text,
      scaffoldBackgroundColor: AppColors.surface,
      dividerTheme: const DividerThemeData(
        color: AppColors.line,
        thickness: 1,
        space: 1,
      ),
      iconTheme: const IconThemeData(color: AppColors.ink, size: 24),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleSpacing: 16,
        shape: const Border(bottom: BorderSide(color: AppColors.line)),
        titleTextStyle: text.titleLarge,
      ),
      inputDecorationTheme: _inputTheme(text),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: _primaryButton(text, controlShape),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: _primaryButton(text, controlShape),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, AppSizes.secondaryButtonHeight),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          foregroundColor: AppColors.ink,
          backgroundColor: AppColors.surface,
          disabledForegroundColor: AppColors.inkMuted,
          side: const BorderSide(color: AppColors.line),
          textStyle: text.labelLarge,
          iconSize: 20,
          shape: controlShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, AppSizes.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          foregroundColor: AppColors.primary,
          textStyle: text.labelLarge,
          iconSize: 20,
          shape: controlShape,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.ink,
          iconSize: 22,
          shape: controlShape,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceRaised,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.line),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.primaryTint,
        disabledColor: AppColors.surface200,
        labelStyle: text.labelMedium?.copyWith(color: AppColors.ink),
        secondaryLabelStyle: text.labelMedium?.copyWith(
          color: AppColors.primary,
        ),
        side: const BorderSide(color: AppColors.line),
        checkmarkColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: const StadiumBorder(),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        selectedIcon: const Icon(LucideIcons.check, size: 16),
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          textStyle: WidgetStatePropertyAll(text.labelMedium),
          side: const WidgetStatePropertyAll(
            BorderSide(color: AppColors.line),
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppColors.primaryTint
                : AppColors.surface,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.ink,
          ),
          shape: WidgetStatePropertyAll(controlShape),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        side: const BorderSide(color: AppColors.lineStrong, width: 1.5),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary
              : Colors.transparent,
        ),
      ),
      switchTheme: SwitchThemeData(
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        thumbColor: const WidgetStatePropertyAll(AppColors.surface),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.surface200,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.surface200,
        circularTrackColor: Colors.transparent,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.inkMuted,
        textColor: AppColors.ink,
        titleTextStyle: text.titleSmall,
        subtitleTextStyle: text.bodySmall?.copyWith(color: AppColors.inkMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        minVerticalPadding: 12,
        shape: controlShape,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: text.bodySmall?.copyWith(color: AppColors.surface),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: text.bodyMedium?.copyWith(color: AppColors.surface),
        actionTextColor: AppColors.blueSoft,
        shape: controlShape,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: AppColors.shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium?.copyWith(color: AppColors.inkMuted),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: AppColors.surface200,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: AppColors.shadow,
        textStyle: text.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: const BorderSide(color: AppColors.line),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 72,
        indicatorColor: AppColors.primaryTint,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.inkMuted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelSmall?.copyWith(
            letterSpacing: 0,
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.inkMuted,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  static const _colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    primaryContainer: AppColors.primaryTint,
    onPrimaryContainer: AppColors.primary,
    secondary: AppColors.navy,
    onSecondary: AppColors.onPrimary,
    secondaryContainer: AppColors.surface200,
    onSecondaryContainer: AppColors.ink,
    tertiary: AppColors.blue,
    onTertiary: AppColors.onPrimary,
    error: AppColors.danger,
    onError: AppColors.onPrimary,
    errorContainer: AppColors.dangerTint,
    onErrorContainer: AppColors.danger,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.inkMuted,
    surfaceContainerLowest: AppColors.surface,
    surfaceContainerLow: AppColors.surfaceRaised,
    surfaceContainer: AppColors.surfaceRaised,
    surfaceContainerHigh: AppColors.surface200,
    surfaceContainerHighest: AppColors.surface200,
    outline: AppColors.lineStrong,
    outlineVariant: AppColors.line,
    shadow: AppColors.shadow,
    inverseSurface: AppColors.ink,
    onInverseSurface: AppColors.surface,
    inversePrimary: AppColors.blueSoft,
  );

  /// Kit scale: h1 32, h2 24, h3 18, body-lg 17 (app), body 15, small 13.
  static final _textTheme = const TextTheme(
    displaySmall: TextStyle(
        fontSize: 40,
        height: 48 / 40,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8),
    headlineLarge: TextStyle(
        fontSize: 32,
        height: 40 / 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.48),
    headlineMedium: TextStyle(
        fontSize: 24,
        height: 32 / 24,
        fontWeight: _semibold,
        letterSpacing: -0.24),
    headlineSmall: TextStyle(
        fontSize: 20,
        height: 28 / 20,
        fontWeight: _semibold,
        letterSpacing: -0.2),
    titleLarge: TextStyle(fontSize: 18, height: 26 / 18, fontWeight: _semibold),
    titleMedium:
        TextStyle(fontSize: 16, height: 24 / 16, fontWeight: _semibold),
    titleSmall: TextStyle(fontSize: 15, height: 22 / 15, fontWeight: _semibold),
    bodyLarge: TextStyle(fontSize: 17, height: 26 / 17),
    bodyMedium: TextStyle(fontSize: 15, height: 24 / 15),
    bodySmall: TextStyle(fontSize: 13, height: 20 / 13),
    labelLarge: TextStyle(fontSize: 15, height: 20 / 15, fontWeight: _semibold),
    labelMedium:
        TextStyle(fontSize: 13, height: 18 / 13, fontWeight: _semibold),
    labelSmall: TextStyle(
        fontSize: 12,
        height: 16 / 12,
        fontWeight: _semibold,
        letterSpacing: 0.6),
  ).apply(
    fontFamily: _fontFamily,
    bodyColor: AppColors.ink,
    displayColor: AppColors.ink,
  );

  static ButtonStyle _primaryButton(TextTheme text, OutlinedBorder shape) {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
      disabledBackgroundColor: AppColors.surface200,
      disabledForegroundColor: AppColors.inkMuted,
      elevation: 0,
      minimumSize: const Size(64, AppSizes.buttonHeight),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      textStyle: text.labelLarge,
      iconSize: 20,
      shape: shape,
    );
  }

  static InputDecorationTheme _inputTheme(TextTheme text) {
    OutlineInputBorder border(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      labelStyle: text.bodyMedium?.copyWith(color: AppColors.inkMuted),
      floatingLabelStyle: text.labelMedium?.copyWith(color: AppColors.primary),
      hintStyle: text.bodyMedium?.copyWith(color: AppColors.inkMuted),
      helperStyle: text.bodySmall?.copyWith(color: AppColors.inkMuted),
      errorStyle: text.bodySmall?.copyWith(color: AppColors.danger),
      prefixIconColor: AppColors.inkMuted,
      suffixIconColor: AppColors.inkMuted,
      border: border(AppColors.lineStrong),
      enabledBorder: border(AppColors.lineStrong),
      disabledBorder: border(AppColors.line),
      focusedBorder: border(AppColors.focusRing, 2),
      errorBorder: border(AppColors.danger),
      focusedErrorBorder: border(AppColors.danger, 2),
    );
  }
}
