import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:washlly_mobile_app/models/customer_session.dart';
import 'package:washlly_mobile_app/services/session_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

CustomerSession _futureSession({Duration offset = const Duration(hours: 1)}) =>
    CustomerSession(
      customerPhone: '+966500000001',
      customerName: 'Test User',
      sessionToken: 'tok_abc123',
      expiresAt: DateTime.now().add(offset),
    );

CustomerSession _expiredSession() => CustomerSession(
      customerPhone: '+966500000001',
      customerName: 'Test User',
      sessionToken: 'tok_expired',
      expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
    );

void _setupMocks() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // flutter_secure_storage requires a method channel mock in tests.
  FlutterSecureStorage.setMockInitialValues({});
}

void main() {
  setUp(() {
    _setupMocks();
    SharedPreferences.setMockInitialValues({});
  });

  group('SessionService.saveCustomerSession', () {
    test('persists phone, name and expiry via SharedPreferences', () async {
      final session = _futureSession();
      await SessionService.instance.saveCustomerSession(session);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('customer_phone'), session.customerPhone);
      expect(prefs.getString('customer_name'), session.customerName);
      expect(prefs.getString('session_expiry'), session.expiresAt.toIso8601String());
    });

    test('persists session token via FlutterSecureStorage', () async {
      final session = _futureSession();
      await SessionService.instance.saveCustomerSession(session);

      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'session_token');
      expect(token, session.sessionToken);
    });
  });

  group('SessionService.loadCustomerSession', () {
    test('returns null when nothing is stored', () async {
      final result = await SessionService.instance.loadCustomerSession();
      expect(result, isNull);
    });

    test('returns null when phone is missing', () async {
      final session = _futureSession();
      await SessionService.instance.saveCustomerSession(session);

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('customer_phone');

      final result = await SessionService.instance.loadCustomerSession();
      expect(result, isNull);
    });

    test('returns null when name is missing', () async {
      final session = _futureSession();
      await SessionService.instance.saveCustomerSession(session);

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('customer_name');

      final result = await SessionService.instance.loadCustomerSession();
      expect(result, isNull);
    });

    test('returns null when expiry is missing', () async {
      final session = _futureSession();
      await SessionService.instance.saveCustomerSession(session);

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('session_expiry');

      final result = await SessionService.instance.loadCustomerSession();
      expect(result, isNull);
    });

    test('returns null when token is missing from secure storage', () async {
      final session = _futureSession();
      await SessionService.instance.saveCustomerSession(session);

      const storage = FlutterSecureStorage();
      await storage.delete(key: 'session_token');

      final result = await SessionService.instance.loadCustomerSession();
      expect(result, isNull);
    });

    test('auto-clears and returns null when session is expired', () async {
      final session = _expiredSession();
      await SessionService.instance.saveCustomerSession(session);

      final result = await SessionService.instance.loadCustomerSession();
      expect(result, isNull);

      // Storage must have been cleared
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('customer_phone'), isNull);
      expect(prefs.getString('customer_name'), isNull);
      expect(prefs.getString('session_expiry'), isNull);
      const storage = FlutterSecureStorage();
      expect(await storage.read(key: 'session_token'), isNull);
    });

    test('returns the full session when valid and all fields present', () async {
      final session = _futureSession();
      await SessionService.instance.saveCustomerSession(session);

      final loaded = await SessionService.instance.loadCustomerSession();

      expect(loaded, isNotNull);
      expect(loaded!.customerPhone, session.customerPhone);
      expect(loaded.customerName, session.customerName);
      expect(loaded.sessionToken, session.sessionToken);
      expect(loaded.expiresAt.toIso8601String(),
          session.expiresAt.toIso8601String());
    });
  });

  group('SessionService.clearCustomerSession', () {
    test('removes all SharedPreferences keys', () async {
      final session = _futureSession();
      await SessionService.instance.saveCustomerSession(session);

      await SessionService.instance.clearCustomerSession();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('customer_phone'), isNull);
      expect(prefs.getString('customer_name'), isNull);
      expect(prefs.getString('session_expiry'), isNull);
    });

    test('removes token from secure storage', () async {
      final session = _futureSession();
      await SessionService.instance.saveCustomerSession(session);

      await SessionService.instance.clearCustomerSession();

      const storage = FlutterSecureStorage();
      expect(await storage.read(key: 'session_token'), isNull);
    });

    test('subsequent load returns null after clear', () async {
      final session = _futureSession();
      await SessionService.instance.saveCustomerSession(session);
      await SessionService.instance.clearCustomerSession();

      final result = await SessionService.instance.loadCustomerSession();
      expect(result, isNull);
    });
  });
}
