import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:washlly_mobile_app/models/customer_session.dart';
import 'package:washlly_mobile_app/services/session_service.dart';
import 'package:washlly_mobile_app/state/customer_session_notifier.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

CustomerSession _validSession() => CustomerSession(
      customerPhone: '+966500000010',
      customerName: 'Notifier User',
      sessionToken: 'tok_notifier',
      expiresAt: DateTime.now().add(const Duration(hours: 2)),
    );

void _setupMocks() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});
}

void main() {
  setUp(() {
    _setupMocks();
    SharedPreferences.setMockInitialValues({});
  });

  group('CustomerSessionNotifier initial state', () {
    test('loaded is false before _init completes', () {
      final notifier = CustomerSessionNotifier();
      // Synchronously check — _init is async and not yet awaited
      expect(notifier.loaded, isFalse);
      expect(notifier.session, isNull);
    });

    test('loaded becomes true after _init completes with no stored session', () async {
      final notifier = CustomerSessionNotifier();
      // Wait for the async _init to settle
      await Future<void>.delayed(Duration.zero);
      expect(notifier.loaded, isTrue);
      expect(notifier.session, isNull);
    });

    test('session is null when nothing is stored at startup', () async {
      final notifier = CustomerSessionNotifier();
      await Future<void>.delayed(Duration.zero);
      expect(notifier.session, isNull);
    });

    test('session is populated from storage when a valid session was persisted', () async {
      final session = _validSession();
      await SessionService.instance.saveCustomerSession(session);

      final notifier = CustomerSessionNotifier();
      await Future<void>.delayed(Duration.zero);

      expect(notifier.session, isNotNull);
      expect(notifier.session!.customerPhone, session.customerPhone);
    });

    test('notifyListeners is called once after _init completes', () async {
      int notifyCount = 0;
      final notifier = CustomerSessionNotifier()
        ..addListener(() => notifyCount++);

      await Future<void>.delayed(Duration.zero);

      expect(notifyCount, 1);
      expect(notifier.loaded, isTrue);
    });
  });

  group('CustomerSessionNotifier.save', () {
    test('sets session to the saved value', () async {
      final notifier = CustomerSessionNotifier();
      await Future<void>.delayed(Duration.zero);

      final session = _validSession();
      await notifier.save(session);

      expect(notifier.session, isNotNull);
      expect(notifier.session!.customerPhone, session.customerPhone);
      expect(notifier.session!.sessionToken, session.sessionToken);
    });

    test('notifyListeners is called on save', () async {
      final notifier = CustomerSessionNotifier();
      await Future<void>.delayed(Duration.zero);

      int notifyCount = 0;
      notifier.addListener(() => notifyCount++);

      await notifier.save(_validSession());

      expect(notifyCount, 1);
    });

    test('persists session so a freshly loaded notifier can read it', () async {
      final session = _validSession();
      final notifier1 = CustomerSessionNotifier();
      await Future<void>.delayed(Duration.zero);
      await notifier1.save(session);

      // Simulate app restart — new notifier reads from storage
      final notifier2 = CustomerSessionNotifier();
      await Future<void>.delayed(Duration.zero);

      expect(notifier2.session?.customerPhone, session.customerPhone);
    });
  });

  group('CustomerSessionNotifier.logout', () {
    test('sets session to null', () async {
      final session = _validSession();
      final notifier = CustomerSessionNotifier();
      await Future<void>.delayed(Duration.zero);
      await notifier.save(session);

      await notifier.logout();

      expect(notifier.session, isNull);
    });

    test('notifyListeners is called on logout', () async {
      final session = _validSession();
      final notifier = CustomerSessionNotifier();
      await Future<void>.delayed(Duration.zero);
      await notifier.save(session);

      int notifyCount = 0;
      notifier.addListener(() => notifyCount++);

      await notifier.logout();

      expect(notifyCount, 1);
    });

    test('clears persisted storage so a fresh notifier finds nothing', () async {
      final session = _validSession();
      final notifier = CustomerSessionNotifier();
      await Future<void>.delayed(Duration.zero);
      await notifier.save(session);
      await notifier.logout();

      final notifier2 = CustomerSessionNotifier();
      await Future<void>.delayed(Duration.zero);

      expect(notifier2.session, isNull);
    });
  });
}
