import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/owner_session.dart';
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
  XFile? _stationImage;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _stationNameController.dispose();
    _stationAddressController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final loc = AppLocalizations.of(context)!;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(loc.stationImagePickGallery),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(loc.stationImageTakePhoto),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            if (_stationImage != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: Text(loc.stationImageRemove,
                    style: const TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _stationImage = null);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    if (picked != null && mounted) {
      setState(() => _stationImage = picked);
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
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
          'address': _stationAddressController.text.trim(),
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
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _stationImage != null
                        ? Colors.blue.shade300
                        : Colors.grey.shade300,
                    width: 1.5,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: _stationImage != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(
                            File(_stationImage!.path),
                            fit: BoxFit.cover,
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _stationImage = null),
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(6),
                                child: const Icon(Icons.close,
                                    color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined,
                              size: 44,
                              color: Colors.blue.shade300),
                          const SizedBox(height: 8),
                          Text(
                            loc.stationImageLabel,
                            style: TextStyle(
                              color: Colors.blue.shade600,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            loc.stationImageOptional,
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
              ),
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
