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

  static const List<String> _routes = [
    '/home',
    '/stations',
    '/map',
    '/booking',
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

    final items = <BottomNavigationBarItem>[
      BottomNavigationBarItem(icon: const Icon(Icons.home), label: loc.bottomHome),
      BottomNavigationBarItem(icon: const Icon(Icons.list), label: loc.bottomStations),
      BottomNavigationBarItem(icon: inboxIcon, label: loc.bottomMap),
      BottomNavigationBarItem(icon: const Icon(Icons.calendar_today), label: loc.bottomBooking),
      BottomNavigationBarItem(icon: const Icon(Icons.person), label: loc.bottomProfile),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: appBarActions,
      ),
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => _onTap(context, index),
        items: items,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
