import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../widgets/bottom_nav_scaffold.dart';
import 'booking_screen.dart';
import 'owner_login_screen.dart';
import 'station_list_screen.dart';
import 'station_map_screen.dart';

class HomeScreen extends StatelessWidget {
  static const routeName = '/home';

  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return BottomNavScaffold(
      currentIndex: 0,
      title: loc.appTitle,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade800, Colors.blue.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              loc.welcomeTitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              loc.welcomeSubtitle,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha((0.2 * 255).round()),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.local_car_wash, color: Colors.white, size: 36),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      _HomeStatCard(
                        icon: Icons.map,
                        label: loc.nearestStationLabel,
                        value: loc.nearestStationValue,
                      ),
                      const SizedBox(width: 12),
                      _HomeStatCard(
                        icon: Icons.support_agent,
                        label: loc.supportLabel,
                        value: loc.supportValue,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.startNow,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    runSpacing: 12,
                    spacing: 12,
                    children: [
                      _ActionCard(
                        title: loc.actionStationsTitle,
                        subtitle: loc.actionStationsSubtitle,
                        icon: Icons.list_alt,
                        color: Colors.indigo,
                        onTap: () => Navigator.pushReplacementNamed(context, StationListScreen.routeName),
                      ),
                      _ActionCard(
                        title: loc.actionMapTitle,
                        subtitle: loc.actionMapSubtitle,
                        icon: Icons.map,
                        color: Colors.teal,
                        onTap: () => Navigator.pushReplacementNamed(context, StationMapScreen.routeName),
                      ),
                      _ActionCard(
                        title: loc.actionQuickBookingTitle,
                        subtitle: loc.actionQuickBookingSubtitle,
                        icon: Icons.calendar_today,
                        color: Colors.orange,
                        onTap: () => Navigator.pushReplacementNamed(context, BookingScreen.routeName),
                      ),
                      _ActionCard(
                        title: loc.actionOwnerLoginTitle,
                        subtitle: loc.actionOwnerLoginSubtitle,
                        icon: Icons.person,
                        color: Colors.purple,
                        onTap: () => Navigator.pushReplacementNamed(context, OwnerLoginScreen.routeName),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    loc.howItWorksTitle,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    loc.howItWorksSteps,
                    style: const TextStyle(fontSize: 16, height: 1.6),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _HomeStatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha((0.18 * 255).round()),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 6),
                  Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 56) / 2,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: color.withAlpha((0.3 * 255).round()),
                blurRadius: 12,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha((0.2 * 255).round()),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(height: 18),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
            ],
          ),
        ),
      ),
    );
  }
}
