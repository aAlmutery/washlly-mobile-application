import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import '../../models/booking.dart';
import '../../models/owner_session.dart';
import '../../models/service_model.dart';
import '../../services/owner_session_service.dart';
import '../../services/supabase_service.dart';
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

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final session = await OwnerSessionService.instance.loadOwnerSession();
    if (mounted) setState(() { _session = session; _loading = false; });
  }

  void _onLogout() async {
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
      _OwnerHomeTab(session: session),
      _OwnerStationTab(session: session),
      _OwnerBookingsTab(session: session),
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

class _OwnerHomeTab extends StatefulWidget {
  final OwnerSession session;
  const _OwnerHomeTab({required this.session});

  @override
  State<_OwnerHomeTab> createState() => _OwnerHomeTabState();
}

class _OwnerHomeTabState extends State<_OwnerHomeTab> {
  late Future<List<Map<String, dynamic>>> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = SupabaseService.instance.ownerGetBookings(
      stationId: widget.session.stationId,
      ownerPhone: widget.session.ownerPhone,
      sessionToken: widget.session.sessionToken,
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(widget.session.stationName)),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _statsFuture,
        builder: (context, snapshot) {
          final bookings = snapshot.data ?? [];
          final pending = bookings.where((b) =>
              b['status'] == 'pending' ||
              b['status'] == 'pending_owner_approval' ||
              b['status'] == 'pending_customer_approval').length;
          final confirmed = bookings.where((b) => b['status'] == 'confirmed').length;
          final total = bookings.length;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  color: Colors.blue.shade800,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        const Icon(Icons.local_car_wash, color: Colors.white, size: 40),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.session.stationName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.session.ownerPhone,
                                style: const TextStyle(color: Colors.white70, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  loc.ownerOverview,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
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
                          color: Colors.orange,
                          icon: Icons.hourglass_empty,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: loc.ownerConfirmedLabel,
                          value: confirmed.toString(),
                          color: Colors.green,
                          icon: Icons.check_circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _StatCard(
                    label: loc.ownerTotalBookings,
                    value: total.toString(),
                    color: Colors.blue,
                    icon: Icons.calendar_today,
                  ),
                ],
              ],
            ),
          );
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
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
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
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.local_car_wash, color: Colors.blue.shade800, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        widget.session.stationName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  loc.ownerMyServices,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
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
                      padding: const EdgeInsets.all(24),
                      child: Text(loc.ownerNoServices, style: const TextStyle(color: Colors.grey)),
                    ),
                  );
                }
                return Column(
                  children: services.map((s) => Card(
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.build_circle_outlined, color: Colors.blue.shade700),
                      ),
                      title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: s.durationMinutes != null
                          ? Text('${s.durationMinutes} ${loc.ownerServiceDurationSuffix}')
                          : null,
                      trailing: Text(
                        '${s.price}${loc.ownerCurrencySuffix}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 15),
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
  const _OwnerBookingsTab({required this.session});

  @override
  State<_OwnerBookingsTab> createState() => _OwnerBookingsTabState();
}

class _OwnerBookingsTabState extends State<_OwnerBookingsTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<Map<String, dynamic>>> _bookingsFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _bookingsFuture = _loadBookings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _loadBookings() =>
      SupabaseService.instance.ownerGetBookings(
        stationId: widget.session.stationId,
        ownerPhone: widget.session.ownerPhone,
        sessionToken: widget.session.sessionToken,
      );

  void _refresh() => setState(() { _bookingsFuture = _loadBookings(); });

  Future<void> _complete(String bookingId) async {
    try {
      // Prefer the edge function — it uses service_role and bypasses RLS.
      // Fall back to direct REST if the edge function doesn't support 'complete'.
      try {
        await SupabaseService.instance.ownerManageBooking(
          bookingId: bookingId,
          action: 'complete',
          sessionToken: widget.session.sessionToken,
        );
      } on Exception {
        await SupabaseService.instance.ownerUpdateBookingStatus(
          bookingId: bookingId,
          stationId: widget.session.stationId,
          newStatus: 'completed',
        );
      }
      _refresh();
      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.ownerCompleteSuccess),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc.ownerCompleteFailed}$e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

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
    try {
      await SupabaseService.instance.ownerManageBooking(
        bookingId: bookingId,
        action: 'confirm',
        sessionToken: widget.session.sessionToken,
      );
      _refresh();
    } catch (e) {
      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${loc.ownerApproveFailed}$e')),
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

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
      case 'pending_owner_approval':
        return Colors.orange;
      case 'pending_customer_approval':
        return Colors.deepPurple;
      case 'confirmed':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Widget _buildList(List<Map<String, dynamic>> bookings, _TabType tabType) {
    final loc = AppLocalizations.of(context)!;
    if (bookings.isEmpty) {
      return Center(
        child: Text(loc.ownerNoBookings, style: const TextStyle(color: Colors.grey)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        final b = Booking.fromJson(bookings[index]);
        final statusColor = _statusColor(b.status);
        final isAwaitingCustomer = b.status == 'pending_customer_approval';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${loc.ownerBookingNumberPrefix}${b.bookingNumber}',
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
                        _ownerStatusLabel(b.status, loc),
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

                // Customer info
                _OwnerInfoRow(icon: Icons.person, text: '${loc.ownerCustomerPrefix}${b.customerName}'),
                const SizedBox(height: 4),
                _OwnerInfoRow(icon: Icons.phone, text: '${loc.ownerPhonePrefix}${b.customerPhone}'),
                const SizedBox(height: 4),
                _OwnerInfoRow(icon: Icons.build_circle_outlined, text: '${loc.ownerServicePrefix}${b.serviceName}'),
                const SizedBox(height: 4),
                _OwnerInfoRow(icon: Icons.calendar_today, text: '${loc.ownerDatePrefix}${b.bookingDate}  ${b.bookingTime}'),
                if (b.price != null) ...[
                  const SizedBox(height: 4),
                  _OwnerInfoRow(icon: Icons.attach_money, text: '${loc.ownerPricePrefix}${b.price!.toStringAsFixed(0)}${loc.ownerCurrencySuffix}'),
                ],

                // Proposed time (shown when owner postponed and waiting for customer)
                if (b.proposedDate != null && b.proposedTime != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.schedule, size: 16, color: Colors.deepPurple),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${loc.ownerProposedTimeLabel}${b.proposedDate}  ${b.proposedTime}',
                            style: const TextStyle(color: Colors.deepPurple, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Awaiting customer note
                if (isAwaitingCustomer) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.hourglass_top, size: 16, color: Colors.deepPurple),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            loc.ownerAwaitingCustomerNote,
                            style: const TextStyle(color: Colors.deepPurple, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Actions for pending (only pending / pending_owner_approval — NOT pending_customer_approval)
                if (tabType == _TabType.pending && !isAwaitingCustomer) ...[
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: () => _approve(b.id),
                    icon: const Icon(Icons.check, size: 18),
                    label: Text(loc.ownerApproveBtn),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 44),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showRejectDialog(b.id),
                          icon: const Icon(Icons.close, size: 18),
                          label: Text(loc.ownerRejectBtn),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showPostponeDialog(b),
                          icon: const Icon(Icons.schedule, size: 18),
                          label: Text(loc.ownerPostponeBtn),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                // Actions for confirmed
                if (tabType == _TabType.confirmed) ...[
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: () => _complete(b.id),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: Text(loc.ownerDoneBtn),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 44),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showPostponeDialog(b),
                          icon: const Icon(Icons.schedule, size: 18),
                          label: Text(loc.ownerPostponeBtn),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _cancelConfirmed(b.id),
                          icon: const Icon(Icons.cancel_outlined, size: 18),
                          label: Text(loc.cancelButton),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
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
    );
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
          tabs: [
            Tab(text: loc.ownerTabPending),
            Tab(text: loc.ownerTabConfirmed),
            Tab(text: loc.ownerTabDone),
          ],
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _bookingsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${loc.errorPrefix}${snapshot.error}'));
          }
          final all = snapshot.data ?? [];
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

          return TabBarView(
            controller: _tabController,
            children: [
              _buildList(pending, _TabType.pending),
              _buildList(confirmed, _TabType.confirmed),
              _buildList(done, _TabType.done),
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
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade800,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(Icons.business, size: 32, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.stationName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            session.ownerPhone,
                            style: const TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              loc.ownerStationOwnerRole,
                              style: const TextStyle(fontSize: 12, color: Colors.blue),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
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
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
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
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
      ],
    );
  }
}
