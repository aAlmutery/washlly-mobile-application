import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../state/customer_session_notifier.dart';
import '../../state/locale_notifier.dart';
import '../../state/theme_mode_notifier.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/bottom_nav_scaffold.dart';
import '../../widgets/customer_login_sheet.dart';
import '../home_screen.dart';
import 'customer_booking_history_screen.dart';
import 'inbox_screen.dart';
import 'settings_screen.dart';
import '../owner/owner_login_screen.dart';

class ProfileScreen extends StatefulWidget {
  static const routeName = '/profile';

  final CustomerSessionNotifier sessionNotifier;
  final LocaleNotifier localeNotifier;
  final ThemeModeNotifier themeModeNotifier;

  const ProfileScreen({
    super.key,
    required this.sessionNotifier,
    required this.localeNotifier,
    required this.themeModeNotifier,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _logout() async {
    final loc = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.profileLogoutConfirmTitle),
        content: Text(loc.profileLogoutConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(loc.noBtn),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(loc.profileLogout, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.sessionNotifier.logout();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        HomeScreen.routeName,
        (route) => false,
      );
    }
  }

  Future<void> _openWhatsAppSupport() async {
    final loc = AppLocalizations.of(context)!;
    final action = await showDialog<_SupportAction>(
      context: context,
      builder: (ctx) => _WhatsAppSupportDialog(loc: loc),
    );
    if (action == null) return;
    final uri = action == _SupportAction.whatsapp
        ? Uri.parse('https://wa.me/9647506033421')
        : Uri.parse('tel:+9647506033421');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          localeNotifier: widget.localeNotifier,
          themeModeNotifier: widget.themeModeNotifier,
        ),
      ),
    );
  }

  void _openLoginSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => CustomerLoginSheet(
        onSuccess: (session) async {
          Navigator.pop(ctx);
          await widget.sessionNotifier.save(session);
          if (mounted) {
            final loc = AppLocalizations.of(context)!;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(loc.customerLoginSuccess)),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final notifier = widget.sessionNotifier;

    return BottomNavScaffold(
      currentIndex: 3,
      title: loc.bottomProfile,
      appBarActions: notifier.session != null
          ? [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                tooltip: loc.notificationsLabel,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const InboxScreen()),
                ),
              ),
            ]
          : null,
      body: !notifier.loaded
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Profile Card
                  if (notifier.session != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Row(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: const BoxDecoration(
                                color: AppColors.primaryLight,
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Icon(Icons.person, size: 32, color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    notifier.session!.customerName,
                                    style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    notifier.session!.customerPhone,
                                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Card(
                      color: AppColors.primarySurface,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.person_outline, size: 40, color: AppColors.primary),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        loc.welcomeTitle,
                                        style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: AppSpacing.xs),
                                      Text(
                                        loc.profileLoginPrompt,
                                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _openLoginSheet,
                                child: Text(loc.profileLoginButton),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(loc.profileOptionsTitle, style: AppTextStyles.titleMedium),
                  const SizedBox(height: AppSpacing.md),
                  // Booking History + Notifications — only when logged in
                  if (notifier.session != null) ...[
                    _ProfileOptionCard(
                      iconData: Icons.history,
                      iconColor: AppColors.primary,
                      iconBackground: AppColors.primarySurface,
                      title: loc.bookingHistoryTitle,
                      subtitle: loc.bookingHistorySubtitle,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CustomerBookingHistoryScreen(session: notifier.session!),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  // Owner Login Option — hidden when a customer session is active.
                  if (notifier.session == null) ...[
                    _ProfileOptionCard(
                      iconData: Icons.business,
                      iconColor: AppColors.primary,
                      iconBackground: AppColors.primarySurface,
                      title: loc.actionOwnerLoginTitle,
                      subtitle: loc.profileOwnerLoginDesc,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const OwnerLoginScreen()),
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  // Settings Option
                  _ProfileOptionCard(
                    iconData: Icons.settings,
                    iconColor: AppColors.primary,
                    iconBackground: AppColors.primarySurface,
                    title: loc.profileSettings,
                    subtitle: loc.profileSettingsDesc,
                    onTap: _openSettings,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Help Option
                  _ProfileOptionCard(
                    iconData: Icons.help,
                    iconColor: AppColors.primary,
                    iconBackground: AppColors.primarySurface,
                    title: loc.profileHelpSupport,
                    subtitle: loc.profileHelpSupportDesc,
                    onTap: _openWhatsAppSupport,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // About Option
                  _ProfileOptionCard(
                    iconData: Icons.info,
                    iconColor: AppColors.primary,
                    iconBackground: AppColors.primarySurface,
                    title: loc.profileAboutTitle,
                    subtitle: loc.profileAboutDesc,
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) {
                          final dlgLoc = AppLocalizations.of(context)!;
                          return AlertDialog(
                            title: Text(dlgLoc.profileAboutTitle),
                            content: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    dlgLoc.profileAboutAppName,
                                    style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(dlgLoc.profileVersion, style: AppTextStyles.bodyMedium),
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(dlgLoc.profileAboutContent, style: AppTextStyles.bodyMedium),
                                ],
                              ),
                            ),
                            actions: [
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text(dlgLoc.profileClose),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (notifier.session != null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _logout,
                        icon: const Icon(Icons.logout),
                        label: Text(loc.profileLogout),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

// ---------- Reusable profile option row card ----------

class _ProfileOptionCard extends StatelessWidget {
  final IconData iconData;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProfileOptionCard({
    required this.iconData,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Center(child: Icon(iconData, color: iconColor, size: 28)),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(subtitle, style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.textDisabled),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- WhatsApp Support Dialog ----------

enum _SupportAction { whatsapp, call }

class _WhatsAppSupportDialog extends StatelessWidget {
  final AppLocalizations loc;
  const _WhatsAppSupportDialog({required this.loc});

  static const _whatsappGreen = Color(0xFF25D366);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Gradient header ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1DA851), _whatsappGreen],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(40),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.headset_mic_rounded,
                      color: Colors.white, size: 36),
                ),
                const SizedBox(height: 10),
                Text(
                  loc.profileHelpSupport,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  loc.supportLeaveAppMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withAlpha(200),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // ── Phone number pill ──
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _whatsappGreen.withAlpha(20),
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(color: _whatsappGreen.withAlpha(60)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.phone_rounded,
                        color: _whatsappGreen, size: 15),
                    const SizedBox(width: 6),
                    const Text(
                      '+964 750 603 3421',
                      style: TextStyle(
                        color: _whatsappGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ── Action buttons ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                // WhatsApp button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        Navigator.pop(context, _SupportAction.whatsapp),
                    icon: const Icon(Icons.chat_rounded, size: 18),
                    label: Text(loc.supportOpenWhatsApp),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _whatsappGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Call button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        Navigator.pop(context, _SupportAction.call),
                    icon: const Icon(Icons.call_rounded, size: 18),
                    label: Text(loc.supportCallNow),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ── Cancel ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                ),
                child: Text(loc.cancelButton),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

