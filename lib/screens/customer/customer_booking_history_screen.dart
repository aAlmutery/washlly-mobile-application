import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../models/booking.dart';
import '../../models/customer_session.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/booking_card.dart';

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
  bool _showOldBookings = false;

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

  Future<void> _markDone(String bookingId) async {
    final loc = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: Text(loc.customerMarkDoneConfirmTitle),
        content: Text(loc.customerMarkDoneConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(loc.noBtn),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: Text(loc.yesAcceptBtn, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await SupabaseService.instance.customerCompleteBooking(
        bookingId: bookingId,
        customerPhone: widget.session.customerPhone,
        sessionToken: widget.session.sessionToken,
      );
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.ownerCompleteSuccess),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.ownerCompleteFailed}$e')),
        );
      }
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

          final all = rawList.map((b) => Booking.fromJson(b)).toList();
          final active = all.where((b) => !isOldBooking(b.status)).toList();
          final old = all.where((b) => isOldBooking(b.status)).toList();
          final visible = [...active, if (_showOldBookings) ...old];

          return Column(
            children: [
              if (snapshot.connectionState == ConnectionState.waiting)
                const LinearProgressIndicator(),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: visible.length + (old.isNotEmpty ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == visible.length && old.isNotEmpty) {
                      return _ToggleOldBookingsButton(
                        count: old.length,
                        expanded: _showOldBookings,
                        onTap: () => setState(() => _showOldBookings = !_showOldBookings),
                      );
                    }
                    final b = visible[index];
                    return BookingCard(
                      booking: b,
                      statusLabel: bookingStatusLabel(b.status, loc),
                      statusColor: b.statusColor,
                      canCancel: _canCancel(b.status),
                      onCancel: () => _cancel(b.id),
                      onMarkDone: b.status == 'confirmed'
                          ? () => _markDone(b.id)
                          : null,
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

class _ToggleOldBookingsButton extends StatelessWidget {
  final int count;
  final bool expanded;
  final VoidCallback onTap;

  const _ToggleOldBookingsButton({
    required this.count,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 18,
              color: AppColors.primary,
            ),
            const SizedBox(width: 6),
            Text(
              expanded ? loc.hideOldBookings(count) : loc.showOldBookings(count),
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
