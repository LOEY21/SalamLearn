import 'package:flutter/material.dart';

import 'app_colors.dart';

/// "Madrasah Classic" theme: cream canvas, deep teal actions, soft tinted
/// panels, gentle 12–16px radii, subtle borders — clean and school-like.
abstract final class AppTheme {
  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.teal,
      onPrimary: Colors.white,
      secondary: AppColors.gold,
      onSecondary: AppColors.ink,
      tertiary: AppColors.coral,
      onTertiary: Colors.white,
      error: AppColors.danger,
      onError: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      surfaceContainerHighest: AppColors.creamDark,
      outline: AppColors.creamBorder,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.cream,
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.cream,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.ink,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.creamBorder),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.teal,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.teal,
          minimumSize: const Size(64, 52),
          side: const BorderSide(color: AppColors.teal, width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.teal),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.teal,
        thumbColor: AppColors.teal,
        inactiveTrackColor: AppColors.mintBorder,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.teal
              : Colors.transparent,
        ),
        side: const BorderSide(color: AppColors.teal, width: 1.6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base) {
    return base.copyWith(
      displayLarge: base.displayLarge!.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: AppColors.ink,
      ),
      headlineMedium: base.headlineMedium!.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
      titleLarge: base.titleLarge!.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
      bodyLarge: base.bodyLarge!.copyWith(fontSize: 15, color: AppColors.ink),
      bodyMedium:
          base.bodyMedium!.copyWith(fontSize: 14, color: AppColors.textMuted),
      labelSmall:
          base.labelSmall!.copyWith(fontSize: 12, color: AppColors.textMuted),
    );
  }

  /// Kid-facing text theme for the Learner Hub subtree only — Fredoka for
  /// headings/stats, Nunito for body text, per the Adventure Map design
  /// spec's typography section. Parent/Teacher screens keep `light()`'s
  /// default Material text theme untouched.
  ///
  /// Pass the already-`_textTheme`'d theme as `base` (e.g.
  /// `AppTheme.light().textTheme`), not the raw Material default — this
  /// method only swaps `fontFamily`/`fontWeight`/`color` on top of the
  /// sizes `_textTheme` already set, it doesn't set its own `fontSize`.
  ///
  /// Cairo (registered in pubspec.yaml alongside these) has no slot here —
  /// Flutter's `TextTheme` has no Arabic-script-specific style, so it must
  /// be applied directly via `TextStyle(fontFamily: 'Cairo')` wherever
  /// Arabic text renders, not through this theme object.
  static TextTheme learnerTextTheme(TextTheme base) {
    return base.copyWith(
      displayLarge: base.displayLarge!.copyWith(
        fontFamily: 'Fredoka',
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
      headlineMedium: base.headlineMedium!.copyWith(
        fontFamily: 'Fredoka',
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
      titleLarge: base.titleLarge!.copyWith(
        fontFamily: 'Baloo2',
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
      bodyLarge: base.bodyLarge!.copyWith(
        fontFamily: 'Nunito',
        color: AppColors.ink,
      ),
      bodyMedium: base.bodyMedium!.copyWith(
        fontFamily: 'Nunito',
        color: AppColors.textMuted,
      ),
      labelSmall: base.labelSmall!.copyWith(
        fontFamily: 'Nunito',
        color: AppColors.textMuted,
      ),
    );
  }
}
