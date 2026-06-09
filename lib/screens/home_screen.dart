import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../models/customer_notification.dart';
import '../models/customer_session.dart';
import '../services/session_service.dart';
import '../services/supabase_service.dart';
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
                return _ServiceCard(
                  service: svc,
                  onTap: () => Navigator.pushNamed(
                      context, BookingScreen.routeName),
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

class _WelcomeHeader extends StatefulWidget {
  const _WelcomeHeader();

  @override
  State<_WelcomeHeader> createState() => _WelcomeHeaderState();
}

class _WelcomeHeaderState extends State<_WelcomeHeader> {
  CustomerSession? _session;
  List<CustomerNotification> _notifications = [];

  int get _unreadCount => _notifications.where((n) => !n.isRead).length;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final session = await SessionService.instance.loadCustomerSession();
    if (!mounted || session == null) return;
    setState(() => _session = session);
    try {
      final data = await SupabaseService.instance.customerGetInbox(
        customerPhone: session.customerPhone,
        sessionToken: session.sessionToken,
      );
      if (!mounted) return;
      setState(() {
        _notifications = (data['notifications'] as List? ?? [])
            .map((n) => CustomerNotification.fromJson(n as Map<String, dynamic>))
            .toList();
      });
    } catch (_) {}
  }

  void _markRead(String id) {
    setState(() {
      _notifications = _notifications.map((n) => n.id == id
          ? CustomerNotification(
              id: n.id, title: n.title, body: n.body,
              referenceBookingId: n.referenceBookingId,
              isRead: true, createdAt: n.createdAt)
          : n).toList();
    });
    if (_session != null) {
      SupabaseService.instance.customerMarkNotificationRead(
        customerPhone: _session!.customerPhone,
        sessionToken: _session!.sessionToken,
        notificationId: id,
      );
    }
  }

  void _markAllRead() {
    setState(() {
      _notifications = _notifications.map((n) => CustomerNotification(
            id: n.id, title: n.title, body: n.body,
            referenceBookingId: n.referenceBookingId,
            isRead: true, createdAt: n.createdAt)).toList();
    });
    if (_session != null) {
      SupabaseService.instance.customerMarkNotificationRead(
        customerPhone: _session!.customerPhone,
        sessionToken: _session!.sessionToken,
        markAll: true,
      );
    }
  }

  void _showNotificationsPopup() {
    final loc = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _NotificationsSheet(
        loc: loc,
        notifications: _notifications,
        onMarkRead: _markRead,
        onMarkAllRead: _markAllRead,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final hasUnread = _unreadCount > 0;

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
                onTap: _showNotificationsPopup,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: hasUnread
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
                    if (hasUnread)
                      Positioned(
                        top: 5,
                        right: 5,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF5252),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppColors.primaryDark, width: 1.5),
                          ),
                          constraints: const BoxConstraints(
                              minWidth: 16, minHeight: 16),
                          child: Text(
                            _unreadCount > 99 ? '99+' : '$_unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
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
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceCardDark : AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
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
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: svc.accent.withAlpha(28),
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Icon(svc.icon, color: svc.accent, size: 26),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                svc.title,
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                svc.subtitle,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xs),
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
      onTap: () =>
          Navigator.pushNamed(context, BookingScreen.routeName),
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

// ─── Notifications popup sheet ─────────────────────────────────────────────

class _NotificationsSheet extends StatelessWidget {
  final AppLocalizations loc;
  final List<CustomerNotification> notifications;
  final void Function(String id) onMarkRead;
  final VoidCallback onMarkAllRead;

  const _NotificationsSheet({
    required this.loc,
    required this.notifications,
    required this.onMarkRead,
    required this.onMarkAllRead,
  });

  @override
  Widget build(BuildContext context) {
    final hasUnread = notifications.any((n) => !n.isRead);
    final maxHeight = MediaQuery.of(context).size.height * 0.7;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 8, AppSpacing.sm, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    loc.notificationsLabel,
                    style: AppTextStyles.titleLarge,
                  ),
                ),
                if (hasUnread)
                  TextButton.icon(
                    onPressed: () {
                      onMarkAllRead();
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.done_all_rounded, size: 16),
                    label: Text(loc.markAllRead,
                        style: const TextStyle(fontSize: 13)),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.success),
                  ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Body
          if (notifications.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.notifications_off_outlined,
                        size: 48, color: AppColors.textDisabled),
                    const SizedBox(height: AppSpacing.sm),
                    Text(loc.noNotifications,
                        style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary)),
                  ],
                ),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                shrinkWrap: true,
                itemCount: notifications.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 16, endIndent: 16),
                itemBuilder: (context, index) {
                  final notif = notifications[index];
                  return ListTile(
                    onTap: notif.isRead
                        ? null
                        : () => onMarkRead(notif.id),
                    tileColor: notif.isRead
                        ? null
                        : Theme.of(context).brightness == Brightness.dark
                            ? AppColors.success.withAlpha(30)
                            : AppColors.successSurface,
                    leading: CircleAvatar(
                      backgroundColor: notif.isRead
                          ? AppColors.divider
                          : AppColors.primarySurface,
                      child: Icon(
                        Icons.notifications_outlined,
                        size: 20,
                        color: notif.isRead
                            ? AppColors.textDisabled
                            : AppColors.primary,
                      ),
                    ),
                    title: Text(
                      notif.title,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: notif.isRead
                            ? FontWeight.normal
                            : FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(notif.body,
                        style: AppTextStyles.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    trailing: !notif.isRead
                        ? const Icon(Icons.circle,
                            color: AppColors.success, size: 10)
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
                  );
                },
              ),
            ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}
