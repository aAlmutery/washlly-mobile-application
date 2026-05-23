import 'package:flutter/material.dart';
import '../services/realtime_notification_service.dart';

class RealtimeNotificationBadge extends StatefulWidget {
  final String customerPhone;
  final VoidCallback onNotificationReceived;

  const RealtimeNotificationBadge({
    super.key,
    required this.customerPhone,
    required this.onNotificationReceived,
  });

  @override
  State<RealtimeNotificationBadge> createState() => _RealtimeNotificationBadgeState();
}

class _RealtimeNotificationBadgeState extends State<RealtimeNotificationBadge> {
  int _unreadCount = 0;
  late Stream<Map<String, dynamic>> _notificationStream;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    try {
      await RealtimeNotificationService.instance
          .subscribeToCustomerNotifications(widget.customerPhone);

      _notificationStream = RealtimeNotificationService.instance.notificationStream;

      _notificationStream.listen((notification) {
        if (mounted) {
          setState(() => _unreadCount++);
          widget.onNotificationReceived();
          _showNotificationSnackbar(notification);
        }
      });
    } catch (e) {
      print('Error initializing notifications: $e');
    }
  }

  void _showNotificationSnackbar(Map<String, dynamic> notification) {
    final title = notification['title'] ?? 'New Notification';
    final body = notification['body'] ?? '';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (body.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(body),
            ],
          ],
        ),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.blue[800],
      ),
    );
  }

  @override
  void dispose() {
    RealtimeNotificationService.instance.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Icon(Icons.notifications, size: 28),
        if (_unreadCount > 0)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
              child: Text(
                _unreadCount > 99 ? '99+' : '$_unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

class RealtimeBookingUpdates extends StatefulWidget {
  final String bookingId;
  final ValueChanged<Map<String, dynamic>> onUpdate;

  const RealtimeBookingUpdates({
    super.key,
    required this.bookingId,
    required this.onUpdate,
  });

  @override
  State<RealtimeBookingUpdates> createState() => _RealtimeBookingUpdatesState();
}

class _RealtimeBookingUpdatesState extends State<RealtimeBookingUpdates> {
  @override
  void initState() {
    super.initState();
    _subscribeToBookingUpdates();
  }

  Future<void> _subscribeToBookingUpdates() async {
    try {
      await RealtimeNotificationService.instance
          .subscribeToBookingUpdates(widget.bookingId);

      RealtimeNotificationService.instance.notificationStream.listen((update) {
        if (mounted && update['booking_id'] == widget.bookingId) {
          widget.onUpdate(update);
        }
      });
    } catch (e) {
      print('Error subscribing to booking updates: $e');
    }
  }

  @override
  void dispose() {
    RealtimeNotificationService.instance.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
