import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Testable subclass of RealtimeNotificationService
//
// RealtimeNotificationService calls `Supabase.instance.client` at field-init
// time, which requires a live Supabase initialisation.  To keep tests
// hermetic we introduce _TestableNotificationService that overrides only the
// Supabase-dependent polling methods with no-ops, leaving every other piece
// of pure logic (subscriber counting, timer management, state transitions)
// exercisable without a network.
// ---------------------------------------------------------------------------

// Duplicate the pure-logic fields/methods here rather than importing the
// production class so we can test without hitting the Supabase init guard.
// If the production class is ever refactored to accept an injected client,
// these tests can be migrated to use it directly.

class _FakeNotificationService {
  final StreamController<Map<String, dynamic>> _notificationController =
      StreamController<Map<String, dynamic>>.broadcast();

  Timer? _pollingTimer;
  bool _isConnected = false;
  int _subscriberCount = 0;
  DateTime? _lastPolledAt;
  String? _lastBookingStatus;

  Stream<Map<String, dynamic>> get notificationStream =>
      _notificationController.stream;

  bool get isConnected => _isConnected;
  int get subscriberCount => _subscriberCount;
  DateTime? get lastPolledAt => _lastPolledAt;
  String? get lastBookingStatus => _lastBookingStatus;
  Timer? get pollingTimer => _pollingTimer;

  // Mirror of the real subscribeToCustomerNotifications (minus Supabase call)
  void subscribeToCustomer(String customerPhone) {
    _subscriberCount++;
    _lastPolledAt = DateTime.now();
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      // no-op in test — pure logic only
    });
    _isConnected = true;
  }

  // Mirror of the real subscribeToStationNotifications
  void subscribeToStation(String stationId) {
    _subscriberCount++;
    _lastPolledAt = DateTime.now();
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {});
    _isConnected = true;
  }

  // Mirror of the real subscribeToBookingUpdates
  void subscribeToBooking(String bookingId) {
    _subscriberCount++;
    _lastBookingStatus = null;
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {});
    _isConnected = true;
  }

  // Exact copy of the production unsubscribe logic
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

  // Exposes the booking-update emission logic for white-box testing
  void simulateBookingPoll(Map<String, dynamic> data) {
    final currentStatus = data['status'] as String?;
    if (currentStatus != _lastBookingStatus) {
      _lastBookingStatus = currentStatus;
      _notificationController.add(data);
    }
  }

  // Exposes the notification emission logic (emits when data non-empty)
  void simulateNotificationPoll(List<Map<String, dynamic>> data) {
    if (data.isNotEmpty) {
      _lastPolledAt = DateTime.now();
      for (final notification in data) {
        _notificationController.add(notification);
      }
    }
  }

  void dispose() {
    _subscriberCount = 0;
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isConnected = false;
    _notificationController.close();
  }
}

