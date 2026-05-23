import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../models/owner_session.dart';
import '../../services/owner_session_service.dart';
import '../../services/supabase_service.dart';
import 'owner_shell.dart';

class OwnerLoginScreen extends StatefulWidget {
  static const routeName = '/owner';

  const OwnerLoginScreen({super.key});

  @override
  State<OwnerLoginScreen> createState() => _OwnerLoginScreenState();
}

class _OwnerLoginScreenState extends State<OwnerLoginScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(loc.ownerTitle)),
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: [
              Tab(text: loc.ownerLoginTabTitle),
              Tab(text: loc.ownerRegisterTabTitle),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _LoginTab(),
                _RegisterTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Login Tab ----------

class _LoginTab extends StatefulWidget {
  const _LoginTab();

  @override
  State<_LoginTab> createState() => _LoginTabState();
}

class _LoginTabState extends State<_LoginTab> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      final ownerData = await SupabaseService.instance.ownerSignIn(
        phone: _phoneController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      final loc = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.ownerLoginSuccess)),
      );
      await OwnerSessionService.instance.saveOwnerSession(OwnerSession(
        stationId: ownerData['station_id'] as String? ?? '',
        ownerPhone: ownerData['owner_phone'] as String? ?? '',
        sessionToken: ownerData['session_token'] as String? ?? '',
        stationName: ownerData['station_name'] as String? ?? '',
      ));
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, OwnerShell.routeName, (_) => false);
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            TextFormField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: loc.ownerPhoneLabel,
                hintText: loc.ownerPhoneHint,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? loc.fieldRequired : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: loc.ownerPasswordLabel,
                hintText: loc.ownerPasswordHint,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword
                      ? Icons.visibility
                      : Icons.visibility_off),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return loc.fieldRequired;
                if (v.length < 6) return loc.passwordMinLength;
                return null;
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: const TextStyle(color: Colors.red, fontSize: 13)),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loading ? null : _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade800,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(loc.ownerLoginTabTitle,
                      style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Register Tab ----------

class _RegisterTab extends StatefulWidget {
  const _RegisterTab();

  @override
  State<_RegisterTab> createState() => _RegisterTabState();
}

class _RegisterTabState extends State<_RegisterTab> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _stationNameController = TextEditingController();
  final _stationAddressController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _stationNameController.dispose();
    _stationAddressController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      await SupabaseService.instance.ownerSelfRegister(
        ownerName: _nameController.text.trim(),
        ownerPhone: _phoneController.text.trim(),
        password: _passwordController.text,
        station: {
          'name': _stationNameController.text.trim(),
          'address': _stationAddressController.text.trim(),
          'detailed_address': '',
          'working_hours_start': '08:00',
          'working_hours_end': '22:00',
          'scheduling_type': 'slots',
          'slot_duration_minutes': 30,
          'latitude': 0.0,
          'longitude': 0.0,
          'image_url': null,
          'category': 'car_wash',
        },
        services: [
          {
            'name': 'General wash',
            'price': 5000,
            'duration_minutes': 30,
            'customer_discount': null,
            'sort_order': 0,
          },
        ],
      );
      if (!mounted) return;
      final loc = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.ownerRegisterSuccess)),
      );
      // Auto-login after registration
      final ownerData = await SupabaseService.instance.ownerSignIn(
        phone: _phoneController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      await OwnerSessionService.instance.saveOwnerSession(OwnerSession(
        stationId: ownerData['station_id'] as String? ?? '',
        ownerPhone: ownerData['owner_phone'] as String? ?? '',
        sessionToken: ownerData['session_token'] as String? ?? '',
        stationName: ownerData['station_name'] as String? ?? '',
      ));
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, OwnerShell.routeName, (_) => false);
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: loc.fullNameLabel,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.person),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? loc.fieldRequired : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: loc.ownerPhoneLabel,
                hintText: loc.ownerPhoneHint,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? loc.fieldRequired : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: loc.ownerPasswordLabel,
                hintText: loc.ownerPasswordHint,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword
                      ? Icons.visibility
                      : Icons.visibility_off),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return loc.fieldRequired;
                if (v.length < 6) return loc.passwordMinLength;
                return null;
              },
            ),
            const SizedBox(height: 24),
            Text(
              loc.ownerStationNameLabel,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _stationNameController,
              decoration: InputDecoration(
                labelText: loc.ownerStationNameLabel,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.local_car_wash),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? loc.fieldRequired : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _stationAddressController,
              decoration: InputDecoration(
                labelText: loc.ownerStationAddressLabel,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.location_city),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? loc.fieldRequired : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: const TextStyle(color: Colors.red, fontSize: 13)),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loading ? null : _register,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade800,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(loc.ownerRegisterBtn,
                      style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
