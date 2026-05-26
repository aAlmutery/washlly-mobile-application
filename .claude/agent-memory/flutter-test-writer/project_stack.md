---
name: project-stack
description: Tech stack, architecture patterns, state management, and testing-relevant structure for the Washlly mobile app
metadata:
  type: project
---

Flutter app (Dart SDK ^3.6.0) + Supabase backend (supabase_flutter ^2.4.0).

**State management:** Plain ChangeNotifier (`CustomerSessionNotifier extends ChangeNotifier`). No Riverpod, BLoC, or Provider package — uses `ListenableBuilder` in `WashllyApp`.

**Two-role screen split:** Customer screens under `lib/screens/customer/`, owner screens under `lib/screens/owner/`. `WelcomeScreen` routes to `HomeScreen` (customer) or `OwnerShell` (owner) based on `OwnerSessionService.loadOwnerSession()`.

**Session persistence:** `SessionService` (customer) and `OwnerSessionService` (owner) both use `shared_preferences` for non-sensitive fields and `flutter_secure_storage` for session tokens.

**Booking mutation routing pattern:**
- Customer bookings fetched via `fetchCustomerBookings` — tries edge function `customer-list-bookings` first, falls back to REST `.from('bookings').select(...)` on `FunctionException`.
- Owner booking mutations: `ownerManageBooking` calls edge function `owner-manage-booking`; confirmed booking postpone and status changes fall back to direct REST (`ownerPostponeConfirmedBooking`, `ownerUpdateBookingStatus`).

**Supabase edge functions used:** `owner-self-register`, `owner-login-lookup`, `owner-login-by-phone`, `customer-login-by-phone`, `customer-list-bookings`, `customer-get-inbox`, `customer-manage-booking`, `customer-submit-rating`, `customer-mark-notification-read`, `owner-manage-booking`, `spin-booking-discount`, `create-map-booking`, `create-quick-booking`, `cancel-map-booking`, `cancel-all-map-bookings`, `whatsapp-send`, `resolve-booking-conflict`.

**Notifications:** Polling-based (`RealtimeNotificationService`) — 5-second `Timer.periodic` per subscription type (customer, station, booking). No Supabase Realtime channels used.

**Localisation:** `flutter_gen/gen_l10n/app_localizations.dart` (Arabic, locale forced to `ar`). All UI strings from `AppLocalizations`.

**Dev dependencies (as of audit):** Only `flutter_test` and `flutter_lints` — NO mocktail, mockito, bloc_test, or any test helpers.

**Why:** Relevant for test strategy — mocking requires adding `mocktail` to dev_dependencies. ChangeNotifier pattern means no BLoC/Riverpod test helpers needed.

**How to apply:** When writing tests, add `mocktail: ^0.3.0` to pubspec.yaml dev_dependencies. Wrap widgets under test with `MaterialApp` + `Localizations` delegates (locale `ar`). For ChangeNotifier tests, instantiate notifier directly and listen for `notifyListeners`.