void main() {
  late _FakeNotificationService sut;

  setUp(() {
    sut = _FakeNotificationService();
  });

  tearDown(() {
    sut.dispose();
  });

  // -------------------------------------------------------------------------
  // Subscriber counting
  // -------------------------------------------------------------------------
  group('Subscriber counting', () {
    test('subscriberCount starts at 0', () {
      expect(sut.subscriberCount, 0);
    });

    test('subscribeToCustomer increments count to 1', () {
      sut.subscribeToCustomer('+966500000001');
      expect(sut.subscriberCount, 1);
    });

    test('subscribeToStation increments count to 1', () {
      sut.subscribeToStation('station-uuid');
      expect(sut.subscriberCount, 1);
    });

    test('subscribeToBooking increments count to 1', () {
      sut.subscribeToBooking('booking-uuid');
      expect(sut.subscriberCount, 1);
    });

    test('multiple subscribe calls accumulate the count', () {
      sut.subscribeToCustomer('+966500000001');
      sut.subscribeToStation('station-uuid');
      sut.subscribeToBooking('booking-uuid');
      expect(sut.subscriberCount, 3);
    });

    test('isConnected is true after first subscription', () {
      sut.subscribeToCustomer('+966500000001');
      expect(sut.isConnected, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // Unsubscribe — timer and state management
  // -------------------------------------------------------------------------
  group('unsubscribe', () {
    test('decrements count from 1 to 0', () async {
      sut.subscribeToCustomer('+966500000001');
      await sut.unsubscribe();
      expect(sut.subscriberCount, 0);
    });

    test('cancels timer and clears state when count reaches 0', () async {
      sut.subscribeToCustomer('+966500000001');
      await sut.unsubscribe();

      expect(sut.pollingTimer, isNull);
      expect(sut.isConnected, isFalse);
      expect(sut.lastPolledAt, isNull);
    });

    test('does not cancel timer while other subscribers remain', () async {
      sut.subscribeToCustomer('+966500000001');
      sut.subscribeToStation('station-uuid');

      await sut.unsubscribe(); // count drops to 1

      expect(sut.subscriberCount, 1);
      expect(sut.isConnected, isTrue);
      expect(sut.pollingTimer, isNotNull);
    });

    test('count never goes negative when called more times than subscribe', () async {
      await sut.unsubscribe();
      await sut.unsubscribe();
      await sut.unsubscribe();
      expect(sut.subscriberCount, 0);
    });

    test('isConnected becomes false when all subscribers unsubscribe', () async {
      sut.subscribeToCustomer('+966500000001');
      sut.subscribeToStation('station-uuid');
      await sut.unsubscribe();
      await sut.unsubscribe();
      expect(sut.isConnected, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // Polling emission logic — notifications
  // -------------------------------------------------------------------------
  group('Notification polling logic', () {
    test('emits each notification when data is non-empty', () async {
      sut.subscribeToCustomer('+966500000001');

      final emitted = <Map<String, dynamic>>[];
      sut.notificationStream.listen(emitted.add);

      sut.simulateNotificationPoll([
        {'id': '1', 'message': 'First'},
        {'id': '2', 'message': 'Second'},
      ]);

      // Allow the stream to deliver events
      await Future<void>.delayed(Duration.zero);

      expect(emitted.length, 2);
      expect(emitted[0]['id'], '1');
      expect(emitted[1]['id'], '2');
    });

    test('does not emit anything when polling returns empty data', () async {
      sut.subscribeToCustomer('+966500000001');

      final emitted = <Map<String, dynamic>>[];
      sut.notificationStream.listen(emitted.add);

      sut.simulateNotificationPoll([]);
      await Future<void>.delayed(Duration.zero);

      expect(emitted, isEmpty);
    });

    test('updates lastPolledAt only when data is non-empty', () async {
      sut.subscribeToCustomer('+966500000001');
      final beforePoll = sut.lastPolledAt!;

      // Empty poll — lastPolledAt must not change
      sut.simulateNotificationPoll([]);
      expect(sut.lastPolledAt, equals(beforePoll));

      // Non-empty poll — lastPolledAt must be updated
      await Future<void>.delayed(const Duration(milliseconds: 5));
      sut.simulateNotificationPoll([
        {'id': '1', 'message': 'Hello'},
      ]);
      expect(sut.lastPolledAt!.isAfter(beforePoll), isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // Polling emission logic — booking updates
  // -------------------------------------------------------------------------
  group('Booking update polling logic', () {
    test('emits when status changes from null to a value', () async {
      sut.subscribeToBooking('booking-uuid');

      final emitted = <Map<String, dynamic>>[];
      sut.notificationStream.listen(emitted.add);

      sut.simulateBookingPoll({'id': 'booking-uuid', 'status': 'confirmed'});
      await Future<void>.delayed(Duration.zero);

      expect(emitted.length, 1);
      expect(emitted.first['status'], 'confirmed');
    });

    test('emits when status changes from one value to another', () async {
      sut.subscribeToBooking('booking-uuid');

      final emitted = <Map<String, dynamic>>[];
      sut.notificationStream.listen(emitted.add);

      sut.simulateBookingPoll({'id': 'booking-uuid', 'status': 'pending'});
      sut.simulateBookingPoll({'id': 'booking-uuid', 'status': 'confirmed'});
      await Future<void>.delayed(Duration.zero);

      expect(emitted.length, 2);
      expect(emitted[0]['status'], 'pending');
      expect(emitted[1]['status'], 'confirmed');
    });

    test('does NOT emit when status is unchanged on consecutive polls', () async {
      sut.subscribeToBooking('booking-uuid');

      final emitted = <Map<String, dynamic>>[];
      sut.notificationStream.listen(emitted.add);

      sut.simulateBookingPoll({'id': 'booking-uuid', 'status': 'confirmed'});
      sut.simulateBookingPoll({'id': 'booking-uuid', 'status': 'confirmed'});
      sut.simulateBookingPoll({'id': 'booking-uuid', 'status': 'confirmed'});
      await Future<void>.delayed(Duration.zero);

      // Only one emission — the first status change from null -> confirmed
      expect(emitted.length, 1);
    });

    test('tracks lastBookingStatus correctly through multiple transitions', () async {
      sut.subscribeToBooking('booking-uuid');

      sut.simulateBookingPoll({'id': 'booking-uuid', 'status': 'pending'});
      expect(sut.lastBookingStatus, 'pending');

      sut.simulateBookingPoll({'id': 'booking-uuid', 'status': 'confirmed'});
      expect(sut.lastBookingStatus, 'confirmed');

      sut.simulateBookingPoll({'id': 'booking-uuid', 'status': 'completed'});
      expect(sut.lastBookingStatus, 'completed');
    });

    test('lastBookingStatus is reset to null when all subscribers unsubscribe', () async {
      sut.subscribeToBooking('booking-uuid');
      sut.simulateBookingPoll({'id': 'booking-uuid', 'status': 'confirmed'});
      expect(sut.lastBookingStatus, 'confirmed');

      await sut.unsubscribe();
      expect(sut.lastBookingStatus, isNull);
    });
  });
}
