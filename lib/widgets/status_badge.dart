import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Reusable pill-shaped badge that renders a booking status with the
/// appropriate semantic color from [AppColors].
///
/// Accepts raw Supabase booking status strings:
///   `pending`, `pending_owner_approval`, `pending_customer_approval`,
///   `confirmed`, `completed`, `cancelled`.
///
/// The [label] parameter overrides the status text if supplied.
/// When omitted the widget uses [status] as-is; callers should pass a
/// localized string via `AppLocalizations` for the visible text.
///
/// Example:
/// ```dart
/// StatusBadge(status: booking.status, label: _statusLabel(booking.status, loc))
/// ```
class StatusBadge extends StatelessWidget {
  final String status;
  final String? label;

  const StatusBadge({
    super.key,
    required this.status,
    this.label,
  });

  Color get _badgeColor {
    switch (status) {
      case 'pending':
      case 'pending_owner_approval':
        return AppColors.statusPending;
      case 'pending_customer_approval':
        return AppColors.statusPendingCustomer;
      case 'confirmed':
        return AppColors.statusConfirmed;
      case 'completed':
        return AppColors.statusCompleted;
      case 'cancelled':
        return AppColors.statusCancelled;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _badgeColor;
    final text = label ?? status;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: AppTextStyles.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
