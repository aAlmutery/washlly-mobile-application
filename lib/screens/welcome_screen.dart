import 'dart:async';

import 'package:flutter/material.dart';

import '../services/owner_session_service.dart';
import 'home_screen.dart';
import 'owner/owner_shell.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text(
                AppLocalizations.of(context)!.welcomeTitle,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.welcomeSubtitle,
                style: const TextStyle(fontSize: 18, height: 1.6),
              ),
              const SizedBox(height: 32),
              Text(
                AppLocalizations.of(context)!.welcomeFeaturesTitle,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: Colors.blueAccent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 16, height: 1.5)),
          ),
        ],
      ),
    );
  }
}
