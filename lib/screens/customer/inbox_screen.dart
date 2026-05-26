import 'package:flutter/material.dart';
import '../../models/booking.dart';
import '../../models/customer_notification.dart';
import '../../services/session_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/bottom_nav_scaffold.dart';
import '../../widgets/status_badge.dart';
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
    return _loadInbox();
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
    if (mounted) {
      setState(() {
        _inboxFuture = _initAndLoadInbox();
      });
    }
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
                            padding: const EdgeInsets.all(AppSpacing.md),
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
                                  color: notif.isRead ? null : AppColors.primarySurface,
                                  child: ListTile(
                                    title: Text(
                                      notif.title,
                                      style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Text(notif.body, style: AppTextStyles.bodySmall),
                                    trailing: !notif.isRead
                                        ? const Icon(Icons.circle, color: AppColors.primary, size: 12)
                                        : null,
                                    contentPadding: const EdgeInsets.all(AppSpacing.md),
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
    final statusLabel = booking.statusLabel;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Booking #${booking.bookingNumber}',
                  style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                ),
                StatusBadge(status: booking.status, label: statusLabel),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(booking.stationName, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
            Text(booking.serviceName, style: AppTextStyles.bodyMedium),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: AppSpacing.sm),
                Text('${booking.bookingDate} at ${booking.bookingTime}', style: AppTextStyles.bodyMedium),
              ],
            ),
            if (booking.price != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text('Price: ${booking.price} IQD', style: AppTextStyles.bodyMedium),
            ],
            if (booking.customerRating != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  const Icon(Icons.star, size: 16, color: Colors.amber),
                  const SizedBox(width: AppSpacing.sm),
                  Text('Rating: ${booking.customerRating}/5', style: AppTextStyles.bodyMedium),
                ],
              ),
            ],
            if (booking.status == 'confirmed' && booking.customerRating == null) ...[
              const SizedBox(height: AppSpacing.sm),
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
            onPressed: () async {
              Navigator.pop(context);
              try {
                await SupabaseService.instance.customerSubmitRating(
                  bookingId: booking.id,
                  customerPhone: customerPhone,
                  sessionToken: sessionToken,
                  rating: rating,
                );
              } catch (_) {}
              if (mounted) setState(() => _inboxFuture = _initAndLoadInbox());
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}
