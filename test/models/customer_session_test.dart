import 'package:flutter_test/flutter_test.dart';
import 'package:washlly_mobile_app/models/customer_session.dart';

CustomerSession _makeSession({required DateTime expiresAt}) => CustomerSession(
      customerPhone: '+966500000001',
      customerName: 'Test User',
      sessionToken: 'tok_abc123',
      expiresAt: expiresAt,
    );

void main() {
  group('CustomerSession.isValid', () {
    test('returns true when expiresAt is in the future', () {
      final session = _makeSession(
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      expect(session.isValid, isTrue);
    });

    test('returns false when expiresAt is in the past', () {
      final session = _makeSession(
        expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
      );
      expect(session.isValid, isFalse);
    });

    test('returns false when expiresAt is exactly now (boundary — already expired)', () {
      // DateTime.now() will be slightly after the assigned expiresAt
      // because isBefore is strict, so equal timestamps also fail.
      final past = DateTime.now().subtract(const Duration(milliseconds: 1));
      final session = _makeSession(expiresAt: past);
      expect(session.isValid, isFalse);
    });
  });

  group('CustomerSession fields', () {
    test('fromJson parses all fields correctly', () {
      final json = {
        'customer_phone': '+966500000002',
        'customer_name': 'Ali',
        'session_token': 'tok_xyz',
        'expires_at': '2099-12-31T23:59:59.000Z',
      };

      final session = CustomerSession.fromJson(json);

      expect(session.customerPhone, '+966500000002');
      expect(session.customerName, 'Ali');
      expect(session.sessionToken, 'tok_xyz');
      expect(session.expiresAt.year, 2099);
      expect(session.isValid, isTrue);
    });
  });
}
