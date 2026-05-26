import 'dart:async';

import 'package:flutter/material.dart';

import '../services/owner_session_service.dart';
import '../state/customer_session_notifier.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'home_screen.dart';
import 'owner/owner_shell.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class WelcomeScreen extends StatefulWidget {
  final CustomerSessionNotifier sessionNotifier;

  const WelcomeScreen({super.key, required this.sessionNotifier});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 2), () async {
      if (!mounted) return;
      final ownerSession = await OwnerSessionService.instance.loadOwnerSession();
      if (!mounted) return;
      if (ownerSession != null) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          OwnerShell.routeName,
          (route) => false,
        );
      } else {
        Navigator.pushNamedAndRemoveUntil(
          context,
          HomeScreen.routeName,
          (route) => false,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.lg),
              Text(
                AppLocalizations.of(context)!.welcomeTitle,
                style: AppTextStyles.displayLarge.copyWith(
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                AppLocalizations.of(context)!.welcomeSubtitle,
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.normal,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                AppLocalizations.of(context)!.welcomeFeaturesTitle,
                style: AppTextStyles.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              _FeatureItem(text: AppLocalizations.of(context)!.featureMap),
              _FeatureItem(text: AppLocalizations.of(context)!.featureServices),
              _FeatureItem(text: AppLocalizations.of(context)!.featureQuickBooking),
              _FeatureItem(text: AppLocalizations.of(context)!.featureManageBookings),
              const Spacer(),
              const Center(
                child: CircularProgressIndicator(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final String text;

  const _FeatureItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm + 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
          const SizedBox(width: AppSpacing.sm + 4),
          Expanded(
            child: Text(text, style: AppTextStyles.bodyLarge),
          ),
        ],
      ),
    );
  }
}
