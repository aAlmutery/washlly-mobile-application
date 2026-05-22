import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class BottomNavScaffold extends StatelessWidget {
  final Widget body;
  final String title;
  final int currentIndex;

  static const List<String> _routes = [
    '/home',
    '/stations',
    '/map',
    '/booking',
    '/owner',
  ];

  const BottomNavScaffold({
    super.key,
    required this.body,
    required this.title,
    required this.currentIndex,
  });

  void _onTap(BuildContext context, int index) {
    if (index == currentIndex) return;
    Navigator.pushReplacementNamed(context, _routes[index]);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final items = <BottomNavigationBarItem>[
      BottomNavigationBarItem(icon: const Icon(Icons.home), label: loc.bottomHome),
      BottomNavigationBarItem(icon: const Icon(Icons.list), label: loc.bottomStations),
      BottomNavigationBarItem(icon: const Icon(Icons.map), label: loc.bottomMap),
      BottomNavigationBarItem(icon: const Icon(Icons.calendar_today), label: loc.bottomBooking),
      BottomNavigationBarItem(icon: const Icon(Icons.person), label: loc.bottomOwner),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: body,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => _onTap(context, index),
        items: items,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
