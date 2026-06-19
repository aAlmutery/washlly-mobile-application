import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import '../../models/booking.dart';
import '../../models/owner_session.dart';
import '../../models/service_model.dart';
import '../../services/notification_service.dart';
import '../../services/owner_session_service.dart';
import '../../services/sound_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/status_badge.dart';
import '../home_screen.dart';

class OwnerShell extends StatefulWidget {
  static const routeName = '/owner-shell';
  const OwnerShell({super.key});

  @override
  State<OwnerShell> createState() => _OwnerShellState();
}

class _OwnerShellState extends State<OwnerShell> {
  int _currentIndex = 0;
  OwnerSession? _session;
  bool _loading = true;
  late Future<List<Map<String, dynamic>>> _bookingsFuture;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final session = await OwnerSessionService.instance.loadOwnerSession();
    if (mounted) {
      setState(() {
        _session = session;
        _loading = false;
      });
      if (session != null) {
        _bookingsFuture = _fetchBookings(session);
        NotificationService.instance.linkToken(
          phone: session.ownerPhone,
          role: 'owner',
        );
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchBookings(OwnerSession session) =>
      SupabaseService.instance.ownerGetBookings(
        stationId: session.stationId,
        ownerPhone: session.ownerPhone,
        sessionToken: session.sessionToken,
      );

  Future<void> _refreshBookings() async {
    if (_session == null) return;
    final future = _fetchBookings(_session!);
    setState(() { _bookingsFuture = future; });
    await future;
  }

  void _onLogout() async {
    await NotificationService.instance.unlinkToken();
    await OwnerSessionService.instance.clearOwnerSession();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, HomeScreen.routeName, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_session == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, HomeScreen.routeName, (_) => false);
        }
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final session = _session!;
    final bodies = <Widget>[
      _OwnerHomeTab(session: session, bookingsFuture: _bookingsFuture, onRefresh: _refreshBookings),
      _OwnerStationTab(session: session),
      _OwnerBookingsTab(
        session: session,
        bookingsFuture: _bookingsFuture,
        onRefresh: _refreshBookings,
      ),
      _OwnerProfileTab(session: session, onLogout: _onLogout),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: bodies),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.dashboard), label: loc.bottomHome),
          BottomNavigationBarItem(icon: const Icon(Icons.local_car_wash), label: loc.ownerMyStation),
          BottomNavigationBarItem(icon: const Icon(Icons.calendar_today), label: loc.ownerBookingsTitle),
          BottomNavigationBarItem(icon: const Icon(Icons.person), label: loc.ownerProfileTitle),
        ],
      ),
    );
  }
}

// ─────────────────────────── Home Tab ───────────────────────────

class _OwnerHomeTab extends StatelessWidget {
  final OwnerSession session;
  final Future<List<Map<String, dynamic>>> bookingsFuture;
  final Future<void> Function() onRefresh;

