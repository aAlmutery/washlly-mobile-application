import 'package:flutter/material.dart';

/// Single source of truth for all brand colors in Washlly.
///
/// All colors are `const` so they can be used in `const` constructors and
/// referenced without a `BuildContext`. Semantic assignments — e.g. using
/// `Theme.of(context).colorScheme` — are handled in [AppTheme].
abstract final class AppColors {
  // ─── Primary brand palette ─────────────────────────────────────────────────
  /// Main brand blue — replaces every `Colors.blue.shade800` across the app.
  static const Color primary = Color(0xFF1565C0);

  /// Lighter interactive state (hover / pressed overlay).
  static const Color primaryLight = Color(0xFF1976D2);

  /// Darker variant for headers / hero areas.
  static const Color primaryDark = Color(0xFF0D47A1);

  /// Very light blue tint for card backgrounds, badges, info chips.
  static const Color primarySurface = Color(0xFFE3F0FC);

  // ─── Semantic / status ─────────────────────────────────────────────────────
  static const Color success = Color(0xFF2E7D32);
  static const Color successSurface = Color(0xFFE8F5E9);

  static const Color warning = Color(0xFFE65100);
  static const Color warningSurface = Color(0xFFFFF3E0);

  static const Color error = Color(0xFFC62828);
  static const Color errorSurface = Color(0xFFFFEBEE);

  static const Color info = Color(0xFF0277BD);
  static const Color infoSurface = Color(0xFFE1F5FE);

  // ─── Booking status palette ────────────────────────────────────────────────
  /// pending / pending_owner_approval
  static const Color statusPending = Color(0xFFE65100);

  /// confirmed
  static const Color statusConfirmed = Color(0xFF2E7D32);

  /// completed
  static const Color statusCompleted = Color(0xFF1565C0);

  /// cancelled
  static const Color statusCancelled = Color(0xFF757575);

  /// pending_customer_approval
  static const Color statusPendingCustomer = Color(0xFF4A148C);

  // ─── Neutral / text ────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textDisabled = Color(0xFFBDBDBD);

  /// Card / surface background
  static const Color surfaceCard = Color(0xFFFFFFFF);

  /// Subtle divider line
  static const Color divider = Color(0xFFE5E7EB);

  // ─── Dark-mode surface overrides (used in AppTheme.dark()) ────────────────
  static const Color surfaceDark = Color(0xFF121212);
  static const Color surfaceCardDark = Color(0xFF1E1E1E);
}
