---
name: project-test-patterns
description: Established test patterns, mock setup, and known gotchas for this project's test suite
metadata:
  type: project
---

## Mock setup (required in every test file that touches storage)

```dart
TestWidgetsFlutterBinding.ensureInitialized();
FlutterSecureStorage.setMockInitialValues({});
SharedPreferences.setMockInitialValues({});
```

Both calls must be in `setUp()` (not `setUpAll`) so each test starts clean.

**Why:** `SessionService` uses both `SharedPreferences` and `flutter_secure_storage`. Without the mock setup the method channel throws a MissingPluginException in the test environment.

## SessionService is a singleton

`SessionService.instance` is the only way to access it — there is no constructor injection. Tests must rely on the SharedPreferences + FlutterSecureStorage mock values being cleared between runs.

**How to apply:** Always call both `setMockInitialValues({})` in `setUp`, not just once globally.

## CustomerSessionNotifier uses async _init in constructor

The notifier fires `_init()` in the constructor but it is async. After `CustomerSessionNotifier()`, you must `await Future<void>.delayed(Duration.zero)` before asserting on `loaded` or `session`.

**Why:** `_init` calls `SessionService.instance.loadCustomerSession()` which is async. Without the delay the notifier is still initialising.

## RealtimeNotificationService cannot be instantiated in tests

`RealtimeNotificationService` accesses `Supabase.instance.client` at field-init time (not lazily). This means you cannot construct the singleton in tests without a live Supabase init. Instead, test pure logic via `_FakeNotificationService` defined in `test/services/realtime_notification_service_test.dart`.

**How to apply:** If the production class is ever refactored to accept an injected `SupabaseClient`, delete `_FakeNotificationService` and use the real class.

## canCancelBooking — top-level extraction

`_canCancel` was a private method on `_CustomerBookingHistoryScreenState`. It has been extracted to a public top-level function `canCancelBooking(String status)` in `lib/screens/customer/customer_booking_history_screen.dart` so it can be unit-tested without a widget tree.

**Why:** Private state methods cannot be called from test files.

## No mocktail/mockito in this project

Dev dependencies only include `flutter_test` and `flutter_lints`. The mock pattern used is:
- `SharedPreferences.setMockInitialValues({})` for shared_preferences
- `FlutterSecureStorage.setMockInitialValues({})` for flutter_secure_storage
- Hand-written fake classes for anything else

**How to apply:** Do not add mocktail unless the user explicitly requests it.

## Pre-existing broken test

`test/widget_test.dart` ("Loads Washlly home screen") has always failed — it calls `pumpAndSettle` on `WashllyApp` which requires Supabase to be initialised. This is a known pre-existing issue, not introduced by the new test suite.
