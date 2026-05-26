---
name: project-architecture
description: State management approach and overall architecture of the Washlly Flutter app
metadata:
  type: project
---

The app uses **pure StatefulWidget + FutureBuilder** as its exclusive state management pattern. No BLoC, Riverpod, Provider, or GetX are installed or used anywhere.

**State management pattern (consistent across all screens):**
- All mutable screen state lives in `State<T>` fields
- All async data fetching is done in `initState()` by storing a `Future` in a `late` field
- That future is consumed in `build()` via `FutureBuilder`
- Manual mutations call `setState(() { _future = _reload(); })` to refresh

**How shared/global state is passed:**
- Session objects (`CustomerSession`, `OwnerSession`) are passed via constructor injection
- `OwnerShell` loads session in its own `initState`, then passes `session` down to child tab widgets as constructor params
- `ProfileScreen` passes `_session!` to `CustomerBookingHistoryScreen` via `MaterialPageRoute`
- No InheritedWidget, no ChangeNotifier, no stream-based global state

**Service layer (singletons):**
- `SupabaseService.instance` — all API calls
- `SessionService.instance` — customer session persistence (SharedPreferences + FlutterSecureStorage)
- `OwnerSessionService.instance` — owner session persistence
- `RealtimeNotificationService.instance` — 5-second polling timer wrapped in a broadcast StreamController

**Async data surface pattern:**
1. `late Future<T> _future` declared on state class
2. `initState` assigns: `_future = SupabaseService.instance.fetch(...)`
3. `build()` wraps in `FutureBuilder<T>` with explicit `waiting`/`error`/`data` branches
4. Refresh: `setState(() { _future = _reload(); })`
5. Direct mutations (approve, cancel, postpone): `await service.call(); _refresh();` in async methods, error surfaced via `ScaffoldMessenger` snackbars

**Routing:**
- Named routes defined in `MaterialApp.routes` for top-level screens
- Push via `Navigator.pushNamed` / `Navigator.pushNamedAndRemoveUntil`
- `BookingScreen` and `CustomerBookingHistoryScreen` passed data via constructor through `MaterialPageRoute`

**Known patterns and conventions:**
- `mounted` guards on every `setState` after `await`
- `WidgetsBinding.instance.addPostFrameCallback` used in `BookingScreen.initState` for session pre-fill and location fetch
- `StatefulBuilder` used inside dialogs and bottom sheets that need local state
- `StationListScreen` has manual pagination state (`_currentPage`, `_hasMoreStations`, `_isLoadingMore`) with a `ScrollController` listener
- Edge function + REST fallback pattern: `try { edgeFunction() } on Exception { directRest() }` — seen in `_OwnerBookingsTabState._complete()`
- One hardcoded Arabic string in `profile_screen.dart` line 206 (not in l10n)

**Session state (updated after refactor):**
- `CustomerSessionNotifier extends ChangeNotifier` lives at `lib/state/customer_session_notifier.dart`
- Instantiated once in `main()`, passed to `WashllyApp` as a constructor param
- `WashllyApp` wraps `MaterialApp` in `ListenableBuilder` so all routes rebuild on session change
- `WelcomeScreen` and `ProfileScreen` receive it as a required constructor param
- `ProfileScreen` calls `notifier.save()` / `notifier.logout()` — never calls `SessionService` directly
- `OwnerShell` still uses its own `OwnerSessionService` (no notifier for owner side)

**Shared bookings fetch in OwnerShell:**
- `_OwnerShellState` owns `_bookingsFuture` and `_refreshBookings()` callback
- Both `_OwnerHomeTab` (now `StatelessWidget`) and `_OwnerBookingsTab` receive the future + refresh callback as constructor params
- One network call serves both tabs

**Stale-while-revalidate pattern:**
- `CustomerBookingHistoryScreen` and `_OwnerBookingsTab` cache their last-good data in `_cachedData`/`_cachedBookings`
- When `connectionState == waiting && _cachedData != null`: show data + `LinearProgressIndicator` at top
- Full spinner only shown on first load (when cache is null)

**Realtime widgets wired up:**
- `RealtimeNotificationBadge` is mounted inside `BottomNavScaffold` when `notificationPhone` param is non-null
- `InboxScreen` passes `customerPhone` to `BottomNavScaffold.notificationPhone`
- `RealtimeBookingUpdates` is mounted in `BookingScreen` after a successful booking creation (uses `_createdBookingId`)

**Booking model enriched:**
- `Booking.statusColor` getter — locale-free, returns `Color` for all status values
- `Booking.statusLabel` getter — English fallback strings, used in `InboxScreen`
- `_statusColor()` helper removed from `CustomerBookingHistoryScreen` and `_OwnerBookingsTab`; replaced with `booking.statusColor`
- `_ownerStatusLabel()` and locale-aware `_statusLabel()` remain in their respective screens (they use different l10n keys)

**Assessment:** Minimalist StatefulWidget+FutureBuilder pattern is now augmented with a single ChangeNotifier for customer session. No new packages added.
