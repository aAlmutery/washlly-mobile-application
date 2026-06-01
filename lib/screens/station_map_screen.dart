import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../models/station.dart';
import '../services/session_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/bottom_nav_scaffold.dart';
import 'customer/booking_screen.dart';

class StationMapScreen extends StatefulWidget {
  static const routeName = '/map';

  const StationMapScreen({super.key});

  @override
  State<StationMapScreen> createState() => _StationMapScreenState();
}

class _StationMapScreenState extends State<StationMapScreen> {
  late final Future<List<Station>> _stationsFuture;
  final _mapController = MapController();
  LatLng? _userLocation;
  bool _locating = false;
  String? _customerPhone;
  bool _cancellingAll = false;
  bool _showLabels = true;
  Timer? _labelTimer;

  @override
  void initState() {
    super.initState();
    _stationsFuture = SupabaseService.instance.fetchStations();
    _loadCustomerPhone();
    _labelTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _showLabels = false);
    });
  }

  Future<void> _loadCustomerPhone() async {
    final session = await SessionService.instance.loadCustomerSession();
    if (mounted && session != null) {
      setState(() => _customerPhone = session.customerPhone);
    }
  }

  @override
  void dispose() {
    _labelTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _locateUser() async {
    if (_locating) return;
    setState(() => _locating = true);

    final loc = AppLocalizations.of(context)!;

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackBar(loc.quickLocationDisabled);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        final confirmed = await _showPermissionDialog();
        if (!confirmed) return;
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnackBar(
          loc.quickLocationDeniedForever,
          action: SnackBarAction(
            label: loc.quickLocationSettings,
            onPressed: Geolocator.openAppSettings,
          ),
        );
        return;
      }

      if (permission == LocationPermission.denied) {
        _showSnackBar(loc.quickLocationDenied);
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      final point = LatLng(position.latitude, position.longitude);
      setState(() => _userLocation = point);
      _mapController.move(point, 14);
    } catch (_) {
      _showSnackBar(loc.quickLocationFailed);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<bool> _showPermissionDialog() async {
    final loc = AppLocalizations.of(context)!;
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(loc.mapLocationPermissionTitle),
            content: Text(loc.mapLocationPermissionMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(loc.cancelButton),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(loc.mapAllowLocation),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showSnackBar(String message, {SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), action: action),
    );
  }

  Future<void> _cancelAllBookings() async {
    final loc = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;

    if (_customerPhone == null) {
      _showSnackBar(loc.cancelAllBookingsNoPhone);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.cancelAllBookingsConfirmTitle),
        content: Text(loc.cancelAllBookingsConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(loc.cancelButton),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(loc.yesCancelBtn),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _cancellingAll = true);
    try {
      await SupabaseService.instance.cancelAllMapBookings(
        customerPhone: _customerPhone!,
        language: lang,
      );
      if (mounted) _showSnackBar(loc.cancelAllBookingsSuccess);
    } catch (e) {
      if (mounted) _showSnackBar('${loc.cancelAllBookingsFailed}$e');
    } finally {
      if (mounted) setState(() => _cancellingAll = false);
    }
  }

  void _showQuickBookingSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _QuickBookingSheet(initialLocation: _userLocation),
    );
  }

  void _showStationDetails(Station station) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                station.name,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(station.address, style: const TextStyle(fontSize: 16)),
              if (station.detailedAddress != null) ...[
                const SizedBox(height: 6),
                Text(station.detailedAddress!, style: const TextStyle(fontSize: 14, color: Colors.black54)),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.place, color: Colors.blueAccent),
                  const SizedBox(width: 8),
                  Builder(builder: (context) {
                    final loc = AppLocalizations.of(context)!;
                    return Text(
                      '${loc.locationPrefix}${station.latitude?.toStringAsFixed(5) ?? '-'}, ${station.longitude?.toStringAsFixed(5) ?? '-'}',
                      style: const TextStyle(fontSize: 14),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => BookingScreen(station: station)),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Builder(builder: (context) {
                      final loc = AppLocalizations.of(context)!;
                      return Text(loc.bookAtThisStation);
                    }),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return BottomNavScaffold(
      currentIndex: 2,
      title: loc.mapTitle,
      body: Stack(
        children: [
          FutureBuilder<List<Station>>(
        future: _stationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('${AppLocalizations.of(context)!.errorPrefix}${snapshot.error}'));
          }

          final stations = snapshot.data ?? [];
          final validStations = stations
              .where((s) => s.latitude != null && s.longitude != null)
              .toList();

          if (validStations.isEmpty) {
            return Center(child: Text(loc.noStationsWithLocation));
          }

          final stationMarkers = validStations.map((station) {
            return Marker(
              width: 40,
              height: 40,
              point: LatLng(station.latitude!, station.longitude!),
              child: GestureDetector(
                onTap: () => _showStationDetails(station),
                child: const Icon(
                  Icons.location_pin,
                  color: Colors.blueAccent,
                  size: 36,
                ),
              ),
            );
          }).toList();

          final bounds = LatLngBounds.fromPoints(
            validStations.map((s) => LatLng(s.latitude!, s.longitude!)).toList(),
          );

          return FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(validStations.first.latitude!, validStations.first.longitude!),
              initialZoom: 10,
              initialCameraFit: CameraFit.bounds(
                bounds: bounds,
                padding: const EdgeInsets.all(80),
              ),
              maxZoom: 18,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.washlly_mobile_app',
              ),
              MarkerLayer(
                markers: [
                  ...stationMarkers,
                  if (_userLocation != null)
                    Marker(
                      width: 20,
                      height: 20,
                      point: _userLocation!,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
          ),
          // Action buttons — positioned at the trailing edge (right in LTR, left in RTL)
          PositionedDirectional(
            bottom: 16,
            end: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _MapActionButton(
                  heroTag: 'fab_quick_booking',
                  label: loc.quickBookingTitle,
                  icon: Icons.flash_on,
                  backgroundColor: AppColors.warning,
                  showLabel: _showLabels,
                  onPressed: _showQuickBookingSheet,
                ),
                const SizedBox(height: 8),
                _MapActionButton(
                  heroTag: 'fab_my_location',
                  label: loc.mapMyLocation,
                  icon: Icons.my_location,
                  loading: _locating,
                  showLabel: _showLabels,
                  onPressed: _locateUser,
                ),
                const SizedBox(height: 8),
                _MapActionButton(
                  heroTag: 'fab_cancel_all',
                  label: loc.cancelAllBookingsButton,
                  icon: Icons.cancel,
                  backgroundColor: Colors.red,
                  loading: _cancellingAll,
                  showLabel: _showLabels,
                  onPressed: _cancelAllBookings,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Map Action Button (icon + label) ────────────────────────────────────────

class _MapActionButton extends StatelessWidget {
  final String heroTag;
  final String label;
  final IconData icon;
  final Color? backgroundColor;
  final bool loading;
  final bool showLabel;
  final VoidCallback onPressed;

  const _MapActionButton({
    required this.heroTag,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.backgroundColor,
    this.loading = false,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    final isRtl = lang == 'ar' || lang == 'ku';

    final labelWidget = AnimatedOpacity(
      opacity: showLabel ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 400),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
    );

    final fabWidget = FloatingActionButton.small(
      heroTag: heroTag,
      onPressed: onPressed,
      backgroundColor: backgroundColor,
      child: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Icon(icon),
    );

    // In RTL (Arabic/Kurdish): label first, then FAB.
    // In LTR (English): FAB first, then label.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: isRtl
          ? [labelWidget, const SizedBox(width: 8), fabWidget]
          : [fabWidget, const SizedBox(width: 8), labelWidget],
    );
  }
}

// ─── Quick Booking Bottom Sheet ───────────────────────────────────────────────

class _QuickBookingSheet extends StatefulWidget {
  final LatLng? initialLocation;

  const _QuickBookingSheet({this.initialLocation});

  @override
  State<_QuickBookingSheet> createState() => _QuickBookingSheetState();
}

class _QuickBookingSheetState extends State<_QuickBookingSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 12, minute: 0);

  List<String> _serviceNames = [];
  String? _selectedServiceName;

  LatLng? _location;
  bool _loadingLocation = false;
  String? _locationError;

  bool _loading = false;
  String? _resultMessage;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    _location = widget.initialLocation;
    _loadSessionAndServices();
    if (_location == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fetchLocation());
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadSessionAndServices() async {
    final session = await SessionService.instance.loadCustomerSession();
    if (mounted && session != null) {
      _nameController.text = session.customerName;
      _phoneController.text = session.customerPhone;
    }

    try {
      final names = await SupabaseService.instance.fetchServiceNames();
      if (mounted) {
        setState(() {
          _serviceNames = names;
          _selectedServiceName = names.isNotEmpty ? names.first : null;
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchLocation() async {
    if (_loadingLocation) return;
    setState(() {
      _loadingLocation = true;
      _locationError = null;
    });

    final loc = AppLocalizations.of(context)!;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _locationError = loc.quickLocationDisabled);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final confirmed = await _showPermissionDialog();
        if (!confirmed) return;
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _locationError = loc.quickLocationDeniedForever);
        return;
      }

      if (permission == LocationPermission.denied) {
        setState(() => _locationError = loc.quickLocationDenied);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (mounted) setState(() => _location = LatLng(position.latitude, position.longitude));
    } catch (_) {
      if (mounted) setState(() => _locationError = AppLocalizations.of(context)!.quickLocationFailed);
    } finally {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  Future<bool> _showPermissionDialog() async {
    final loc = AppLocalizations.of(context)!;
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(loc.mapLocationPermissionTitle),
            content: Text(loc.mapLocationPermissionMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(loc.cancelButton),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(loc.mapAllowLocation),
              ),
            ],
          ),
        ) ??
        false;
  }

  String get _formattedDate => DateFormat('yyyy-MM-dd').format(_selectedDate);
  String get _formattedTimeIso =>
      '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _selectedTime);
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _submit() async {
    final loc = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    if (_location == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.quickAllowLocation)));
      return;
    }
    if (_selectedServiceName == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.quickFillAllFields)));
      return;
    }

    setState(() {
      _loading = true;
      _resultMessage = null;
    });
    try {
      final booking = await SupabaseService.instance.createQuickBooking(
        customerName: _nameController.text.trim(),
        customerPhone: _phoneController.text.trim(),
        bookingDate: _formattedDate,
        bookingTime: _formattedTimeIso,
        serviceKind: _selectedServiceName!,
        customerLat: _location!.latitude,
        customerLng: _location!.longitude,
      );
      final targets = (booking['targets'] as List?) ?? [];
      if (mounted) {
        setState(() {
          _success = true;
          _resultMessage =
              '${loc.quickBookingSentPrefix}${targets.length}${loc.quickBookingSentSuffix}';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _resultMessage = '${loc.quickBookingFailedPrefix}$error');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildLocationStatus() {
    final loc = AppLocalizations.of(context)!;

    if (_loadingLocation) {
      return Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(loc.quickLocationDetecting, style: AppTextStyles.bodySmall),
        ],
      );
    }

    if (_location != null) {
      return Row(
        children: [
          const Icon(Icons.location_on, color: AppColors.success, size: 18),
          const SizedBox(width: AppSpacing.xs),
          Text(
            loc.quickLocationSuccess,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.success),
          ),
        ],
      );
    }

    if (_locationError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_off, color: AppColors.error, size: 18),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  _locationError!,
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              OutlinedButton.icon(
                onPressed: _fetchLocation,
                icon: const Icon(Icons.refresh, size: 14),
                label: Text(loc.quickLocationRetry),
                style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
              OutlinedButton.icon(
                onPressed: Geolocator.openAppSettings,
                icon: const Icon(Icons.settings, size: 14),
                label: Text(loc.quickLocationSettings),
                style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
            ],
          ),
        ],
      );
    }

    // No location yet — auto-fetch was triggered in initState, show loader placeholder
    return Row(
      children: [
        const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(width: AppSpacing.sm),
        Text(loc.quickLocationDetecting, style: AppTextStyles.bodySmall),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.flash_on, color: AppColors.warning),
                const SizedBox(width: AppSpacing.sm),
                Text(loc.quickBookingTitle, style: AppTextStyles.titleLarge),
              ],
            ),
            const SizedBox(height: 16),

            if (_success) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.successSurface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.success),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _resultMessage ?? '',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Icon(Icons.close),
                  ),
                ),
              ),
            ] else ...[
              Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(labelText: loc.fullNameLabel),
                      validator: (v) =>
                          v?.trim().isEmpty == true ? loc.fullNameRequired : null,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(labelText: loc.phoneLabel),
                      validator: (v) =>
                          v?.trim().isEmpty == true ? loc.phoneRequired : null,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _pickDate,
                            child: Text('${loc.dateLabelPrefix}$_formattedDate'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _pickTime,
                            child: Text(
                                '${loc.timeLabelPrefix}${_selectedTime.format(context)}'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (_serviceNames.isEmpty)
                      const Center(child: CircularProgressIndicator())
                    else
                      DropdownButtonFormField<String>(
                        value: _selectedServiceName,
                        decoration: InputDecoration(labelText: loc.chooseServiceLabel),
                        items: _serviceNames
                            .map((name) =>
                                DropdownMenuItem(value: name, child: Text(name)))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedServiceName = v),
                      ),
                    const SizedBox(height: AppSpacing.sm),
                    _buildLocationStatus(),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Text(
                            _loading ? loc.quickSendingText : loc.quickBookingButton,
                          ),
                        ),
                      ),
                    ),
                    if (_resultMessage != null && !_success) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _resultMessage!,
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
