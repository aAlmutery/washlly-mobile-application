import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import '../../models/booking.dart';
import '../../models/owner_session.dart';
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
  late Future<List<Map<String, dynamic>>> _employeesFuture;

  @override
  void initState() {
    super.initState();
    _employeesFuture = _loadEmployees();
  }

  Future<List<Map<String, dynamic>>> _loadEmployees() async {
    try {
      final data = await SupabaseService.instance.client
          .from('employees')
          .select('*')
          .eq('station_id', widget.session.stationId);
      return List<Map<String, dynamic>>.from(data);
    } catch (_) {
      return [];
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.session.stationName,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${loc.ownerStationIdPrefix}${widget.session.stationId}',
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
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
              loc.ownerEmployees,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _employeesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final employees = snapshot.data ?? [];
                if (employees.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(loc.ownerNoEmployees, style: const TextStyle(color: Colors.grey)),
                    ),
                  );
                }
                return Column(
                  children: employees
                      .map(
                        (e) => Card(
                          child: ListTile(
                            leading: const CircleAvatar(child: Icon(Icons.person)),
                            title: Text(e['name'] ?? ''),
                            subtitle: Text(e['phone'] ?? e['email'] ?? ''),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                e['role'] ?? loc.ownerDefaultRole,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
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

  void _refresh() => setState(() => _bookingsFuture = _loadBookings());

  Future<void> _complete(String bookingId) async {
    try {
      await SupabaseService.instance.ownerUpdateBookingStatus(
        bookingId: bookingId,
        stationId: widget.session.stationId,
        newStatus: 'completed',
      );
      _refresh();
    } catch (e) {
      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${loc.ownerCompleteFailed}$e')),
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
    } catch (e) {
      if (mounted) {
        final loc2 = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${loc2.ownerCancelFailed}$e')),
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

  Future<void> _showPostponeDialog(String bookingId, {required bool isPending}) async {
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
      if (isPending) {
        await SupabaseService.instance.ownerManageBooking(
          bookingId: bookingId,
          action: 'postpone',
          sessionToken: widget.session.sessionToken,
          proposedDate: dateStr,
          proposedTime: timeStr,
        );
      } else {
        await SupabaseService.instance.ownerPostponeConfirmedBooking(
          bookingId: bookingId,
          stationId: widget.session.stationId,
          proposedDate: dateStr,
          proposedTime: timeStr,
        );
      }
      _refresh();
      if (mounted) {
        final loc2 = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc2.ownerPostponeSuccess)),
        );
      }
    } catch (e) {
      if (mounted) {
        final loc2 = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${loc2.ownerPostponeFailed}$e')),
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

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
      case 'pending_owner_approval':
      case 'pending_customer_approval':
        return Colors.orange;
      case 'confirmed':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildList(List<Map<String, dynamic>> bookings, _TabType tabType) {
    if (bookings.isEmpty) {
      final loc = AppLocalizations.of(context)!;
      return Center(
        child: Text(loc.ownerNoBookings, style: const TextStyle(color: Colors.grey)),
      );
    }
    final loc = AppLocalizations.of(context)!;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        final b = Booking.fromJson(bookings[index]);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${loc.ownerBookingNumberPrefix}${b.bookingNumber}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusColor(b.status),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        b.status.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text('${loc.ownerCustomerPrefix}${b.customerName}'),
                Text('${loc.ownerPhonePrefix}${b.customerPhone}'),
                const SizedBox(height: 6),
                Text('${loc.ownerServicePrefix}${b.serviceName}'),
                Text('${loc.ownerDatePrefix}${b.bookingDate} - ${b.bookingTime}'),
                const SizedBox(height: 6),
                Text('${loc.ownerPricePrefix}${b.price ?? 0}${loc.ownerCurrencySuffix}'),
                if (tabType == _TabType.pending) ...[
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
                          onPressed: () => _showPostponeDialog(b.id, isPending: true),
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
                          onPressed: () => _showPostponeDialog(b.id, isPending: false),
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
