import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../models/booking.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'status_badge.dart';

bool isOldBooking(String status) => status == 'cancelled' || status == 'completed';

bool canCancelBooking(String status) =>
    status == 'pending' ||
    status == 'pending_owner_approval' ||
    status == 'confirmed';

String bookingStatusLabel(String status, AppLocalizations loc) {
  switch (status) {
    case 'pending':
    case 'pending_owner_approval':
      return loc.statusPendingStation;
    case 'pending_customer_approval':
      return loc.statusPendingCustomer;
    case 'confirmed':
      return loc.statusConfirmed;
    case 'completed':
      return loc.statusCompleted;
    case 'cancelled':
      return loc.statusCancelled;
    default:
      return status;
  }
}

class BookingCard extends StatelessWidget {
  final Booking booking;
  final String statusLabel;
  final Color statusColor;
  final bool canCancel;
  final VoidCallback onCancel;
  final VoidCallback? onRate;
  final VoidCallback? onAcceptPostpone;
  final VoidCallback? onRejectPostpone;

  const BookingCard({
    super.key,
    required this.booking,
    required this.statusLabel,
    required this.statusColor,
    required this.canCancel,
    required this.onCancel,
    this.onRate,
    this.onAcceptPostpone,
    this.onRejectPostpone,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${loc.bookingNumberPrefix}${booking.bookingNumber}',
                  style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                ),
                StatusBadge(status: booking.status, label: statusLabel),
              ],
            ),
            const Divider(height: AppSpacing.lg),

            BookingInfoRow(icon: Icons.local_car_wash, text: booking.stationName),
            const SizedBox(height: AppSpacing.xs),
            BookingInfoRow(icon: Icons.build_circle_outlined, text: booking.serviceName),
            const SizedBox(height: AppSpacing.xs),
            BookingInfoRow(
              icon: Icons.calendar_today,
              text: '${booking.bookingDate}  ${booking.bookingTime}',
            ),
            if (booking.price != null) ...[
              const SizedBox(height: AppSpacing.xs),
              BookingInfoRow(
                icon: Icons.attach_money,
                text: '${booking.price!.toStringAsFixed(0)}${loc.servicePriceCurrencySuffix}',
              ),
            ],

            if (booking.proposedDate != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.warningSurface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.schedule, color: AppColors.warning, size: 16),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        '${loc.proposedTimePrefix}${booking.proposedDate}  ${booking.proposedTime ?? ''}',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.warning),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (booking.customerRating != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 18),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '${loc.yourRatingPrefix}${booking.customerRating}/5',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ],

            if (onAcceptPostpone != null || onRejectPostpone != null || canCancel || onRate != null) ...[
              const SizedBox(height: AppSpacing.sm),
              if (onAcceptPostpone != null) ...[
                ElevatedButton.icon(
                  onPressed: onAcceptPostpone,
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: Text(loc.acceptPostponeBtn),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 44),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              if (onRejectPostpone != null) ...[
                ElevatedButton.icon(
                  onPressed: onRejectPostpone,
                  icon: const Icon(Icons.schedule_outlined, size: 18),
                  label: Text(loc.rejectPostponeBtn),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 44),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              Row(
                children: [
                  if (onRate != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onRate,
                        icon: const Icon(Icons.star_outline, size: 18),
                        label: Text(loc.rateServiceBtn),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.amber),
                      ),
                    ),
                  if (onRate != null && canCancel) const SizedBox(width: AppSpacing.sm),
                  if (canCancel)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onCancel,
                        icon: const Icon(Icons.cancel_outlined, size: 18),
                        label: Text(loc.cancelButton),
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class BookingInfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const BookingInfoRow({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(text, style: AppTextStyles.bodyMedium)),
      ],
    );
  }
}
