import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../models/customer_session.dart';
import '../../services/supabase_service.dart';
import '../../state/customer_session_notifier.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/bottom_nav_scaffold.dart';
import 'customer_booking_history_screen.dart';
import 'inbox_screen.dart';
import '../owner/owner_login_screen.dart';

class ProfileScreen extends StatefulWidget {
  static const routeName = '/profile';

  final CustomerSessionNotifier sessionNotifier;

  const ProfileScreen({super.key, required this.sessionNotifier});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _logout() async {
    await widget.sessionNotifier.logout();
    if (mounted) {
      final loc = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.profileLogoutSuccess)),
      );
    }
  }

  void _openLoginSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _CustomerLoginSheet(
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
                    _ProfileOptionCard(
                      iconData: Icons.notifications_rounded,
                      iconColor: AppColors.primary,
                      iconBackground: AppColors.primarySurface,
                      title: loc.notificationsLabel,
                      subtitle: loc.noNotifications,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const InboxScreen()),
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  // Owner Login Option
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
                  // Settings Option
                  _ProfileOptionCard(
                    iconData: Icons.settings,
                    iconColor: AppColors.primary,
                    iconBackground: AppColors.primarySurface,
                    title: loc.profileAccountSettings,
                    subtitle: loc.profileAccountSettingsDesc,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(loc.profileSettingsComingSoon)),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Help Option
                  _ProfileOptionCard(
                    iconData: Icons.help,
                    iconColor: AppColors.primary,
                    iconBackground: AppColors.primarySurface,
                    title: loc.profileHelpSupport,
                    subtitle: loc.profileHelpSupportDesc,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(loc.profileSupportComingSoon)),
                      );
                    },
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

// ---------- Customer Login Bottom Sheet ----------

class _CustomerLoginSheet extends StatefulWidget {
  final void Function(CustomerSession session) onSuccess;

  const _CustomerLoginSheet({required this.onSuccess});

  @override
  State<_CustomerLoginSheet> createState() => _CustomerLoginSheetState();
}

class _CustomerLoginSheetState extends State<_CustomerLoginSheet> {
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  bool _requiresName = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final loc = AppLocalizations.of(context)!;
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = loc.phoneRequired);
      return;
    }
    if (_requiresName && _nameController.text.trim().isEmpty) {
      setState(() => _error = loc.customerNameRequiredPrompt);
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      final result = await SupabaseService.instance.customerLoginByPhone(
        customerPhone: phone,
        customerName: _requiresName ? _nameController.text.trim() : null,
      );

      if (result['requires_name'] == true) {
        setState(() { _requiresName = true; _loading = false; });
        return;
      }

      final session = CustomerSession(
        customerPhone: result['customer_phone'] as String,
        customerName: result['customer_name'] as String,
        sessionToken: result['session_token'] as String,
        expiresAt: DateTime.parse(result['expires_at'] as String),
      );
      widget.onSuccess(session);
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            loc.customerLoginTitle,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _phoneController,
            decoration: InputDecoration(
              labelText: loc.ownerPhoneLabel,
              hintText: loc.customerPhoneHint,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.phone),
            ),
            keyboardType: TextInputType.phone,
            enabled: !_requiresName,
          ),
          if (_requiresName) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              loc.customerNameRequiredPrompt,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: loc.fullNameLabel,
                hintText: loc.customerNameHint,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.person),
              ),
              textCapitalization: TextCapitalization.words,
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _error!,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(
            onPressed: _loading ? null : _submit,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            ),
            child: _loading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(loc.customerLoginBtn),
          ),
        ],
      ),
    );
  }
}
