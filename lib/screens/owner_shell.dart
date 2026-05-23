import 'package:flutter/material.dart';
import '../models/booking.dart';
import '../models/owner_session.dart';
import '../services/owner_session_service.dart';
import '../services/supabase_service.dart';
import 'home_screen.dart';

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
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'الرئيسية'),
          BottomNavigationBarItem(icon: Icon(Icons.local_car_wash), label: 'محطتي'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'الحجوزات'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'ملفي'),
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
                const Text(
                  'نظرة عامة',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'قيد الانتظار',
                          value: pending.toString(),
                          color: Colors.orange,
                          icon: Icons.hourglass_empty,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: 'مؤكدة',
                          value: confirmed.toString(),
                          color: Colors.green,
                          icon: Icons.check_circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _StatCard(
                    label: 'إجمالي الحجوزات',
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
    return Scaffold(
      appBar: AppBar(title: const Text('محطتي')),
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
                            'رقم المحطة: ${widget.session.stationId}',
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
            const Text(
              'الموظفون',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('لا يوجد موظفون', style: TextStyle(color: Colors.grey)),
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
                                e['role'] ?? 'موظف',
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

  void _approve(String bookingId) async {
    await SupabaseService.instance.ownerApproveBooking(
      bookingId: bookingId,
      stationId: widget.session.stationId,
      ownerPhone: widget.session.ownerPhone,
      sessionToken: widget.session.sessionToken,
    );
    setState(() { _bookingsFuture = _loadBookings(); });
  }

  void _reject(String bookingId, String? reason) async {
    await SupabaseService.instance.ownerRejectBooking(
      bookingId: bookingId,
      stationId: widget.session.stationId,
      ownerPhone: widget.session.ownerPhone,
      sessionToken: widget.session.sessionToken,
      reason: reason,
    );
    setState(() { _bookingsFuture = _loadBookings(); });
  }

  void _showRejectDialog(String bookingId) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('رفض الحجز'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(labelText: 'سبب الرفض'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              _reject(bookingId, reasonController.text);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('رفض', style: TextStyle(color: Colors.white)),
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

  Widget _buildList(List<Map<String, dynamic>> bookings, bool canAct) {
    if (bookings.isEmpty) {
      return const Center(
        child: Text('لا توجد حجوزات', style: TextStyle(color: Colors.grey)),
      );
    }
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
                      'حجز #${b.bookingNumber}',
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
                Text('العميل: ${b.customerName}'),
                Text('الهاتف: ${b.customerPhone}'),
                const SizedBox(height: 6),
                Text('الخدمة: ${b.serviceName}'),
                Text('التاريخ: ${b.bookingDate} - ${b.bookingTime}'),
                const SizedBox(height: 6),
                Text('السعر: ${b.price ?? 0} دينار'),
                if (canAct) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _approve(b.id),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          child: const Text('قبول', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _showRejectDialog(b.id),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          child: const Text('رفض', style: TextStyle(color: Colors.white)),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('الحجوزات'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'قيد الانتظار'),
            Tab(text: 'مؤكدة'),
            Tab(text: 'مكتملة'),
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
            return Center(child: Text('خطأ: ${snapshot.error}'));
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
              _buildList(pending, true),
              _buildList(confirmed, false),
              _buildList(done, false),
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
    return Scaffold(
      appBar: AppBar(title: const Text('ملفي الشخصي')),
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
                            child: const Text(
                              'مالك المحطة',
                              style: TextStyle(fontSize: 12, color: Colors.blue),
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
                      title: const Text('تسجيل الخروج'),
                      content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('إلغاء'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            onLogout();
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          child: const Text(
                            'تسجيل الخروج',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.logout),
                label: const Text('تسجيل الخروج'),
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
