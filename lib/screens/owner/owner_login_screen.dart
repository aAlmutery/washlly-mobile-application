import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/owner_session.dart';
import '../../services/notification_service.dart';
import '../../services/owner_session_service.dart';
import '../../services/supabase_service.dart';
import '../../utils/location_utils.dart';
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
      final ownerPhone = ownerData['owner_phone'] as String? ?? '';
      await OwnerSessionService.instance.saveOwnerSession(OwnerSession(
        stationId: ownerData['station_id'] as String? ?? '',
        ownerPhone: ownerPhone,
        sessionToken: ownerData['session_token'] as String? ?? '',
        stationName: ownerData['station_name'] as String? ?? '',
      ));
      NotificationService.instance.linkToken(phone: ownerPhone, role: 'owner');
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
  static const _governorates = [
    'Baghdad', 'Basra', 'Nineveh', 'Erbil', 'Sulaymaniyah', 'Duhok',
    'Kirkuk', 'Anbar', 'Babylon', 'Diyala', 'Karbala', 'Maysan',
    'Muthanna', 'Najaf', 'Qadisiyyah', 'Saladin', 'Thi Qar', 'Wasit',
  ];

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _stationNameController = TextEditingController();
  String? _selectedGovernorate;
  final List<Map<String, dynamic>> _services = [];
  List<String> _serviceNames = [];
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _stationNameController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadServiceNames();
  }

  Future<void> _loadServiceNames() async {
    try {
      final names = await SupabaseService.instance.fetchServiceNames();
      if (mounted) setState(() => _serviceNames = names);
    } catch (_) {}
  }

  Future<void> _showAddServiceDialog() async {
    final loc = AppLocalizations.of(context)!;
    if (_serviceNames.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.ownerServiceInvalidInput)),
      );
      return;
    }

    String? selectedName;
    final priceController = TextEditingController();
    final durationController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(loc.ownerAddService),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedName,
                isExpanded: true,
                decoration: InputDecoration(labelText: loc.ownerServiceName),
                items: _serviceNames
                    .map((n) => DropdownMenuItem(
                          value: n,
                          child: Text(n, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (v) => setDialogState(() => selectedName = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceController,
                decoration: InputDecoration(labelText: loc.ownerServicePrice),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: durationController,
                decoration: InputDecoration(labelText: loc.ownerServiceDuration),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(loc.cancelButton),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(loc.ownerAddServiceBtn),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    final name = selectedName ?? '';
    final price = int.tryParse(priceController.text.trim()) ?? 0;
    final duration = int.tryParse(durationController.text.trim()) ?? 30;
    if (name.isEmpty || price <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.ownerServiceInvalidInput)),
        );
      }
      return;
    }
    setState(() {
      _services.add({
        'name': name,
        'price': price,
        'duration_minutes': duration,
        'customer_discount': null,
        'sort_order': _services.length,
      });
    });
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate() || _selectedGovernorate == null) return;
    if (_services.isEmpty) {
      final loc = AppLocalizations.of(context)!;
      setState(() => _error = loc.ownerRegisterServiceRequired);
      return;
    }
    setState(() { _loading = true; _error = null; });

    // Fetch current location; fall back to 0.0 if permission denied or unavailable.
    double lat = 0.0;
    double lng = 0.0;
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final accuracy = await resolveLocationAccuracy();
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(accuracy: accuracy),
        );
        lat = pos.latitude;
        lng = pos.longitude;
      }
    } catch (_) {}

    try {
      await SupabaseService.instance.ownerSelfRegister(
        ownerName: _nameController.text.trim(),
        ownerPhone: _phoneController.text.trim(),
        password: _passwordController.text,
        station: {
          'name': _stationNameController.text.trim(),
          'address': _selectedGovernorate!,
          'detailed_address': '',
          'working_hours_start': '08:00',
          'working_hours_end': '22:00',
          'scheduling_type': 'slots',
          'slot_duration_minutes': 30,
          'latitude': lat,
          'longitude': lng,
          'image_url': null,
          'category': 'car_wash',
        },
        services: _services,
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
      final ownerPhone = ownerData['owner_phone'] as String? ?? '';
      await OwnerSessionService.instance.saveOwnerSession(OwnerSession(
        stationId: ownerData['station_id'] as String? ?? '',
        ownerPhone: ownerPhone,
        sessionToken: ownerData['session_token'] as String? ?? '',
        stationName: ownerData['station_name'] as String? ?? '',
      ));
      NotificationService.instance.linkToken(phone: ownerPhone, role: 'owner');
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
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              decoration: InputDecoration(
                labelText: loc.confirmPasswordLabel,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirmPassword
                      ? Icons.visibility
                      : Icons.visibility_off),
                  onPressed: () => setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return loc.fieldRequired;
                if (v != _passwordController.text) return loc.passwordMismatch;
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
            DropdownButtonFormField<String>(
              value: _selectedGovernorate,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: loc.ownerStationGovernorateLabel,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.location_city),
              ),
              items: _governorates
                  .map((g) => DropdownMenuItem(
                        value: g,
                        child: Text(g, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedGovernorate = v),
              validator: (_) => _selectedGovernorate == null
                  ? loc.ownerStationGovernorateRequired
                  : null,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  loc.ownerMyServices,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                TextButton.icon(
                  onPressed: _showAddServiceDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(loc.ownerAddService),
                ),
              ],
            ),
            if (_services.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  loc.ownerNoServices,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _services.length,
                itemBuilder: (_, i) {
                  final svc = _services[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(svc['name'] as String),
                      subtitle: Text(
                        '${svc['price']} IQD · ${svc['duration_minutes']} ${loc.ownerServiceDurationSuffix}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => setState(() => _services.removeAt(i)),
                      ),
                    ),
                  );
                },
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
