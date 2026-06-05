import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../models/customer_session.dart';
import '../services/session_service.dart';
import '../services/supabase_service.dart';
import 'realtime_notifications_widget.dart';
// bottom_nav_scaffold.dart — theming is handled via AppTheme.bottomNavigationBarTheme

class BottomNavScaffold extends StatefulWidget {
  final Widget body;
  final String title;
  final int currentIndex;
  final String? notificationPhone;
  final List<Widget>? appBarActions;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  static const List<String> _routes = [
    '/home',
    '/stations',
    '/map',
    '/profile',
  ];

  const BottomNavScaffold({
    super.key,
    required this.body,
    required this.title,
    required this.currentIndex,
    this.notificationPhone,
    this.appBarActions,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
  });

  @override
  State<BottomNavScaffold> createState() => _BottomNavScaffoldState();
}

class _BottomNavScaffoldState extends State<BottomNavScaffold> {
  int _activeBookingCount = 0;
  Timer? _pollTimer;
  CustomerSession? _session;

  static const _activeStatuses = {
    'pending',
    'pending_owner_approval',
    'confirmed',
    'pending_customer_approval',
  };

  @override
  void initState() {
    super.initState();
    _loadAndPoll();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAndPoll() async {
    final session = await SessionService.instance.loadCustomerSession();
    if (!mounted || session == null) return;
    _session = session;
    await _poll();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _poll(),
    );
  }

  Future<void> _poll() async {
    if (_session == null) return;
    try {
      final raw = await SupabaseService.instance.fetchCustomerBookings(
        _session!.customerPhone,
        sessionToken: _session!.sessionToken,
      );
      if (!mounted) return;
      final count =
          raw.where((b) => _activeStatuses.contains(b['status'])).length;
      if (count != _activeBookingCount) {
        setState(() => _activeBookingCount = count);
      }
    } catch (_) {}
  }

  void _onTap(BuildContext context, int index) {
    if (index == widget.currentIndex) return;
    Navigator.pushReplacementNamed(context, BottomNavScaffold._routes[index]);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    Widget inboxIcon = const Icon(Icons.inbox);
    if (widget.notificationPhone != null &&
        widget.notificationPhone!.isNotEmpty) {
      inboxIcon = RealtimeNotificationBadge(
        customerPhone: widget.notificationPhone!,
        onNotificationReceived: () {},
      );
    }

    Widget mapIcon = inboxIcon;
    if (_activeBookingCount > 0) {
      mapIcon = Stack(
        clipBehavior: Clip.none,
        children: [
          inboxIcon,
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                '$_activeBookingCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    }

    final items = <BottomNavigationBarItem>[
      BottomNavigationBarItem(
          icon: const Icon(Icons.home), label: loc.bottomHome),
      BottomNavigationBarItem(
          icon: const Icon(Icons.list), label: loc.bottomStations),
      BottomNavigationBarItem(icon: mapIcon, label: loc.bottomMap),
      BottomNavigationBarItem(
          icon: const Icon(Icons.person), label: loc.bottomProfile),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: widget.appBarActions,
      ),
      body: widget.body,
      floatingActionButton: widget.floatingActionButton,
      floatingActionButtonLocation: widget.floatingActionButtonLocation,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: widget.currentIndex,
        onTap: (index) => _onTap(context, index),
        items: items,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
