import 'package:flutter/material.dart';
import '../../models/booking.dart';
import '../../models/customer_notification.dart';
import '../../services/session_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/booking_card.dart';
import '../../widgets/bottom_nav_scaffold.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class InboxScreen extends StatefulWidget {
  static const routeName = '/inbox';

  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<Map<String, dynamic>> _inboxFuture;
  String customerPhone = '';
  String sessionToken = '';
  bool _markingAll = false;
  List<CustomerNotification> _notifications = [];
  bool _showOldBookings = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _inboxFuture = _initAndLoadInbox();
  }

  Future<Map<String, dynamic>> _initAndLoadInbox() async {
    final session = await SessionService.instance.loadCustomerSession();
    if (session == null) {
      return {'notifications': [], 'bookings': []};
    }
    customerPhone = session.customerPhone;
    sessionToken = session.sessionToken;
    final data = await _loadInbox();
    // Cache notifications in state so mark-all can update them without reloading.
    _notifications = (data['notifications'] as List? ?? [])
        .map((n) => CustomerNotification.fromJson(n as Map<String, dynamic>))
        .toList();
    return data;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _loadInbox() async {
    return await SupabaseService.instance.customerGetInbox(
      customerPhone: customerPhone,
      sessionToken: sessionToken,
    );
  }

  Future<void> _markAllRead() async {
    if (_markingAll || customerPhone.isEmpty) return;
    // Optimistic update — mark all as read in local state immediately.
    setState(() {
      _markingAll = true;
      _notifications = _notifications
          .map((n) => CustomerNotification(
                id: n.id,
                title: n.title,
                body: n.body,
                referenceBookingId: n.referenceBookingId,
                isRead: true,
                createdAt: n.createdAt,
              ))
          .toList();
    });
    try {
      await SupabaseService.instance.customerMarkNotificationRead(
        customerPhone: customerPhone,
        sessionToken: sessionToken,
        markAll: true,
      );
    } catch (_) {
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  void _markNotificationRead(String notificationId) {
    // Optimistic update — flip isRead locally, fire API in background.
    setState(() {
      _notifications = _notifications
          .map((n) => n.id == notificationId
              ? CustomerNotification(
                  id: n.id,
                  title: n.title,
                  body: n.body,
                  referenceBookingId: n.referenceBookingId,
                  isRead: true,
                  createdAt: n.createdAt,
                )
              : n)
          .toList();
    });
    SupabaseService.instance.customerMarkNotificationRead(
      customerPhone: customerPhone,
      sessionToken: sessionToken,
      notificationId: notificationId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavScaffold(
      currentIndex: 2,
      title: 'Inbox',
      notificationPhone: customerPhone.isNotEmpty ? customerPhone : null,
      body: FutureBuilder<Map<String, dynamic>>(
        future: _inboxFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final inboxData = snapshot.data ?? {};
          final bookings = (inboxData['bookings'] as List?)
                  ?.map((b) => Booking.fromJson(b as Map<String, dynamic>))
                  .toList() ??
              [];

          return Column(
            children: [
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Notifications'),
                  Tab(text: 'My Bookings'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Notifications Tab
                    _notifications.isEmpty
                        ? const Center(child: Text('No notifications'))
                        : Column(
                            children: [
                              if (_notifications.any((n) => !n.isRead))
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton.icon(
                                        onPressed: _markingAll ? null : _markAllRead,
                                        icon: _markingAll
                                            ? const SizedBox(
                                                width: 14,
                                                height: 14,
                                                child: CircularProgressIndicator(strokeWidth: 2),
                                              )
                                            : const Icon(Icons.done_all_rounded, size: 16),
                                        label: Text(
                                          AppLocalizations.of(context)!.markAllRead,
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                        style: TextButton.styleFrom(
                                          foregroundColor: AppColors.success,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              Expanded(
                                child: ListView.builder(
                                  padding: const EdgeInsets.all(AppSpacing.md),
                                  itemCount: _notifications.length,
                                  itemBuilder: (context, index) {
                              final notif = _notifications[index];
                              return GestureDetector(
                                onTap: () {
                                  if (!notif.isRead) {
                                    _markNotificationRead(notif.id);
                                  }
                                },
                                child: Card(
                                  color: notif.isRead
                                      ? null
                                      : Theme.of(context).brightness == Brightness.dark
                                          ? AppColors.success.withAlpha(30)
                                          : AppColors.successSurface,
                                  child: ListTile(
                                    title: Text(
                                      notif.title,
                                      style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Text(notif.body, style: AppTextStyles.bodySmall),
                                    trailing: !notif.isRead
                                        ? const Icon(Icons.circle, color: AppColors.success, size: 12)
                                        : null,
                                    contentPadding: const EdgeInsets.all(AppSpacing.md),
                                  ),
                                ),
                              );
                                  },
                                ),
                              ),
                            ],
                          ),
                    // Bookings Tab
                    bookings.isEmpty
                        ? const Center(child: Text('No bookings'))
                        : Builder(builder: (context) {
                            final loc = AppLocalizations.of(context)!;
                            final active = bookings.where((b) => !isOldBooking(b.status)).toList();
                            final old = bookings.where((b) => isOldBooking(b.status)).toList();
                            final visible = [...active, if (_showOldBookings) ...old];
                            return ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: visible.length + (old.isNotEmpty ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == visible.length && old.isNotEmpty) {
                                  return _InboxToggleOldButton(
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
                                  canCancel: canCancelBooking(b.status),
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
                            );
                          }),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _refreshAll() => setState(() => _inboxFuture = _initAndLoadInbox());

  Future<void> _cancel(String bookingId) async {
    final loc = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.cancelBookingTitle),
        content: Text(loc.cancelBookingConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(loc.noBtn)),
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
        customerPhone: customerPhone,
        sessionToken: sessionToken,
      );
      _refreshAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.cancelBookingSuccess)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.cancelBookingFailed}$e')),
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(loc.noBtn)),
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
        customerPhone: customerPhone,
        sessionToken: sessionToken,
      );
      _refreshAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.acceptPostponeSuccess)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.acceptPostponeFailed}$e')),
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(loc.noBtn)),
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
        customerPhone: customerPhone,
        sessionToken: sessionToken,
      );
      _refreshAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.rejectPostponeSuccess)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.rejectPostponeFailed}$e')),
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
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(loc.cancelButton)),
            ElevatedButton(
              onPressed: selectedRating == 0
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      try {
                        await SupabaseService.instance.customerSubmitRating(
                          bookingId: bookingId,
                          customerPhone: customerPhone,
                          sessionToken: sessionToken,
                          rating: selectedRating,
                        );
                        _refreshAll();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(AppLocalizations.of(context)!.rateSuccess)),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${AppLocalizations.of(context)!.rateFailed}$e')),
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
}

class _InboxToggleOldButton extends StatelessWidget {
  final int count;
  final bool expanded;
  final VoidCallback onTap;

  const _InboxToggleOldButton({
    required this.count,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return InkWell(
      onTap: onTap,
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
