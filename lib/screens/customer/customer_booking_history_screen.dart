import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../models/booking.dart';
import '../../models/customer_session.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/status_badge.dart';

/// Returns true when a booking with [status] can still be cancelled by the customer.
/// Extracted as a top-level function so it can be unit-tested independently.
bool canCancelBooking(String status) =>
    status == 'pending' ||
    status == 'pending_owner_approval' ||
    status == 'confirmed';
// Note: pending_customer_approval is handled by the dedicated Reject New Time button.

class CustomerBookingHistoryScreen extends StatefulWidget {
  final CustomerSession session;

  const CustomerBookingHistoryScreen({super.key, required this.session});

  @override
  State<CustomerBookingHistoryScreen> createState() =>
      _CustomerBookingHistoryScreenState();
}

class _CustomerBookingHistoryScreenState
    extends State<CustomerBookingHistoryScreen> {
  late Future<List<Map<String, dynamic>>> _bookingsFuture;
  List<Map<String, dynamic>>? _cachedData;

  @override
  void initState() {
    super.initState();
    _bookingsFuture = _load();
  }

  Future<List<Map<String, dynamic>>> _load() =>
      SupabaseService.instance.fetchCustomerBookings(
        widget.session.customerPhone,
        sessionToken: widget.session.sessionToken,
      );

  void _refresh() => setState(() { _bookingsFuture = _load(); });

  Future<void> _cancel(String bookingId) async {
    final loc = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.cancelBookingTitle),
        content: Text(loc.cancelBookingConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(loc.noBtn),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(loc.yesCancelBtn, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await SupabaseService.instance.customerManageBooking(
        bookingId: bookingId,
        action: 'cancel',
        customerPhone: widget.session.customerPhone,
        sessionToken: widget.session.sessionToken,
      );
      _refresh();
      if (mounted) {
        final loc2 = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc2.cancelBookingSuccess)),
        );
      }
    } catch (e) {
      if (mounted) {
        final loc2 = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${loc2.cancelBookingFailed}$e')),
        );
      }
    }
  }

  Future<void> _rejectPostpone(String bookingId) async {
    final loc = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.rejectPostponeTitle),
        content: Text(loc.rejectPostponeConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(loc.noBtn),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(loc.rejectPostponeBtn, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await SupabaseService.instance.customerManageBooking(
        bookingId: bookingId,
        action: 'reject_postpone',
        customerPhone: widget.session.customerPhone,
        sessionToken: widget.session.sessionToken,
      );
      _refresh();
      if (mounted) {
        final loc2 = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc2.rejectPostponeSuccess)),
        );
      }
    } catch (e) {
      if (mounted) {
        final loc2 = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${loc2.rejectPostponeFailed}$e')),
        );
      }
    }
  }

  Future<void> _acceptPostpone(String bookingId) async {
    final loc = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.acceptPostponeTitle),
        content: Text(loc.acceptPostponeConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(loc.noBtn),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text(loc.yesAcceptBtn, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await SupabaseService.instance.customerManageBooking(
        bookingId: bookingId,
        action: 'accept_postpone',
        customerPhone: widget.session.customerPhone,
        sessionToken: widget.session.sessionToken,
      );
      _refresh();
      if (mounted) {
        final loc2 = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc2.acceptPostponeSuccess)),
        );
      }
    } catch (e) {
      if (mounted) {
        final loc2 = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${loc2.acceptPostponeFailed}$e')),
        );
      }
    }
  }

  void _showRateDialog(String bookingId) {
    final loc = AppLocalizations.of(context)!;
    int selectedRating = 0;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(loc.rateServiceTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(loc.rateServicePrompt),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final star = i + 1;
                  return IconButton(
                    icon: Icon(
                      star <= selectedRating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 36,
                    ),
                    onPressed: () => setDialogState(() => selectedRating = star),
                  );
                }),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(loc.cancelButton),
            ),
            ElevatedButton(
              onPressed: selectedRating == 0
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      try {
                        await SupabaseService.instance.customerSubmitRating(
                          bookingId: bookingId,
                          customerPhone: widget.session.customerPhone,
                          sessionToken: widget.session.sessionToken,
                          rating: selectedRating,
                        );
                        _refresh();
                        if (mounted) {
                          final loc2 = AppLocalizations.of(context)!;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(loc2.rateSuccess)),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          final loc2 = AppLocalizations.of(context)!;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${loc2.rateFailed}$e')),
                          );
                        }
                      }
                    },
              child: Text(loc.submitBtn),
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(String status, AppLocalizations loc) {
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

  bool _canCancel(String status) => canCancelBooking(status);

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.historyTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: loc.refreshTooltip,
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _bookingsFuture,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            _cachedData = snapshot.data;
          }

          if (snapshot.connectionState == ConnectionState.waiting &&
              _cachedData == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError && _cachedData == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      loc.historyLoadError,
                      style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ElevatedButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      label: Text(loc.retryButton),
                    ),
                  ],
                ),
              ),
            );
          }

          final rawList = _cachedData ?? [];
          if (rawList.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today, size: 64, color: AppColors.textDisabled),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    loc.noBookingsYet,
                    style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            );
          }

          final bookings = rawList.map((b) => Booking.fromJson(b)).toList();

          return Column(
            children: [
              if (snapshot.connectionState == ConnectionState.waiting)
                const LinearProgressIndicator(),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: bookings.length,
                  itemBuilder: (context, index) {
                    final b = bookings[index];
                    return _BookingCard(
                      booking: b,
                      statusLabel: _statusLabel(b.status, loc),
                      statusColor: b.statusColor,
                      canCancel: _canCancel(b.status),
                      onCancel: () => _cancel(b.id),
                      onRate: b.status == 'completed' && b.customerRating == null
                          ? () => _showRateDialog(b.id)
                          : null,
                      onAcceptPostpone: b.status == 'pending_customer_approval'
                          ? () => _acceptPostpone(b.id)
                          : null,
                      onRejectPostpone: b.status == 'pending_customer_approval'
                          ? () => _rejectPostpone(b.id)
                          : null,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Booking booking;
  final String statusLabel;
  final Color statusColor;
  final bool canCancel;
  final VoidCallback onCancel;
  final VoidCallback? onRate;
  final VoidCallback? onAcceptPostpone;
  final VoidCallback? onRejectPostpone;

  const _BookingCard({
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
            // Header row
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

            // Station & service
            _InfoRow(icon: Icons.local_car_wash, text: booking.stationName),
            const SizedBox(height: AppSpacing.xs),
            _InfoRow(icon: Icons.build_circle_outlined, text: booking.serviceName),
            const SizedBox(height: AppSpacing.xs),
            _InfoRow(
              icon: Icons.calendar_today,
              text: '${booking.bookingDate}  ${booking.bookingTime}',
            ),
            if (booking.price != null) ...[
              const SizedBox(height: AppSpacing.xs),
              _InfoRow(
                icon: Icons.attach_money,
                text: '${booking.price!.toStringAsFixed(0)}${loc.servicePriceCurrencySuffix}',
              ),
            ],

            // Proposed date/time when owner requests postponement
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

            // Star rating if already rated
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

            // Action buttons
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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

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
