import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../models/booking.dart';
import '../../models/customer_session.dart';
import '../../services/supabase_service.dart';

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

  @override
  void initState() {
    super.initState();
    _bookingsFuture = _load();
  }

  Future<List<Map<String, dynamic>>> _load() =>
      SupabaseService.instance.fetchCustomerBookings(widget.session.customerPhone);

  void _refresh() => setState(() => _bookingsFuture = _load());

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
      await SupabaseService.instance.cancelMapBooking(
        bookingId: bookingId,
        customerPhone: widget.session.customerPhone,
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

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
      case 'pending_owner_approval':
      case 'pending_customer_approval':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  bool _canCancel(String status) =>
      status == 'pending' ||
      status == 'pending_owner_approval' ||
      status == 'pending_customer_approval' ||
      status == 'confirmed';

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
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      loc.historyLoadError,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
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

          final rawList = snapshot.data ?? [];
          if (rawList.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    loc.noBookingsYet,
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final bookings = rawList.map((b) => Booking.fromJson(b)).toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final b = bookings[index];
              return _BookingCard(
                booking: b,
                statusLabel: _statusLabel(b.status, loc),
                statusColor: _statusColor(b.status),
                canCancel: _canCancel(b.status),
                onCancel: () => _cancel(b.id),
                onRate: b.status == 'completed' && b.customerRating == null
                    ? () => _showRateDialog(b.id)
                    : null,
                onAcceptPostpone: b.status == 'pending_customer_approval'
                    ? () => _acceptPostpone(b.id)
                    : null,
              );
            },
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

  const _BookingCard({
    required this.booking,
    required this.statusLabel,
    required this.statusColor,
    required this.canCancel,
    required this.onCancel,
    this.onRate,
    this.onAcceptPostpone,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${loc.bookingNumberPrefix}${booking.bookingNumber}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),

            // Station & service
            _InfoRow(icon: Icons.local_car_wash, text: booking.stationName),
            const SizedBox(height: 6),
            _InfoRow(icon: Icons.build_circle_outlined, text: booking.serviceName),
            const SizedBox(height: 6),
            _InfoRow(
              icon: Icons.calendar_today,
              text: '${booking.bookingDate}  ${booking.bookingTime}',
            ),
            if (booking.price != null) ...[
              const SizedBox(height: 6),
              _InfoRow(
                icon: Icons.attach_money,
                text: '${booking.price!.toStringAsFixed(0)}${loc.servicePriceCurrencySuffix}',
              ),
            ],

            // Proposed date/time when owner requests postponement
            if (booking.proposedDate != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.schedule, color: Colors.orange, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${loc.proposedTimePrefix}${booking.proposedDate}  ${booking.proposedTime ?? ''}',
                        style: const TextStyle(fontSize: 13, color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Star rating if already rated
            if (booking.customerRating != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    '${loc.yourRatingPrefix}${booking.customerRating}/5',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ],

            // Action buttons
            if (onAcceptPostpone != null || canCancel || onRate != null) ...[
              const SizedBox(height: 12),
              if (onAcceptPostpone != null) ...[
                ElevatedButton.icon(
                  onPressed: onAcceptPostpone,
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: Text(loc.acceptPostponeBtn),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 44),
                  ),
                ),
                const SizedBox(height: 8),
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
                  if (onRate != null && canCancel) const SizedBox(width: 8),
                  if (canCancel)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onCancel,
                        icon: const Icon(Icons.cancel_outlined, size: 18),
                        label: Text(loc.cancelButton),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
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
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 14)),
        ),
      ],
    );
  }
}
