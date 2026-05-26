import 'package:flutter/material.dart';

/// Rationalized text-style scale for Washlly.
///
/// Colors are intentionally omitted — the theme's TextTheme.apply() injects
/// the correct color for light and dark mode. Widgets that render text on a
/// colored background (buttons, badges, app bar) apply color via copyWith.
abstract final class AppTextStyles {
  static const List<String> _fontFamilyFallback = ['Cairo', 'Roboto', 'sans-serif'];

  // ─── Display / Hero ────────────────────────────────────────────────────────

  /// 32 sp bold — welcome / onboarding hero titles.
  static const TextStyle displayLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    height: 1.25,
    fontFamilyFallback: _fontFamilyFallback,
  );

  // ─── Headline ──────────────────────────────────────────────────────────────

  /// 24 sp bold — section headings, stat values on owner dashboard.
  static const TextStyle headlineMedium = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    height: 1.3,
    fontFamilyFallback: _fontFamilyFallback,
  );

  // ─── Title ─────────────────────────────────────────────────────────────────

  /// 20 sp bold — screen titles, card headings.
  static const TextStyle titleLarge = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    height: 1.4,
    fontFamilyFallback: _fontFamilyFallback,
  );

  /// 18 sp semibold — station name, prominent labels, section sub-headings.
  static const TextStyle titleMedium = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.4,
    fontFamilyFallback: _fontFamilyFallback,
  );

  // ─── Body ──────────────────────────────────────────────────────────────────

  /// 16 sp regular — primary body text, card content.
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    height: 1.6,
    fontFamilyFallback: _fontFamilyFallback,
  );

  /// 14 sp regular — secondary text, addresses, info rows.
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    height: 1.5,
    fontFamilyFallback: _fontFamilyFallback,
  );

  /// 13 sp regular — supporting text, subtitles, helper text.
  static const TextStyle bodySmall = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.normal,
    height: 1.5,
    fontFamilyFallback: _fontFamilyFallback,
  );

  // ─── Label ─────────────────────────────────────────────────────────────────

  /// 14 sp semibold — button labels, tab labels, form labels.
  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0.1,
    fontFamilyFallback: _fontFamilyFallback,
  );

  /// 12 sp medium — status badges, chips, metadata, timestamps.
  static const TextStyle labelSmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.3,
    letterSpacing: 0.2,
    fontFamilyFallback: _fontFamilyFallback,
  );
}
