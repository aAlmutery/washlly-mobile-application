import 'package:flutter/foundation.dart';
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
  int _subscriberCount = 0;
  DateTime? _lastPolledAt;
  String? _lastBookingStatus;

  Stream<Map<String, dynamic>> get notificationStream => _notificationController.stream;

  Future<void> subscribeToCustomerNotifications(String customerPhone) async {
    _subscriberCount++;
    _lastPolledAt = DateTime.now();
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await _pollForNotifications(customerPhone);
    });
    _isConnected = true;
  }

  Future<void> subscribeToStationNotifications(String stationId) async {
    _subscriberCount++;
    _lastPolledAt = DateTime.now();
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await _pollForStationNotifications(stationId);
    });
    _isConnected = true;
  }

  Future<void> subscribeToBookingUpdates(String bookingId) async {
    _subscriberCount++;
    _lastBookingStatus = null;
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await _pollForBookingUpdates(bookingId);
    });
    _isConnected = true;
  }

  Future<void> _pollForNotifications(String customerPhone) async {
    try {
      final lastPolled = _lastPolledAt;
      var filterQuery = _client
          .from('customer_notifications')
          .select('*')
          .eq('customer_phone', customerPhone);

      if (lastPolled != null) {
        filterQuery = filterQuery.gt('created_at', lastPolled.toIso8601String());
      }

      final data = await filterQuery
          .order('created_at', ascending: false)
          .limit(10);

      if (data.isNotEmpty) {
        _lastPolledAt = DateTime.now();
        for (final notification in data) {
          _notificationController.add(notification);
        }
      }
    } catch (e) {
      debugPrint('Error polling notifications: $e');
    }
  }

  Future<void> _pollForStationNotifications(String stationId) async {
    try {
      final lastPolled = _lastPolledAt;
      var filterQuery = _client
          .from('station_notifications')
          .select('*')
          .eq('station_id', stationId);

      if (lastPolled != null) {
        filterQuery = filterQuery.gt('created_at', lastPolled.toIso8601String());
      }

      final data = await filterQuery
          .order('created_at', ascending: false)
          .limit(10);

      if (data.isNotEmpty) {
        _lastPolledAt = DateTime.now();
        for (final notification in data) {
          _notificationController.add(notification);
        }
      }
    } catch (e) {
      debugPrint('Error polling station notifications: $e');
    }
  }

  Future<void> _pollForBookingUpdates(String bookingId) async {
    try {
      final data = await _client
          .from('bookings')
          .select('*')
          .eq('id', bookingId)
          .single();

      final currentStatus = data['status'] as String?;
      if (currentStatus != _lastBookingStatus) {
        _lastBookingStatus = currentStatus;
        _notificationController.add(data);
      }
    } catch (e) {
      debugPrint('Error polling booking updates: $e');
    }
  }

  Future<void> unsubscribe() async {
    _subscriberCount = (_subscriberCount - 1).clamp(0, _subscriberCount);
    if (_subscriberCount <= 0) {
      _pollingTimer?.cancel();
      _pollingTimer = null;
      _isConnected = false;
      _lastPolledAt = null;
      _lastBookingStatus = null;
    }
  }

  void dispose() {
    _subscriberCount = 0;
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isConnected = false;
    _notificationController.close();
  }

  bool get isConnected => _isConnected;
}
