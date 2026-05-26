import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washlly_mobile_app/models/booking.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Minimal valid JSON for a booking. Override individual keys in each test.
Map<String, dynamic> _baseJson({
  String id = 'b1',
  int bookingNumber = 1,
  String stationId = 'st1',
  String status = 'pending',
  String bookingDate = '2025-01-01',
  String bookingTime = '09:00',
  String createdAt = '2025-01-01T00:00:00.000Z',
}) =>
    {
      'id': id,
      'booking_number': bookingNumber,
      'station_id': stationId,
      'status': status,
      'booking_date': bookingDate,
      'booking_time': bookingTime,
      'created_at': createdAt,
    };

void main() {
  group('Booking.fromJson', () {
    group('REST join format — nested services/stations maps', () {
      test('reads service name and price from nested services map', () {
        final json = _baseJson()
          ..addAll({
            'services': {'name': 'Full Wash', 'price': 45},
            'stations': {'name': 'Station Alpha'},
          });

        final booking = Booking.fromJson(json);

        expect(booking.serviceName, 'Full Wash');
        expect(booking.price, 45.0);
        expect(booking.stationName, 'Station Alpha');
      });

      test('price is parsed as double when services.price is a double', () {
        final json = _baseJson()
          ..addAll({
            'services': {'name': 'Quick Rinse', 'price': 29.5},
          });

        final booking = Booking.fromJson(json);

        expect(booking.price, 29.5);
      });

      test('price is null when services map has no price key', () {
        final json = _baseJson()
          ..addAll({
            'services': {'name': 'Polish'},
          });

        final booking = Booking.fromJson(json);

        expect(booking.price, isNull);
      });
    });

    group('Edge-function flat format — service_name / service_price fields', () {
      test('reads service_name and service_price when no services map present', () {
        final json = _baseJson()
          ..addAll({
            'service_name': 'Interior Clean',
            'service_price': 60,
            'station_name': 'Station Beta',
          });

        final booking = Booking.fromJson(json);

        expect(booking.serviceName, 'Interior Clean');
        expect(booking.price, 60.0);
        expect(booking.stationName, 'Station Beta');
      });

      test('falls back to top-level price field when service_price absent', () {
        final json = _baseJson()
          ..addAll({
            'service_name': 'Wax',
            'price': 80,
          });

        final booking = Booking.fromJson(json);

        expect(booking.price, 80.0);
      });

      test('price is null when all three price fields are absent', () {
        final json = _baseJson()
          ..addAll({'service_name': 'Wax'});

        final booking = Booking.fromJson(json);

        expect(booking.price, isNull);
      });
    });

    group('parseTime — booking_time and proposed_time', () {
      test('strips seconds from HH:MM:SS to produce HH:MM', () {
        final json = _baseJson(bookingTime: '09:30:00');
        final booking = Booking.fromJson(json);
        expect(booking.bookingTime, '09:30');
      });

      test('passes through HH:MM unchanged', () {
        final json = _baseJson(bookingTime: '14:15');
        final booking = Booking.fromJson(json);
        expect(booking.bookingTime, '14:15');
      });

      test('strips seconds from proposed_time', () {
        final json = _baseJson()
          ..addAll({
            'proposed_date': '2025-02-01',
            'proposed_time': '10:45:30',
          });
        final booking = Booking.fromJson(json);
        expect(booking.proposedTime, '10:45');
      });

      test('passes through proposed_time HH:MM unchanged', () {
        final json = _baseJson()
          ..addAll({
            'proposed_date': '2025-02-01',
            'proposed_time': '08:00',
          });
        final booking = Booking.fromJson(json);
        expect(booking.proposedTime, '08:00');
      });

      test('proposed_time is null when proposed_time field is absent', () {
        final json = _baseJson();
        final booking = Booking.fromJson(json);
        expect(booking.proposedTime, isNull);
      });

      test('booking_time defaults to 00:00 when field is null', () {
        final json = _baseJson()..['booking_time'] = null;
        final booking = Booking.fromJson(json);
        expect(booking.bookingTime, '00:00');
      });
    });

    group('Nested map precedence over flat fields', () {
      test('services.name wins over service_name when both present', () {
        final json = _baseJson()
          ..addAll({
            'services': {'name': 'From Services Map'},
            'service_name': 'From Flat Field',
          });
        final booking = Booking.fromJson(json);
        expect(booking.serviceName, 'From Services Map');
      });

      test('stations.name wins over station_name when both present', () {
        final json = _baseJson()
          ..addAll({
            'stations': {'name': 'Station From Map'},
            'station_name': 'Station From Flat',
          });
        final booking = Booking.fromJson(json);
        expect(booking.stationName, 'Station From Map');
      });
    });

    group('Scalar fields', () {
      test('bookingNumber defaults to 0 when absent', () {
        final json = _baseJson()..remove('booking_number');
        final booking = Booking.fromJson(json);
        expect(booking.bookingNumber, 0);
      });

      test('status defaults to pending when absent', () {
        final json = _baseJson()..remove('status');
        final booking = Booking.fromJson(json);
        expect(booking.status, 'pending');
      });

      test('customerRating is null when absent', () {
        final json = _baseJson();
        final booking = Booking.fromJson(json);
        expect(booking.customerRating, isNull);
      });

      test('customerRating is parsed when present', () {
        final json = _baseJson()..addAll({'customer_rating': 4});
        final booking = Booking.fromJson(json);
        expect(booking.customerRating, 4);
      });

      test('ratedAt is null when absent', () {
        final json = _baseJson();
        final booking = Booking.fromJson(json);
        expect(booking.ratedAt, isNull);
      });

      test('ratedAt is parsed when present', () {
        final json = _baseJson()
          ..addAll({'rated_at': '2025-03-10T12:00:00.000Z'});
        final booking = Booking.fromJson(json);
        expect(booking.ratedAt, isA<DateTime>());
      });

      test('createdAt falls back to DateTime.now() on invalid string', () {
        final before = DateTime.now().subtract(const Duration(seconds: 1));
        final json = _baseJson()..['created_at'] = 'not-a-date';
        final booking = Booking.fromJson(json);
        expect(booking.createdAt.isAfter(before), isTrue);
      });
    });
  });

  // ---------------------------------------------------------------------------
  // statusColor getter
  // ---------------------------------------------------------------------------
  group('Booking.statusColor', () {
    Booking bookingWithStatus(String status) =>
        Booking.fromJson(_baseJson(status: status));

    test('pending returns orange', () {
      expect(bookingWithStatus('pending').statusColor, Colors.orange);
    });

    test('pending_owner_approval returns orange', () {
      expect(
          bookingWithStatus('pending_owner_approval').statusColor, Colors.orange);
    });

    test('pending_customer_approval returns deepPurple', () {
      expect(bookingWithStatus('pending_customer_approval').statusColor,
          Colors.deepPurple);
    });

    test('confirmed returns green', () {
      expect(bookingWithStatus('confirmed').statusColor, Colors.green);
    });

    test('completed returns blue', () {
      expect(bookingWithStatus('completed').statusColor, Colors.blue);
    });

    test('cancelled returns grey', () {
      expect(bookingWithStatus('cancelled').statusColor, Colors.grey);
    });

    test('unknown status returns grey', () {
      expect(bookingWithStatus('unknown_status').statusColor, Colors.grey);
    });
  });

  // ---------------------------------------------------------------------------
  // statusLabel getter
  // ---------------------------------------------------------------------------
  group('Booking.statusLabel', () {
    Booking bookingWithStatus(String status) =>
        Booking.fromJson(_baseJson(status: status));

    test('pending returns Pending', () {
      expect(bookingWithStatus('pending').statusLabel, 'Pending');
    });

    test('pending_owner_approval returns Pending', () {
      expect(bookingWithStatus('pending_owner_approval').statusLabel, 'Pending');
    });

    test('pending_customer_approval returns Pending your response', () {
      expect(bookingWithStatus('pending_customer_approval').statusLabel,
          'Pending your response');
    });

    test('confirmed returns Confirmed', () {
      expect(bookingWithStatus('confirmed').statusLabel, 'Confirmed');
    });

    test('completed returns Completed', () {
      expect(bookingWithStatus('completed').statusLabel, 'Completed');
    });

    test('cancelled returns Cancelled', () {
      expect(bookingWithStatus('cancelled').statusLabel, 'Cancelled');
    });

    test('unknown status returns the raw status string', () {
      expect(bookingWithStatus('in_progress').statusLabel, 'in_progress');
    });
  });
}
