/// Spacing and border-radius design tokens for Washlly.
///
/// Use these constants everywhere instead of magic pixel numbers.
///
/// Example:
/// ```dart
/// Padding(
///   padding: const EdgeInsets.all(AppSpacing.md),
///   child: ...,
/// )
/// ```
abstract final class AppSpacing {
  // ─── Spacing scale ─────────────────────────────────────────────────────────
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  // ─── Border-radius scale ───────────────────────────────────────────────────
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 24;

  /// Full pill / circle shape (large enough to always be fully rounded).
  static const double radiusFull = 100;
}
