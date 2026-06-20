import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../models/customer_session.dart';
import '../services/session_service.dart';
import '../services/supabase_service.dart';
import '../state/customer_session_notifier.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Shows the customer login sheet if no session exists, then calls
/// [onAuthenticated]. If already logged in, calls [onAuthenticated] immediately.
Future<void> requireCustomerLogin(
  BuildContext context, {
  required Future<void> Function(CustomerSession session) onAuthenticated,
}) async {
  final session = await SessionService.instance.loadCustomerSession();
  if (!context.mounted) return;
  if (session != null) {
    await onAuthenticated(session);
    return;
  }
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => CustomerLoginSheet(
      onSuccess: (newSession) async {
        await CustomerSessionNotifier.instance.save(newSession);
        if (!ctx.mounted) return;
        Navigator.pop(ctx);
        if (!context.mounted) return;
        await onAuthenticated(newSession);
      },
    ),
  );
}

class CustomerLoginSheet extends StatefulWidget {
  final void Function(CustomerSession session) onSuccess;

  const CustomerLoginSheet({super.key, required this.onSuccess});

  @override
  State<CustomerLoginSheet> createState() => _CustomerLoginSheetState();
}

class _CustomerLoginSheetState extends State<CustomerLoginSheet> {
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

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await SupabaseService.instance.customerLoginByPhone(
        customerPhone: phone,
        customerName: _requiresName ? _nameController.text.trim() : null,
      );

      if (result['requires_name'] == true) {
        setState(() {
          _requiresName = true;
          _loading = false;
        });
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
      setState(() {
        _error = e.toString();
        _loading = false;
      });
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
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(loc.customerLoginBtn),
          ),
        ],
      ),
    );
  }
}
