import 'package:flutter/material.dart';
import '../../models/booking.dart';
import '../../services/supabase_service.dart';
import '../../widgets/bottom_nav_scaffold.dart';

class OwnerDashboardScreen extends StatefulWidget {
  static const routeName = '/owner-dashboard';

  final Map<String, dynamic> ownerData;

  const OwnerDashboardScreen({super.key, required this.ownerData});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late String stationId;
  late String ownerPhone;
  late String sessionToken;
  late Future<List<Map<String, dynamic>>> _bookingsFuture;

  @override
  void initState() {
    super.initState();
    stationId = widget.ownerData['station_id'] ?? '';
    ownerPhone = widget.ownerData['owner_phone'] ?? '';
    sessionToken = widget.ownerData['session_token'] ?? '';
    _tabController = TabController(length: 3, vsync: this);
    _bookingsFuture = _loadBookings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _loadBookings() async {
    return await SupabaseService.instance.ownerGetBookings(
      stationId: stationId,
      ownerPhone: ownerPhone,
      sessionToken: sessionToken,
    );
  }

  void _approveBooking(String bookingId) async {
    await SupabaseService.instance.ownerManageBooking(
      bookingId: bookingId,
      action: 'confirm',
      sessionToken: sessionToken,
    );
    setState(() {
      _bookingsFuture = _loadBookings();
    });
  }

  void _rejectBooking(String bookingId, String? reason) async {
    await SupabaseService.instance.ownerManageBooking(
      bookingId: bookingId,
      action: 'reject',
      sessionToken: sessionToken,
    );
    setState(() {
      _bookingsFuture = _loadBookings();
    });
  }

  void _showRejectDialog(String bookingId) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Booking'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(labelText: 'Reason'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              _rejectBooking(bookingId, reasonController.text);
              Navigator.pop(context);
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavScaffold(
      currentIndex: 4,
      title: 'Dashboard - ${widget.ownerData['station_name'] ?? 'Station'}',
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Pending'),
              Tab(text: 'Confirmed'),
              Tab(text: 'Completed'),
            ],
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _bookingsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final allBookings = snapshot.data ?? [];

                // Filter bookings by status
                final pendingBookings = allBookings
                    .where((b) =>
                        b['status'] == 'pending' ||
                        b['status'] == 'pending_owner_approval' ||
                        b['status'] == 'pending_customer_approval')
                    .toList();

                final confirmedBookings = allBookings
                    .where((b) => b['status'] == 'confirmed')
                    .toList();

                final completedBookings = allBookings
                    .where((b) =>
                        b['status'] == 'completed' ||
                        b['status'] == 'cancelled')
                    .toList();

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildBookingsList(context, pendingBookings, true),
                    _buildBookingsList(context, confirmedBookings, false),
                    _buildBookingsList(context, completedBookings, false),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingsList(BuildContext context, List<Map<String, dynamic>> bookings, bool canApproveReject) {
    if (bookings.isEmpty) {
      return Center(child: Text(bookings.isEmpty ? 'No bookings' : 'No pending bookings'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        final booking = bookings[index];
        final bookingObj = Booking.fromJson(booking);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Booking #${bookingObj.bookingNumber}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(bookingObj.status),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        bookingObj.status.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Customer: ${bookingObj.customerName}'),
                Text('Phone: ${bookingObj.customerPhone}'),
                const SizedBox(height: 8),
                Text('Service: ${bookingObj.serviceName}'),
                Text('Date: ${bookingObj.bookingDate} at ${bookingObj.bookingTime}'),
                const SizedBox(height: 8),
                Text('Price: ${bookingObj.price} IQD'),
                if (canApproveReject) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () => _approveBooking(bookingObj.id),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        child: const Text('Approve'),
                      ),
                      ElevatedButton(
                        onPressed: () => _showRejectDialog(bookingObj.id),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text('Reject'),
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

  Color _getStatusColor(String status) {
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
}
