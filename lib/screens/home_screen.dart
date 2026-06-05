import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/bottom_nav_scaffold.dart';
import 'customer/booking_screen.dart';
import 'station_list_screen.dart';
import 'station_map_screen.dart';

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
  int? _selectedIndex;
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

  void _setFilter(_Filter f) => setState(() {
        _filter = f;
        _selectedIndex = null;
      });

  void _toggleService(int globalIndex) => setState(() {
        _selectedIndex = _selectedIndex == globalIndex ? null : globalIndex;
      });

  void _openBookSheet() {
    final svc =
        _selectedIndex != null ? _allServices[_selectedIndex!] : null;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QuickBookSheet(service: svc),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final filtered = _filtered;

    return BottomNavScaffold(
      currentIndex: 0,
      title: loc.appTitle,
      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _BookFab(
        label: _selectedIndex != null
            ? _allServices[_selectedIndex!].title
            : loc.homeQuickBook,
        accent: _selectedIndex != null
            ? _allServices[_selectedIndex!].accent
            : AppColors.primary,
        onTap: _openBookSheet,
      ),
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
                mainAxisSpacing: AppSpacing.md,
                crossAxisSpacing: AppSpacing.md,
                mainAxisExtent: 220,
              ),
              itemCount: filtered.length,
              itemBuilder: (context, i) {
                final svc = filtered[i];
                final globalIdx = _allServices.indexOf(svc);
                return _ServiceCard(
                  service: svc,
                  selected: _selectedIndex == globalIdx,
                  onTap: () => _toggleService(globalIdx),
                );
              },
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, 0, AppSpacing.md, AppSpacing.xl,
            ),
            sliver: SliverToBoxAdapter(
              child: _PromoBanner(onTap: _openBookSheet),
            ),
          ),
          // Bottom clearance so content is not hidden behind the FAB
          const SliverToBoxAdapter(child: SizedBox(height: 88)),
        ],
      ),
    );
  }
}

// ─── Welcome Header ────────────────────────────────────────────────────────

class _WelcomeHeader extends StatefulWidget {
  const _WelcomeHeader();

  @override
  State<_WelcomeHeader> createState() => _WelcomeHeaderState();
}

class _WelcomeHeaderState extends State<_WelcomeHeader> {
  bool _hasNotif = true;

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
                child:
                    const Icon(Icons.person, color: Colors.white, size: 28),
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
              // Notification bell
              GestureDetector(
                onTap: () => setState(() => _hasNotif = !_hasNotif),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _hasNotif
                            ? Colors.white.withAlpha(55)
                            : Colors.white.withAlpha(30),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_outlined,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    if (_hasNotif)
                      Positioned(
                        top: 7,
                        right: 7,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF5252),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppColors.primaryDark, width: 1.5),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // Quick-navigation pills
          Row(
            children: [
              _NavPill(
                icon: Icons.map_outlined,
                label: loc.actionMapTitle,
                onTap: () => Navigator.pushReplacementNamed(
                    context, StationMapScreen.routeName),
              ),
              const SizedBox(width: AppSpacing.sm),
              _NavPill(
                icon: Icons.list_alt_outlined,
                label: loc.actionStationsTitle,
                onTap: () => Navigator.pushReplacementNamed(
                    context, StationListScreen.routeName),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NavPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 2,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(35),
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            border: Border.all(color: Colors.white30),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  label,
                  style: AppTextStyles.labelLarge.copyWith(color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
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
  final bool selected;
  final VoidCallback onTap;

  const _ServiceCard({
    required this.service,
    required this.selected,
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
    final sel = widget.selected;
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: sel
                ? svc.accent.withAlpha(isDark ? 38 : 18)
                : (isDark
                    ? AppColors.surfaceCardDark
                    : AppColors.surfaceCard),
            borderRadius:
                BorderRadius.circular(AppSpacing.radiusXl),
            border: Border.all(
              color: sel ? svc.accent : AppColors.divider,
              width: sel ? 2.0 : 1.0,
            ),
            boxShadow: sel
                ? [
                    BoxShadow(
                      color: svc.accent.withAlpha(55),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : [
                    BoxShadow(
                      color:
                          Colors.black.withAlpha(isDark ? 28 : 10),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon row with selection indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: sel
                          ? svc.accent.withAlpha(50)
                          : svc.accent.withAlpha(28),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: Icon(svc.icon, color: svc.accent, size: 26),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: sel
                        ? Icon(Icons.check_circle,
                            key: const ValueKey('check'),
                            color: svc.accent,
                            size: 20)
                        : const SizedBox(
                            key: ValueKey('empty'),
                            width: 20,
                            height: 20),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              // Title
              Text(
                svc.title,
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: sel ? svc.accent : null,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xs),
              // Subtitle
              Text(
                svc.subtitle,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xs),
              // Price badge
              AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: sel ? svc.accent : AppColors.primarySurface,
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: Text(
                  '${svc.price}${loc.servicePriceCurrencySuffix}',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: sel ? Colors.white : AppColors.primary,
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
  final VoidCallback onTap;

  const _PromoBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return GestureDetector(
      onTap: onTap,
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
                  // "Special Offer" pill
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

// ─── Quick-book bottom sheet ───────────────────────────────────────────────

class _QuickBookSheet extends StatelessWidget {
  final _Service? service;

  const _QuickBookSheet({this.service});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final svc = service;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceCardDark : AppColors.surfaceCard,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(45),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.sm,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            ),
          ),
          if (svc != null) ...[
            // Selected service row
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: svc.accent.withAlpha(30),
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Icon(svc.icon, color: svc.accent, size: 30),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(svc.title, style: AppTextStyles.titleMedium),
                      Text(
                        svc.subtitle,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusFull),
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
            const SizedBox(height: AppSpacing.lg),
          ] else ...[
            Text(loc.homeQuickBook, style: AppTextStyles.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              loc.chooseServiceLabel,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(
                    context, BookingScreen.routeName);
              },
              icon: const Icon(Icons.flash_on_rounded),
              label: Text(loc.homeBookNow),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── FAB ───────────────────────────────────────────────────────────────────

class _BookFab extends StatelessWidget {
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _BookFab({
    required this.label,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onTap,
      backgroundColor: accent,
      foregroundColor: Colors.white,
      elevation: 6,
      icon: const Icon(Icons.flash_on_rounded),
      label: Text(
        label,
        style: AppTextStyles.labelLarge.copyWith(color: Colors.white),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }
}
