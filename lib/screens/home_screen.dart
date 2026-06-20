import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../state/customer_session_notifier.dart';
import '../widgets/bottom_nav_scaffold.dart';
import '../widgets/notification_bell.dart';
import 'customer/booking_screen.dart';

// ─── Helpers ───────────────────────────────────────────────────────────────

IconData _iconForService(String name) {
  final n = name.toLowerCase();
  if (n.contains('wash') || n.contains('غسيل') || n.contains('غسل')) {
    return Icons.local_car_wash;
  }
  if (n.contains('oil') || n.contains('زيت')) return Icons.opacity;
  if (n.contains('clean') || n.contains('تنظيف')) return Icons.cleaning_services;
  if (n.contains('vip') || n.contains('فاخر') || n.contains('ممتاز')) {
    return Icons.workspace_premium;
  }
  if (n.contains('polish') || n.contains('تلميع')) return Icons.auto_awesome;
  if (n.contains('tire') || n.contains('tyre') || n.contains('إطار')) {
    return Icons.tire_repair;
  }
  if (n.contains('interior') || n.contains('داخل')) return Icons.airline_seat_recline_extra;
  return Icons.car_repair;
}

const _accentColors = [
  AppColors.primary,
  AppColors.warning,
  Color(0xFF00897B),
  AppColors.statusPendingCustomer,
  Color(0xFF00838F),
  AppColors.statusCompleted,
];

// ─── Screen ────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  static const routeName = '/home';

  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<({String name, int minPrice})> _services = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await SupabaseService.instance.fetchDistinctServicesWithPrice();
      if (mounted) setState(() { _services = data.take(4).toList(); _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return BottomNavScaffold(
      currentIndex: 0,
      title: loc.appTitle,
      appBarActions: [
        NotificationBell(
          customerPhone: CustomerSessionNotifier.instance.session?.customerPhone,
          sessionToken: CustomerSessionNotifier.instance.session?.sessionToken,
        ),
      ],
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _WelcomeHeader()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.md, AppSpacing.md, 0,
            ),
            sliver: SliverToBoxAdapter(
              child: Text(loc.homeOurServices, style: AppTextStyles.titleLarge),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null || _services.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Text(
                  _services.isEmpty ? loc.ownerNoServices : (_error ?? ''),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.md),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: AppSpacing.sm,
                  crossAxisSpacing: AppSpacing.sm,
                  mainAxisExtent: 150,
                ),
                itemCount: _services.length,
                itemBuilder: (context, i) {
                  final svc = _services[i];
                  return _ServiceCard(
                    name: svc.name,
                    minPrice: svc.minPrice,
                    icon: _iconForService(svc.name),
                    accent: _accentColors[i % _accentColors.length],
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BookingScreen(
                          preselectedServiceName: svc.name,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Welcome Header ────────────────────────────────────────────────────────

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader();

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(AppSpacing.radiusXl),
          bottomRight: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, 20, AppSpacing.lg, AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loc.welcomeTitle,
                style: AppTextStyles.titleLarge.copyWith(
                  color: cs.onPrimaryContainer,
                ),
              ),
              Text(
                loc.welcomeSubtitle.split('.').first,
                style: AppTextStyles.bodySmall.copyWith(
                  color: cs.onPrimaryContainer.withAlpha(180),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Service card ──────────────────────────────────────────────────────────

class _ServiceCard extends StatefulWidget {
  final String name;
  final int minPrice;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _ServiceCard({
    required this.name,
    required this.minPrice,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  State<_ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends State<_ServiceCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm + 4),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceCardDark : AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: AppColors.divider),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 28 : 10),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: widget.accent.withAlpha(28),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Icon(widget.icon, color: widget.accent, size: 22),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                widget.name,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


