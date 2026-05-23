import 'package:flutter/material.dart';
import '../models/booking.dart';
import '../models/customer_notification.dart';
import '../services/supabase_service.dart';
import '../widgets/bottom_nav_scaffold.dart';
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
  late String customerPhone;
  late String sessionToken;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // TODO: Get customer phone and session token from local storage or provider
    customerPhone = '';
    sessionToken = '';
    _inboxFuture = _loadInbox();
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

  void _markNotificationRead(String notificationId) async {
    await SupabaseService.instance.customerMarkNotificationRead(
      customerPhone: customerPhone,
      sessionToken: sessionToken,
      notificationId: notificationId,
    );
    setState(() {
      _inboxFuture = _loadInbox();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavScaffold(
      currentIndex: 2,
      title: 'Inbox',
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
          final notifications = (inboxData['notifications'] as List?)
                  ?.map((n) => CustomerNotification.fromJson(n as Map<String, dynamic>))
                  .toList() ??
              [];
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
                    notifications.isEmpty
                        ? const Center(child: Text('No notifications'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: notifications.length,
                            itemBuilder: (context, index) {
                              final notif = notifications[index];
                              return GestureDetector(
                                onTap: () {
                                  if (!notif.isRead) {
                                    _markNotificationRead(notif.id);
                                  }
                                },
                                child: Card(
                                  color: notif.isRead ? Colors.white : Colors.blue[50],
                                  child: ListTile(
                                    title: Text(notif.title,
                                        style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text(notif.body),
                                    trailing: !notif.isRead ? const Icon(Icons.circle, color: Colors.blue, size: 12) : null,
                                    contentPadding: const EdgeInsets.all(16),
                                  ),
                                ),
                              );
                            },
                          ),
                    // Bookings Tab
                    bookings.isEmpty
                        ? const Center(child: Text('No bookings'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: bookings.length,
                            itemBuilder: (context, index) {
                              final booking = bookings[index];
                              return _buildBookingCard(context, booking, null);
                            },
                          ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBookingCard(BuildContext context, Booking booking, AppLocalizations? loc) {
    Color statusColor;
    String statusLabel;

    switch (booking.status) {
      case 'confirmed':
        statusColor = Colors.green;
        statusLabel = 'Confirmed';
        break;
      case 'pending':
      case 'pending_owner_approval':
      case 'pending_customer_approval':
        statusColor = Colors.orange;
        statusLabel = 'Pending';
        break;
      case 'completed':
        statusColor = Colors.blue;
        statusLabel = 'Completed';
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusLabel = 'Cancelled';
        break;
      default:
        statusColor = Colors.grey;
        statusLabel = booking.status;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Booking #${booking.bookingNumber}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(20)),
                  child: Text(statusLabel, style: const TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('${booking.stationName}', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('${booking.serviceName}'),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16),
                const SizedBox(width: 8),
                Text('${booking.bookingDate} at ${booking.bookingTime}'),
              ],
            ),
            if (booking.price != null) ...[
              const SizedBox(height: 8),
              Text('Price: ${booking.price} IQD'),
            ],
            if (booking.customerRating != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.star, size: 16, color: Colors.amber),
                  const SizedBox(width: 8),
                  Text('Rating: ${booking.customerRating}/5'),
                ],
              ),
            ],
            if (booking.status == 'confirmed' && booking.customerRating == null) ...[
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => _showRatingDialog(context, booking),
                child: const Text('Rate'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showRatingDialog(BuildContext context, Booking booking) {
    int rating = 5;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rate this booking'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return GestureDetector(
                    onTap: () => setState(() => rating = index + 1),
                    child: Icon(
                      index < rating ? Icons.star : Icons.star_outline,
                      color: Colors.amber,
                      size: 32,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              Text('$rating / 5'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              SupabaseService.instance.customerSubmitRating(
                bookingId: booking.id,
                customerPhone: customerPhone,
                sessionToken: sessionToken,
                rating: rating,
              );
              Navigator.pop(context);
              setState(() => _inboxFuture = _loadInbox());
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}
