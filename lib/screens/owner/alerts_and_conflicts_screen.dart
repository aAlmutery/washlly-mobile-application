import 'package:flutter/material.dart';
import '../../models/booking_alert.dart';
import '../../services/supabase_service.dart';
import '../../widgets/bottom_nav_scaffold.dart';

class AlertsAndConflictsScreen extends StatefulWidget {
  static const routeName = '/alerts';

  const AlertsAndConflictsScreen({super.key});

  @override
  State<AlertsAndConflictsScreen> createState() => _AlertsAndConflictsScreenState();
}

class _AlertsAndConflictsScreenState extends State<AlertsAndConflictsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late String customerPhone;
  late Future<List<Map<String, dynamic>>> _timeoutAlertsFuture;
  late Future<List<Map<String, dynamic>>> _allAlertsFuture;

  @override
  void initState() {
    super.initState();
    customerPhone = ''; // TODO: Get from session
    _tabController = TabController(length: 2, vsync: this);
    _timeoutAlertsFuture = _loadTimeoutAlerts();
    _allAlertsFuture = _loadAllAlerts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _loadTimeoutAlerts() async {
    return await SupabaseService.instance.getTimeoutAlerts(
      customerPhone: customerPhone,
    );
  }

  Future<List<Map<String, dynamic>>> _loadAllAlerts() async {
    // Load all alerts from bookings
    try {
      final client = SupabaseService.instance.client;
      final data = await client
          .from('booking_alerts')
          .select('*')
          .order('created_at', ascending: false)
          .limit(50);
      return (data as List<dynamic>).cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  void _acknowledgeTimeoutAlert(String alertId) async {
    await SupabaseService.instance.acknowledgeTimeoutAlert(alertId: alertId);
    setState(() {
      _timeoutAlertsFuture = _loadTimeoutAlerts();
    });
  }

  void _resolveConflict(String bookingId, String resolution) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resolve Conflict'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Resolution: $resolution'),
            const SizedBox(height: 16),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Reason',
                hintText: 'Enter reason for resolution',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement resolution
              Navigator.pop(context);
            },
            child: const Text('Resolve'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavScaffold(
      currentIndex: 2,
      title: 'Alerts & Conflicts',
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Timeout Alerts'),
              Tab(text: 'Booking Alerts'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Timeout Alerts Tab
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _timeoutAlertsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    final alerts = snapshot.data ?? [];

                    if (alerts.isEmpty) {
                      return const Center(child: Text('No timeout alerts'));
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: alerts.length,
                      itemBuilder: (context, index) {
                        final alert = TimeoutAlert.fromJson(alerts[index]);
                        return Card(
                          color: Colors.red[50],
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Timeout Alert',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${alert.minutesRemaining} mins',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text('Booking ID: ${alert.bookingId}'),
                                Text('Timeout at: ${alert.timeoutTime}'),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () => _acknowledgeTimeoutAlert(alert.id),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                                  child: const Text('Acknowledge'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
                // Booking Alerts Tab
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _allAlertsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    final alerts = snapshot.data ?? [];

                    if (alerts.isEmpty) {
                      return const Center(child: Text('No booking alerts'));
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: alerts.length,
                      itemBuilder: (context, index) {
                        final alert = BookingAlert.fromJson(alerts[index]);
                        return _buildAlertCard(context, alert);
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(BuildContext context, BookingAlert alert) {
    Color bgColor;
    Color borderColor;

    switch (alert.severity) {
      case 'error':
        bgColor = Colors.red[50]!;
        borderColor = Colors.red;
        break;
      case 'warning':
        bgColor = Colors.orange[50]!;
        borderColor = Colors.orange;
        break;
      default:
        bgColor = Colors.blue[50]!;
        borderColor = Colors.blue;
    }

    return Card(
      color: bgColor,
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: borderColor, width: 4)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(alert.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: borderColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      alert.stationType.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(alert.message),
              const SizedBox(height: 8),
              Text('Booking: ${alert.bookingId}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              if (!alert.resolved) ...[
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => _resolveConflict(alert.bookingId, alert.stationType),
                  child: const Text('View & Resolve'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
