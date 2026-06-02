import 'package:flutter_test/flutter_test.dart';
import 'package:washlly_mobile_app/widgets/booking_card.dart';

// ---------------------------------------------------------------------------
// Tests for canCancelBooking — extracted top-level function from
// CustomerBookingHistoryScreen so it can be unit-tested without a widget tree.
// ---------------------------------------------------------------------------

void main() {
  group('canCancelBooking', () {
    group('statuses that should be cancellable', () {
      test('returns true for pending', () {
        expect(canCancelBooking('pending'), isTrue);
      });

      test('returns true for pending_owner_approval', () {
        expect(canCancelBooking('pending_owner_approval'), isTrue);
      });

      test('returns true for confirmed', () {
        expect(canCancelBooking('confirmed'), isTrue);
      });
    });

    group('statuses that should NOT be cancellable', () {
      test('returns false for completed', () {
        expect(canCancelBooking('completed'), isFalse);
      });

      test('returns false for cancelled', () {
        expect(canCancelBooking('cancelled'), isFalse);
      });

      test('returns false for pending_customer_approval '
          '(handled by dedicated Reject New Time button)', () {
        expect(canCancelBooking('pending_customer_approval'), isFalse);
      });

      test('returns false for unknown status', () {
        expect(canCancelBooking('in_progress'), isFalse);
      });

      test('returns false for empty string', () {
        expect(canCancelBooking(''), isFalse);
      });
    });
  });
}
