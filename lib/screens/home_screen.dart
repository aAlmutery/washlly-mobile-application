import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/bottom_nav_scaffold.dart';
import 'customer/booking_screen.dart';
import 'customer/profile_screen.dart';
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
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primaryDark, AppColors.primaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(AppSpacing.radiusXl),
                  bottomRight: Radius.circular(AppSpacing.radiusXl),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, 28, AppSpacing.lg, AppSpacing.xl,
              ),
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
                              style: AppTextStyles.headlineMedium.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              loc.welcomeSubtitle,
                              style: AppTextStyles.bodyLarge.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
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
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      _HomeStatCard(
                        icon: Icons.map,
                        label: loc.nearestStationLabel,
                        value: loc.nearestStationValue,
                      ),
                      const SizedBox(width: AppSpacing.sm),
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
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(loc.startNow, style: AppTextStyles.titleLarge),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    runSpacing: AppSpacing.sm,
                    spacing: AppSpacing.sm,
                    children: [
                      _ActionCard(
                        title: loc.actionStationsTitle,
                        subtitle: loc.actionStationsSubtitle,
                        icon: Icons.list_alt,
                        color: const Color(0xFF3949AB), // indigo
                        onTap: () => Navigator.pushReplacementNamed(context, StationListScreen.routeName),
                      ),
                      _ActionCard(
                        title: loc.actionMapTitle,
                        subtitle: loc.actionMapSubtitle,
                        icon: Icons.map,
                        color: const Color(0xFF00897B), // teal
                        onTap: () => Navigator.pushReplacementNamed(context, StationMapScreen.routeName),
                      ),
                      _ActionCard(
                        title: loc.actionQuickBookingTitle,
                        subtitle: loc.actionQuickBookingSubtitle,
                        icon: Icons.calendar_today,
                        color: AppColors.warning,
                        onTap: () => Navigator.pushReplacementNamed(context, BookingScreen.routeName),
                      ),
                      _ActionCard(
                        title: loc.bottomProfile,
                        subtitle: loc.actionOwnerLoginSubtitle,
                        icon: Icons.account_circle,
                        color: AppColors.statusPendingCustomer,
                        onTap: () => Navigator.pushReplacementNamed(context, ProfileScreen.routeName),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(loc.howItWorksTitle, style: AppTextStyles.titleLarge),
                  const SizedBox(height: AppSpacing.sm),
                  Text(loc.howItWorksSteps, style: AppTextStyles.bodyLarge),
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
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha((0.18 * 255).round()),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.labelSmall.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    value,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
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
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
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
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                subtitle,
                style: AppTextStyles.bodySmall.copyWith(
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
