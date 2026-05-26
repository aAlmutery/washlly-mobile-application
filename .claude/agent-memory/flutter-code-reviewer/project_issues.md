---
name: project-issues
description: Known recurring issues and patterns to watch for in this codebase
metadata:
  type: project
---

## Security — Hardcoded Credentials
`lib/config.dart` contains the real Supabase URL and anon key as plain Dart constants. This is committed to source control. The anon key is a JWT visible in the repo. Must be moved to environment injection before any public release.

**Why:** The anon key itself is designed to be public (it only grants anon-role access), but the URL+key pair together should not be in source control — it makes rotating keys harder and exposes the project identifier.

## Dead/Abandoned Screens
Three screens appear to be prototype-era leftovers that are not wired into any active navigation:
- `lib/screens/owner/owner_dashboard_screen.dart` — superseded by `owner_shell.dart`. Still uses hardcoded English strings, unawaited futures in action methods, and a `currentIndex: 4` that doesn't match the 5-item BottomNavScaffold.
- `lib/screens/customer/inbox_screen.dart` — has `customerPhone = ''` hardcoded with a TODO comment; all UI strings are hardcoded English; unawaited `customerSubmitRating` call in rating dialog.
- `lib/screens/owner/alerts_and_conflicts_screen.dart`, `employee_management_screen.dart`, `suspension_and_debt_screen.dart` — unreviewed stubs, not wired to navigation.

## Realtime Notifications — Polling Not True Realtime
`RealtimeNotificationService` uses `Timer.periodic` every 5 seconds and never tracks a "last seen" timestamp. Every poll re-emits the same 10 notifications, causing the badge count to increment by up to 10 on every tick regardless of whether notifications are new.

## Session Token Storage
Both customer and owner session tokens (Supabase JWT access tokens) are stored in `SharedPreferences` as plain strings. On Android this is unencrypted storage. Should use `flutter_secure_storage` for token fields.

## Hardcoded Strings in Legacy Screens
`inbox_screen.dart` and `owner_dashboard_screen.dart` contain hardcoded English UI strings that bypass the l10n system. The rest of the app is properly localized to Arabic via ARB files.

## Missing `mounted` Check After Async Gap in `profile_screen.dart`
In `_openLoginSheet` → `onSuccess` callback: `AppLocalizations.of(context)!` is called after the bottom sheet pop resolves, which is technically across an async gap. In practice it's safe because the sheet pop is synchronous, but worth noting.

## `ownerGetBookings` ignores `ownerPhone` and `sessionToken` parameters
The method signature accepts these parameters but the implementation uses only `stationId` in the query. This means the owner can fetch bookings for any station_id they supply — authorization relies entirely on Supabase RLS, not the application layer. Low risk if RLS is correct, but misleading API contract.
