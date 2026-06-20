import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../state/customer_session_notifier.dart';
import '../widgets/bottom_nav_scaffold.dart';
import '../widgets/customer_login_sheet.dart';
import '../widgets/notification_bell.dart';
import 'customer/booking_screen.dart';

// ─── Domain ────────────────────────────────────────────────────────────────

enum _Filter { all, popular, recent }

class _Service {
  final String title;
  final String subtitle;
  final String price;
  final IconData icon;
  final Color accent;
  final bool popular;
  final bool recent;

  const _Service({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.icon,
    required this.accent,
    this.popular = false,
    this.recent = false,
  });
}

List<_Service> _buildServices(AppLocalizations l) => [
      _Service(
        title: l.serviceCarWash,
        subtitle: l.serviceCarWashSub,
        price: '5,000',
        icon: Icons.local_car_wash,
        accent: AppColors.primary,
        popular: true,
        recent: true,
      ),
      _Service(
        title: l.serviceOilChange,
        subtitle: l.serviceOilChangeSub,
        price: '25,000',
        icon: Icons.opacity,
        accent: AppColors.warning,
        popular: true,
      ),
      _Service(
        title: l.serviceFullClean,
        subtitle: l.serviceFullCleanSub,
        price: '15,000',
        icon: Icons.cleaning_services,
        accent: const Color(0xFF00897B),
        recent: true,
      ),
      _Service(
        title: l.serviceVipWash,
        subtitle: l.serviceVipWashSub,
        price: '35,000',
        icon: Icons.workspace_premium,
        accent: AppColors.statusPendingCustomer,
        popular: true,
      ),
    ];

// ─── Screen ────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  static const routeName = '/home';

  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  _Filter _filter = _Filter.all;
  late List<_Service> _allServices;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _allServices = _buildServices(AppLocalizations.of(context)!);
  }

  List<_Service> get _filtered => switch (_filter) {
        _Filter.popular => _allServices.where((s) => s.popular).toList(),
        _Filter.recent => _allServices.where((s) => s.recent).toList(),
        _Filter.all => _allServices,
      };

  void _setFilter(_Filter f) => setState(() => _filter = f);

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final filtered = _filtered;

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
          SliverToBoxAdapter(
            child: _FilterBar(active: _filter, onSelect: _setFilter),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.md, AppSpacing.md, 0,
            ),
            sliver: SliverToBoxAdapter(
              child: Text(loc.homeOurServices,
                  style: AppTextStyles.titleLarge),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.md),
            sliver: SliverGrid.builder(
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: AppSpacing.sm,
                crossAxisSpacing: AppSpacing.sm,
                mainAxisExtent: 150,
              ),
              itemCount: filtered.length,
              itemBuilder: (context, i) {
                final svc = filtered[i];
                return _ServiceCard(
                  service: svc,
                  onTap: () => requireCustomerLogin(
                    context,
                    onAuthenticated: (_) async => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BookingScreen(
                          preselectedServiceName: svc.title,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, 0, AppSpacing.md, AppSpacing.xl,
            ),
            sliver: SliverToBoxAdapter(
              child: _PromoBanner(),
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

    return Container(
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
        AppSpacing.lg, 20, AppSpacing.lg, AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar placeholder
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(50),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white38, width: 2),
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 28),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.welcomeTitle,
                      style: AppTextStyles.titleLarge.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      loc.welcomeSubtitle.split('.').first,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white70,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Filter bar ────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final _Filter active;
  final void Function(_Filter) onSelect;

  const _FilterBar({required this.active, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final tabs = [
      (_Filter.all, loc.allServices),
      (_Filter.popular, loc.homeFilterPopular),
      (_Filter.recent, loc.homeFilterRecent),
    ];

    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, i) {
          final (filter, label) = tabs[i];
          return _FilterChip(
            label: label,
            selected: active == filter,
            onTap: () => onSelect(filter),
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs + 2,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelLarge.copyWith(
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ─── Service card ──────────────────────────────────────────────────────────

class _ServiceCard extends StatefulWidget {
  final _Service service;
  final VoidCallback onTap;

  const _ServiceCard({
    required this.service,
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
    final svc = widget.service;
    final loc = AppLocalizations.of(context)!;

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
                  color: svc.accent.withAlpha(28),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Icon(svc.icon, color: svc.accent, size: 22),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                svc.title,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: Text(
                  '${svc.price}${loc.servicePriceCurrencySuffix}',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Promo banner ──────────────────────────────────────────────────────────

class _PromoBanner extends StatelessWidget {
  const _PromoBanner();

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return GestureDetector(
      onTap: () => requireCustomerLogin(
        context,
        onAuthenticated: (_) async =>
            Navigator.pushNamed(context, BookingScreen.routeName),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6A1B9A), Color(0xFF4527A0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6A1B9A).withAlpha(80),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(45),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusFull),
                    ),
                    child: Text(
                      '🎉  ${loc.homeSpecialOffer}',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    loc.homeVipPromoTitle,
                    style: AppTextStyles.titleLarge.copyWith(
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    loc.homeVipPromoOffer,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white70,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusFull),
                    ),
                    child: Text(
                      loc.homeBookNow,
                      style: AppTextStyles.labelLarge.copyWith(
                        color: const Color(0xFF6A1B9A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.workspace_premium,
                color: Colors.white,
                size: 42,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

