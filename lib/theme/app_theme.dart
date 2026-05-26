import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_text_styles.dart';

/// Builds the full Material 3 [ThemeData] for Washlly.
///
/// Usage in `main.dart`:
/// ```dart
/// MaterialApp(
///   theme: AppTheme.light(),
///   darkTheme: AppTheme.dark(),
/// )
/// ```
abstract final class AppTheme {
  // ─── Light theme ───────────────────────────────────────────────────────────

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primarySurface,
      onPrimaryContainer: AppColors.primaryDark,
      secondary: AppColors.primaryLight,
      onSecondary: Colors.white,
      surface: const Color(0xFFF8F9FA),
      onSurface: AppColors.textPrimary,
      error: AppColors.error,
      onError: Colors.white,
    );

    return _buildTheme(colorScheme);
  }

  // ─── Dark theme ────────────────────────────────────────────────────────────

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.primaryLight,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryDark,
      onPrimaryContainer: Colors.white,
      secondary: AppColors.primaryLight,
      onSecondary: Colors.white,
      surface: AppColors.surfaceDark,
      onSurface: Colors.white,
      error: const Color(0xFFEF9A9A),
      onError: Colors.black,
    );

    return _buildTheme(colorScheme);
  }

  // ─── Shared builder ────────────────────────────────────────────────────────

  static ThemeData _buildTheme(ColorScheme colorScheme) {
    final isDark = colorScheme.brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,

      // ── TextTheme ──────────────────────────────────────────────────────────
      textTheme: TextTheme(
        displayLarge: AppTextStyles.displayLarge,
        headlineMedium: AppTextStyles.headlineMedium,
        titleLarge: AppTextStyles.titleLarge,
        titleMedium: AppTextStyles.titleMedium,
        bodyLarge: AppTextStyles.bodyLarge,
        bodyMedium: AppTextStyles.bodyMedium,
        bodySmall: AppTextStyles.bodySmall,
        labelLarge: AppTextStyles.labelLarge,
        labelSmall: AppTextStyles.labelSmall,
      ).apply(
        bodyColor: isDark ? Colors.white : AppColors.textPrimary,
        displayColor: isDark ? Colors.white : AppColors.textPrimary,
      ),

      // ── AppBar ─────────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: AppTextStyles.titleLarge.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),

      // ── Card ───────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: 2,
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        color: isDark ? AppColors.surfaceCardDark : AppColors.surfaceCard,
        clipBehavior: Clip.antiAlias,
      ),

      // ── ElevatedButton ─────────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm + 4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          textStyle: AppTextStyles.labelLarge,
        ),
      ),

      // ── OutlinedButton ─────────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.primary),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm + 4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          textStyle: AppTextStyles.labelLarge,
        ),
      ),

      // ── FilledButton ───────────────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm + 4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          textStyle: AppTextStyles.labelLarge,
        ),
      ),

      // ── InputDecoration ────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? Colors.white.withAlpha(15)
            : AppColors.primarySurface.withAlpha(80),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 4,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        labelStyle: AppTextStyles.bodyMedium.copyWith(
          color: isDark ? Colors.white70 : AppColors.textSecondary,
        ),
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textDisabled,
        ),
      ),

      // ── BottomNavigationBar ────────────────────────────────────────────────
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor:
            isDark ? AppColors.surfaceCardDark : AppColors.surfaceCard,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: AppColors.textSecondary,
        selectedLabelStyle: AppTextStyles.labelSmall.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: AppTextStyles.labelSmall,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),

      // ── Chip ───────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        labelStyle: AppTextStyles.labelSmall,
      ),

      // ── Divider ────────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),

      // ── SnackBar ───────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        backgroundColor:
            isDark ? const Color(0xFF323232) : AppColors.textPrimary,
        contentTextStyle:
            AppTextStyles.bodyMedium.copyWith(color: Colors.white),
      ),
    );
  }
}
