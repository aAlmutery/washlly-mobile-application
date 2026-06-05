import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'realtime_notifications_widget.dart';
// bottom_nav_scaffold.dart — theming is handled via AppTheme.bottomNavigationBarTheme

class BottomNavScaffold extends StatelessWidget {
  final Widget body;
  final String title;
  final int currentIndex;
  final String? notificationPhone;
  final List<Widget>? appBarActions;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final int activeBookingCount;

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
    this.activeBookingCount = 0,
  });

  void _onTap(BuildContext context, int index) {
    if (index == currentIndex) return;
    Navigator.pushReplacementNamed(context, _routes[index]);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    Widget inboxIcon = const Icon(Icons.inbox);
    if (notificationPhone != null && notificationPhone!.isNotEmpty) {
      inboxIcon = RealtimeNotificationBadge(
        customerPhone: notificationPhone!,
        onNotificationReceived: () {},
      );
    }

    Widget mapIcon = inboxIcon;
    if (activeBookingCount > 0) {
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
                '$activeBookingCount',
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
      BottomNavigationBarItem(icon: const Icon(Icons.home), label: loc.bottomHome),
      BottomNavigationBarItem(icon: const Icon(Icons.list), label: loc.bottomStations),
      BottomNavigationBarItem(icon: mapIcon, label: loc.bottomMap),
      BottomNavigationBarItem(icon: const Icon(Icons.person), label: loc.bottomProfile),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: appBarActions,
      ),
      body: body,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => _onTap(context, index),
        items: items,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