  const _OwnerHomeTab({required this.session, required this.bookingsFuture, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(session.stationName)),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: bookingsFuture,
        builder: (context, snapshot) {
          final bookings = snapshot.data ?? [];
          final pending = bookings.where((b) =>
              b['status'] == 'pending' ||
              b['status'] == 'pending_owner_approval' ||
              b['status'] == 'pending_customer_approval').length;
          final confirmed = bookings.where((b) => b['status'] == 'confirmed').length;
          final total = bookings.length;

          return RefreshIndicator(
            onRefresh: onRefresh,
            child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  color: AppColors.primary,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Row(
                      children: [
                        const Icon(Icons.local_car_wash, color: Colors.white, size: 40),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                session.stationName,
                                style: AppTextStyles.titleLarge.copyWith(color: Colors.white),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                session.ownerPhone,
                                style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(loc.ownerOverview, style: AppTextStyles.titleMedium),
                const SizedBox(height: 12),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: loc.ownerPendingLabel,
                          value: pending.toString(),
                          color: AppColors.statusPending,
                          icon: Icons.hourglass_empty,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _StatCard(
                          label: loc.ownerConfirmedLabel,
                          value: confirmed.toString(),
                          color: AppColors.statusConfirmed,
                          icon: Icons.check_circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _StatCard(
                    label: loc.ownerTotalBookings,
                    value: total.toString(),
                    color: AppColors.primary,
                    icon: Icons.calendar_today,
                  ),
                ],
              ],
            ),
          ));
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: AppTextStyles.headlineMedium.copyWith(color: color),
                ),
                Text(label, style: AppTextStyles.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Station Tab ───────────────────────────

class _OwnerStationTab extends StatefulWidget {
  final OwnerSession session;
  const _OwnerStationTab({required this.session});

  @override
  State<_OwnerStationTab> createState() => _OwnerStationTabState();
}

class _OwnerStationTabState extends State<_OwnerStationTab> {
  late Future<List<ServiceModel>> _servicesFuture;

  @override
  void initState() {
    super.initState();
    _servicesFuture = SupabaseService.instance.fetchServices(widget.session.stationId);
  }

  void _refresh() => setState(() {
    _servicesFuture = SupabaseService.instance.fetchServices(widget.session.stationId);
  });

  Future<void> _showAddServiceDialog() async {
    final loc = AppLocalizations.of(context)!;
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final durationController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.ownerAddService),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: loc.ownerServiceName),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              decoration: InputDecoration(labelText: loc.ownerServicePrice),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: durationController,
              decoration: InputDecoration(labelText: loc.ownerServiceDuration),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(loc.cancelButton),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(loc.ownerAddServiceBtn),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final name = nameController.text.trim();
    final price = int.tryParse(priceController.text.trim()) ?? 0;
    final duration = int.tryParse(durationController.text.trim());

    if (name.isEmpty || price <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.ownerServiceInvalidInput)),
        );
      }
      return;
    }

    try {
      await SupabaseService.instance.addService(
        stationId: widget.session.stationId,
        name: name,
        price: price,
        durationMinutes: duration,
      );
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.ownerAddServiceSuccess)),
        );
      }
    } catch (e) {
      if (mounted) {
        final loc2 = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${loc2.ownerAddServiceFailed}$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(loc.ownerMyStation)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                      child: const Icon(Icons.local_car_wash, color: AppColors.primary, size: 32),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        widget.session.stationName,
                        style: AppTextStyles.titleMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(loc.ownerMyServices, style: AppTextStyles.titleMedium),
                ElevatedButton.icon(
                  onPressed: _showAddServiceDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(loc.ownerAddService),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<ServiceModel>>(
              future: _servicesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final services = snapshot.data ?? [];
                if (services.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Text(
                        loc.ownerNoServices,
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  );
                }
                return Column(
                  children: services.map((s) => Card(
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.primarySurface,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        ),
                        child: const Icon(Icons.build_circle_outlined, color: AppColors.primary),
                      ),
                      title: Text(s.name, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                      subtitle: s.durationMinutes != null
                          ? Text('${s.durationMinutes} ${loc.ownerServiceDurationSuffix}', style: AppTextStyles.bodySmall)
                          : null,
                      trailing: Text(
                        '${s.price}${loc.ownerCurrencySuffix}',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  )).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Bookings Tab ───────────────────────────

enum _TabType { pending, confirmed, done }

class _OwnerBookingsTab extends StatefulWidget {
  final OwnerSession session;
  final Future<List<Map<String, dynamic>>> bookingsFuture;
  final Future<void> Function() onRefresh;

  const _OwnerBookingsTab({
    required this.session,
    required this.bookingsFuture,
    required this.onRefresh,
  });

  @override
  State<_OwnerBookingsTab> createState() => _OwnerBookingsTabState();
}

class _OwnerBookingsTabState extends State<_OwnerBookingsTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>>? _cachedBookings;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refresh() => widget.onRefresh();

  Future<void> _cancelConfirmed(String bookingId) async {
    final loc = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.ownerCancelDialogTitle),
        content: Text(loc.ownerCancelConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(loc.noBtn),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(loc.ownerCancelConfirmBtn, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await SupabaseService.instance.ownerUpdateBookingStatus(
        bookingId: bookingId,
        stationId: widget.session.stationId,
        newStatus: 'cancelled',
      );
      _refresh();
      if (mounted) {
        final loc2 = AppLocalizations.of(context)!;
        SoundService.instance.playPopupSound();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc2.ownerCancelSuccess),
            backgroundColor: Colors.grey.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final loc2 = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc2.ownerCancelFailed}$e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _approve(String bookingId) async {
    final loc = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.ownerApproveDialogTitle),
        content: Text(loc.ownerApproveConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(loc.noBtn),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: Text(loc.ownerApproveConfirmBtn, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await SupabaseService.instance.ownerManageBooking(
        bookingId: bookingId,
        action: 'confirm',
        sessionToken: widget.session.sessionToken,
      );
      _refresh();
      if (mounted) {
        final loc2 = AppLocalizations.of(context)!;
        SoundService.instance.playPopupSound();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc2.ownerApproveSuccess),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final loc2 = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${loc2.ownerApproveFailed}$e')),
        );
      }
    }
  }

  Future<void> _reject(String bookingId) async {
    try {
      await SupabaseService.instance.ownerManageBooking(
        bookingId: bookingId,
        action: 'reject',
        sessionToken: widget.session.sessionToken,
      );
      _refresh();
      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        SoundService.instance.playPopupSound();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.ownerRejectSuccess)),
        );
      }
    } catch (e) {
      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${loc.ownerRejectFailed}$e')),
        );
      }
    }
  }

  Future<void> _showPostponeDialog(Booking booking) async {
    final loc = AppLocalizations.of(context)!;
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = const TimeOfDay(hour: 10, minute: 0);

    final date = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      helpText: loc.ownerPostponeDateHelp,
    );
    if (date == null || !mounted) return;
    selectedDate = date;

    final time = await showTimePicker(
      context: context,
      initialTime: selectedTime,
      helpText: loc.ownerPostponeTimeHelp,
    );
    if (time == null || !mounted) return;
    selectedTime = time;

    final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
    final timeStr =
        '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';

    try {
      if (booking.status == 'confirmed') {
        // Edge function only accepts pending/pending_owner_approval — use direct REST for confirmed.
        await SupabaseService.instance.ownerPostponeConfirmedBooking(
          bookingId: booking.id,
          stationId: widget.session.stationId,
          proposedDate: dateStr,
          proposedTime: timeStr,
        );
      } else {
        // pending / pending_owner_approval — edge function sends customer notification automatically.
        await SupabaseService.instance.ownerManageBooking(
          bookingId: booking.id,
          action: 'postpone',
          sessionToken: widget.session.sessionToken,
          proposedDate: dateStr,
          proposedTime: timeStr,
        );
      }
      _refresh();
      if (mounted) {
        final loc2 = AppLocalizations.of(context)!;
        SoundService.instance.playPopupSound();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc2.ownerPostponeSuccess),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final loc2 = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc2.ownerPostponeFailed}$e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showRejectDialog(String bookingId) {
    final loc = AppLocalizations.of(context)!;
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.ownerRejectDialogTitle),
        content: TextField(
          controller: reasonController,
          decoration: InputDecoration(labelText: loc.ownerRejectReasonLabel),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc.cancelButton),
          ),
          ElevatedButton(
            onPressed: () {
              _reject(bookingId);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(loc.ownerRejectBtn, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _ownerStatusLabel(String status, AppLocalizations loc) {
    switch (status) {
      case 'pending':
      case 'pending_owner_approval':
        return loc.ownerStatusNeedsAction;
      case 'pending_customer_approval':
        return loc.ownerStatusPendingCustomer;
      case 'confirmed':
        return loc.ownerStatusConfirmed;
      case 'completed':
        return loc.ownerStatusCompleted;
      case 'cancelled':
        return loc.ownerStatusCancelled;
      default:
        return status;
    }
  }

  Widget _buildList(List<Map<String, dynamic>> bookings, _TabType tabType) {
    final loc = AppLocalizations.of(context)!;
    if (bookings.isEmpty) {
      return RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: 300,
              child: Center(
                child: Text(loc.ownerNoBookings, style: const TextStyle(color: Colors.grey)),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        final b = Booking.fromJson(bookings[index]);
        final isAwaitingCustomer = b.status == 'pending_customer_approval';

        return Card(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${loc.ownerBookingNumberPrefix}${b.bookingNumber}',
                      style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                    ),
                    StatusBadge(
                      status: b.status,
                      label: _ownerStatusLabel(b.status, loc),
                    ),
                  ],
                ),
                const Divider(height: AppSpacing.lg),

                // Customer info
                _OwnerInfoRow(icon: Icons.person, text: '${loc.ownerCustomerPrefix}${b.customerName}'),
                const SizedBox(height: AppSpacing.xs),
                _OwnerInfoRow(icon: Icons.phone, text: '${loc.ownerPhonePrefix}${b.customerPhone}'),
                const SizedBox(height: AppSpacing.xs),
                _OwnerInfoRow(icon: Icons.build_circle_outlined, text: '${loc.ownerServicePrefix}${b.serviceName}'),
                const SizedBox(height: AppSpacing.xs),
                _OwnerInfoRow(icon: Icons.calendar_today, text: '${loc.ownerDatePrefix}${b.bookingDate}  ${b.bookingTime}'),
                if (b.price != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  _OwnerInfoRow(icon: Icons.attach_money, text: '${loc.ownerPricePrefix}${b.price!.toStringAsFixed(0)}${loc.ownerCurrencySuffix}'),
                ],

                // Proposed time (shown when owner postponed and waiting for customer)
                if (b.proposedDate != null && b.proposedTime != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.statusPendingCustomer.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      border: Border.all(color: AppColors.statusPendingCustomer.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.schedule, size: 16, color: AppColors.statusPendingCustomer),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            '${loc.ownerProposedTimeLabel}${b.proposedDate}  ${b.proposedTime}',
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.statusPendingCustomer),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Awaiting customer note
                if (isAwaitingCustomer) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.statusPendingCustomer.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.hourglass_top, size: 16, color: AppColors.statusPendingCustomer),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            loc.ownerAwaitingCustomerNote,
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.statusPendingCustomer),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Actions for pending (only pending / pending_owner_approval — NOT pending_customer_approval)
                if (tabType == _TabType.pending && !isAwaitingCustomer) ...[
                  const SizedBox(height: AppSpacing.sm),
                  ElevatedButton.icon(
                    onPressed: () => _approve(b.id),
                    icon: const Icon(Icons.check, size: 18),
                    label: Text(loc.ownerApproveBtn),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 44),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showRejectDialog(b.id),
                          icon: const Icon(Icons.close, size: 18),
                          label: Text(loc.ownerRejectBtn),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showPostponeDialog(b),
                          icon: const Icon(Icons.schedule, size: 18),
                          label: Text(loc.ownerPostponeBtn),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.warning,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                // Actions for confirmed
                if (tabType == _TabType.confirmed) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showPostponeDialog(b),
                          icon: const Icon(Icons.schedule, size: 18),
                          label: Text(loc.ownerPostponeBtn),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.warning,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _cancelConfirmed(b.id),
                          icon: const Icon(Icons.cancel_outlined, size: 18),
                          label: Text(loc.cancelButton),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    ));
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.ownerBookingsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: loc.refreshTooltip,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: loc.ownerTabPending),
            Tab(text: loc.ownerTabConfirmed),
            Tab(text: loc.ownerTabDone),
          ],
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: widget.bookingsFuture,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            _cachedBookings = snapshot.data;
          }
          if (snapshot.connectionState == ConnectionState.waiting &&
              _cachedBookings == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError && _cachedBookings == null) {
            return Center(child: Text('${loc.errorPrefix}${snapshot.error}'));
          }
          final all = _cachedBookings ?? [];
          final pending = all
              .where((b) =>
                  b['status'] == 'pending' ||
                  b['status'] == 'pending_owner_approval' ||
                  b['status'] == 'pending_customer_approval')
              .toList();
          final confirmed = all.where((b) => b['status'] == 'confirmed').toList();
          final done = all
              .where((b) => b['status'] == 'completed' || b['status'] == 'cancelled')
              .toList();

          return Column(
            children: [
              if (snapshot.connectionState == ConnectionState.waiting)
                const LinearProgressIndicator(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildList(pending, _TabType.pending),
                    _buildList(confirmed, _TabType.confirmed),
                    _buildList(done, _TabType.done),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────── Profile Tab ───────────────────────────

class _OwnerProfileTab extends StatelessWidget {
  final OwnerSession session;
  final VoidCallback onLogout;

  const _OwnerProfileTab({required this.session, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(loc.ownerProfileTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(Icons.business, size: 32, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.stationName,
                            style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            session.ownerPhone,
                            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primarySurface,
                              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                            ),
                            child: Text(
                              loc.ownerStationOwnerRole,
                              style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(loc.profileLogout),
                      content: Text(loc.ownerLogoutConfirm),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(loc.cancelButton),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            onLogout();
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                          child: Text(
                            loc.profileLogout,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.logout),
                label: Text(loc.profileLogout),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OwnerInfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _OwnerInfoRow({required this.icon, required this.text});

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
