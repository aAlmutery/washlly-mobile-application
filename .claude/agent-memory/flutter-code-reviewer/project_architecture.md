---
name: project-architecture
description: Washlly mobile app architecture — Flutter + Supabase, two-role split, state management approach, folder layout
metadata:
  type: project
---

Flutter car-wash booking app for Iraq (Arabic locale default). Dual-role product: customer booking flow and station-owner management flow.

**Why:** Understanding the two-role structure is essential when reviewing any screen — the customer and owner share Supabase but use separate session models and service calls.

**How to apply:** Always check which role a screen targets. Security issues in owner screens (session token leakage, RLS bypass) are higher severity than equivalent issues in customer screens.

## Tech Stack
- Flutter SDK ^3.6.0, Dart null-safe
- Supabase Flutter ^2.4.0 (REST + Edge Functions)
- flutter_map ^8.3.0 (OpenStreetMap tiles)
- geolocator ^13.0.0
- shared_preferences ^2.5.3 (session persistence)
- intl ^0.19.0 + flutter_localizations (ar + en ARB files)

## Folder Layout
```
lib/
  config.dart              # supabaseUrl + supabaseAnonKey (hardcoded — security issue)
  main.dart                # app entry, route table
  models/                  # Booking, Station, ServiceModel, CustomerSession, OwnerSession, ...
  services/
    supabase_service.dart  # singleton SupabaseService — all Supabase calls
    session_service.dart   # customer session via SharedPreferences
    owner_session_service.dart
    realtime_notification_service.dart  # polling-based (not true realtime)
  screens/
    welcome_screen.dart
    home_screen.dart
    station_list_screen.dart   # paginated list with debounced search
    station_map_screen.dart    # flutter_map with markers
    customer/
      booking_screen.dart      # map booking + quick booking (GPS)
      customer_booking_history_screen.dart
      profile_screen.dart      # customer login + booking history entry point
      inbox_screen.dart        # incomplete/abandoned screen
    owner/
      owner_shell.dart         # IndexedStack shell with 4 tabs (home/station/bookings/profile)
      owner_login_screen.dart  # login + register tabs
      owner_dashboard_screen.dart  # legacy/duplicate — superseded by owner_shell.dart
      alerts_and_conflicts_screen.dart
      employee_management_screen.dart
      suspension_and_debt_screen.dart
  widgets/
    bottom_nav_scaffold.dart   # shared 5-tab nav for customer flow
    station_card.dart
    realtime_notifications_widget.dart  # polling badge widget
```

## State Management
No state management library. Pure StatefulWidget + setState throughout. FutureBuilder pattern for async data loading. Sessions stored in SharedPreferences, loaded in initState.

## Edge Function Fallback Pattern
`fetchCustomerBookings` is the canonical example: try edge function first, catch FunctionException, fall back to direct REST query. Same dual-path is used in owner booking management (ownerManageBooking → ownerUpdateBookingStatus fallback).

## Booking Status State Machine
pending → pending_owner_approval → confirmed → completed
pending_customer_approval (owner-proposed postpone, awaiting customer accept/reject)
Any state → cancelled
