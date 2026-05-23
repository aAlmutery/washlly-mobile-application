import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class RealtimeNotificationService {
  RealtimeNotificationService._();
  static final RealtimeNotificationService instance = RealtimeNotificationService._();

  final SupabaseClient _client = Supabase.instance.client;
  final StreamController<Map<String, dynamic>> _notificationController =
      StreamController<Map<String, dynamic>>.broadcast();

  Timer? _pollingTimer;
  bool _isConnected = false;

  Stream<Map<String, dynamic>> get notificationStream => _notificationController.stream;

  Future<void> subscribeToCustomerNotifications(String customerPhone) async {
    // Start polling for new notifications every 5 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await _pollForNotifications(customerPhone);
    });
    _isConnected = true;
  }

  Future<void> subscribeToStationNotifications(String stationId) async {
    // Start polling for station notifications
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await _pollForStationNotifications(stationId);
    });
    _isConnected = true;
  }

  Future<void> subscribeToBookingUpdates(String bookingId) async {
    // Start polling for booking updates
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await _pollForBookingUpdates(bookingId);
    });
    _isConnected = true;
  }

  Future<void> _pollForNotifications(String customerPhone) async {
    try {
      final data = await _client
          .from('customer_notifications')
          .select('*')
          .eq('customer_phone', customerPhone)
          .order('created_at', ascending: false)
          .limit(10);

      if (data.isNotEmpty) {
        for (final notification in data) {
          _notificationController.add(notification);
        }
      }
    } catch (e) {
      print('Error polling notifications: $e');
    }
  }

  Future<void> _pollForStationNotifications(String stationId) async {
    try {
      final data = await _client
          .from('station_notifications')
          .select('*')
          .eq('station_id', stationId)
          .order('created_at', ascending: false)
          .limit(10);

      if (data.isNotEmpty) {
        for (final notification in data) {
          _notificationController.add(notification);
        }
      }
    } catch (e) {
      print('Error polling station notifications: $e');
    }
  }

  Future<void> _pollForBookingUpdates(String bookingId) async {
    try {
      final data = await _client
          .from('bookings')
          .select('*')
          .eq('id', bookingId)
          .single();

      _notificationController.add(data);
    } catch (e) {
      print('Error polling booking updates: $e');
    }
  }

  Future<void> unsubscribe() async {
    _pollingTimer?.cancel();
    _isConnected = false;
  }

  void dispose() {
    unsubscribe();
    _notificationController.close();
  }

  bool get isConnected => _isConnected;
}
