import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../widgets/bottom_nav_scaffold.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class OwnerLoginScreen extends StatefulWidget {
  static const routeName = '/owner';

  const OwnerLoginScreen({super.key});

  @override
  State<OwnerLoginScreen> createState() => _OwnerLoginScreenState();
}

class _OwnerLoginScreenState extends State<OwnerLoginScreen> {
  final _phoneController = TextEditingController();
  bool _loading = false;
  String? _result;

  Future<void> _lookupOwner() async {
    if (_phoneController.text.trim().isEmpty) {
      setState(() {
        final loc = AppLocalizations.of(context)!;
        _result = loc.ownerEnterPhone;
      });
      return;
    }
    setState(() {
      _loading = true;
      _result = null;
    });
    try {
      final response = await SupabaseService.instance.ownerLoginLookup(_phoneController.text.trim());
      setState(() {
        final loc = AppLocalizations.of(context)!;
        _result = '${loc.ownerFoundPrefix}${response['email']}';
      });
    } catch (error) {
      setState(() {
        final loc = AppLocalizations.of(context)!;
        _result = '${loc.ownerSearchFailedPrefix}$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return BottomNavScaffold(
      currentIndex: 4,
      title: loc.ownerTitle,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              loc.ownerDescription,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: loc.ownerPhoneLabel,
                hintText: loc.ownerPhoneHint,
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : _lookupOwner,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(_loading ? loc.ownerSearching : loc.ownerSearchButton),
              ),
            ),
            const SizedBox(height: 20),
            if (_result != null)
              Text(
                _result!,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
          ],
        ),
      ),
    );
  }
}
