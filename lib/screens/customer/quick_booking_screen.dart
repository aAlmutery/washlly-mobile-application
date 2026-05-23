import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/session_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/bottom_nav_scaffold.dart';

class QuickBookingScreen extends StatefulWidget {
  static const routeName = '/quick-booking';

  const QuickBookingScreen({super.key});

  @override
  State<QuickBookingScreen> createState() => _QuickBookingScreenState();
}

class _QuickBookingScreenState extends State<QuickBookingScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();

  Position? _position;
  bool _loadingLocation = false;
  String? _locationError;
  bool _isBooking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _fetchLocation();
      final session = await SessionService.instance.loadCustomerSession();
      if (mounted && session != null) {
        _nameController.text = session.customerName;
        _phoneController.text = session.customerPhone;
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  Future<void> _fetchLocation() async {
    setState(() {
      _loadingLocation = true;
      _locationError = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          final loc = AppLocalizations.of(context)!;
          setState(() => _locationError = loc.quickLocationDisabled);
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (mounted) {
          final loc = AppLocalizations.of(context)!;
          setState(() => _locationError = loc.quickLocationDenied);
        }
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          final loc = AppLocalizations.of(context)!;
          setState(() => _locationError = loc.quickLocationDeniedForever);
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      if (mounted) setState(() => _position = position);
    } catch (e) {
      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        setState(() => _locationError = loc.quickLocationFailed);
      }
    } finally {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  Future<void> _submit() async {
    final loc = AppLocalizations.of(context)!;
    if (_nameController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty ||
        _dateController.text.isEmpty ||
        _timeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.quickFillAllFields)),
      );
      return;
    }

    if (_position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.quickAllowLocation)),
      );
      return;
    }

    setState(() => _isBooking = true);

    try {
      final result = await SupabaseService.instance.createQuickBooking(
        customerName: _nameController.text.trim(),
        customerPhone: _phoneController.text.trim(),
        bookingDate: _dateController.text,
        bookingTime: _timeController.text,
        serviceKind: 'quick',
        customerLat: _position!.latitude,
        customerLng: _position!.longitude,
      );

      if (mounted) {
        final loc2 = AppLocalizations.of(context)!;
        final count = result['target_count'] ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${loc2.quickBookingSentPrefix}$count${loc2.quickBookingSentSuffix}')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        final loc2 = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${loc2.quickBookingFailedPrefix}$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return BottomNavScaffold(
      currentIndex: 0,
      title: loc.quickBookingTitle,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: loc.fullNameLabel,
              prefixIcon: const Icon(Icons.person),
              border: const OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phoneController,
            decoration: InputDecoration(
              labelText: loc.quickPhoneLabel,
              hintText: loc.quickPhoneHint,
              prefixIcon: const Icon(Icons.phone),
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _dateController,
            decoration: InputDecoration(
              labelText: loc.quickDateLabel,
              prefixIcon: const Icon(Icons.calendar_today),
              border: const OutlineInputBorder(),
            ),
            readOnly: true,
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 30)),
              );
              if (date != null) {
                _dateController.text = date.toString().split(' ')[0];
              }
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _timeController,
            decoration: InputDecoration(
              labelText: loc.quickTimeLabel,
              prefixIcon: const Icon(Icons.access_time),
              border: const OutlineInputBorder(),
            ),
            readOnly: true,
            onTap: () async {
              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.now(),
              );
              if (time != null) {
                final h = time.hour.toString().padLeft(2, '0');
                final m = time.minute.toString().padLeft(2, '0');
                _timeController.text = '$h:$m';
              }
            },
          ),
          const SizedBox(height: 24),
          _LocationCard(
            loading: _loadingLocation,
            error: _locationError,
            located: _position != null,
            onRetry: _fetchLocation,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: (_isBooking || _loadingLocation || _position == null) ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade800,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isBooking
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(loc.quickBookingButton, style: const TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  final bool loading;
  final String? error;
  final bool located;
  final VoidCallback onRetry;

  const _LocationCard({
    required this.loading,
    required this.error,
    required this.located,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    if (loading) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 16),
              Text(loc.quickLocationDetecting),
            ],
          ),
        ),
      );
    }

    if (error != null) {
      return Card(
        color: Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_off, color: Colors.red),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(error!, style: const TextStyle(color: Colors.red)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text(loc.quickLocationRetry),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Geolocator.openAppSettings(),
                      icon: const Icon(Icons.settings, size: 18),
                      label: Text(loc.quickLocationSettings),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (located) {
      return Card(
        color: Colors.green.shade50,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              const Icon(Icons.location_on, color: Colors.green, size: 28),
              const SizedBox(width: 12),
              Text(
                loc.quickLocationSuccess,
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
