import 'dart:async';
import 'package:flutter/material.dart';
import '../services/realtime_notification_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

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
  StreamSubscription<Map<String, dynamic>>? _subscription;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    try {
      await RealtimeNotificationService.instance
          .subscribeToCustomerNotifications(widget.customerPhone);

      _subscription = RealtimeNotificationService.instance.notificationStream.listen(
        (notification) {
          if (mounted) {
            setState(() => _unreadCount++);
            widget.onNotificationReceived();
            _showNotificationSnackbar(notification);
          }
        },
      );
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
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
            Text(
              title as String,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if ((body as String).isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                body,
                style: AppTextStyles.bodySmall.copyWith(color: Colors.white70),
              ),
            ],
          ],
        ),
        duration: const Duration(seconds: 4),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
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
                color: AppColors.error,
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
              constraints: const BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
              child: Text(
                _unreadCount > 99 ? '99+' : '$_unreadCount',
                style: AppTextStyles.labelSmall.copyWith(
                  color: Colors.white,
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
  StreamSubscription<Map<String, dynamic>>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscribeToBookingUpdates();
  }

  Future<void> _subscribeToBookingUpdates() async {
    try {
      await RealtimeNotificationService.instance
          .subscribeToBookingUpdates(widget.bookingId);

      _subscription = RealtimeNotificationService.instance.notificationStream.listen(
        (update) {
          if (mounted) {
            widget.onUpdate(update);
          }
        },
      );
    } catch (e) {
      debugPrint('Error subscribing to booking updates: $e');
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    RealtimeNotificationService.instance.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
