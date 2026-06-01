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

  List<Station> _validStations = [];
  List<Marker> _cachedMarkers = [];
  LatLng? _userLocation;

  bool _locating = false;
  bool _findingNearest = false;
  String? _customerPhone;
  bool _cancellingAll = false;
  bool _showLabels = true;
  Timer? _labelTimer;

  // Zoom tier: 0=large clusters, 1=small clusters, 2=pins, 3=pins+labels.
  int _zoomTier = 1;
  StreamSubscription<MapEvent>? _mapEventSub;

  @override
  void initState() {
    super.initState();
    _stationsFuture = SupabaseService.instance.fetchStations().then((list) {
      if (mounted) {
        final valid =
            list.where((s) => s.latitude != null && s.longitude != null).toList();
        setState(() {
          _validStations = valid;
          _cachedMarkers = _buildMarkers(valid);
        });
      }
      return list;
    });

    _loadCustomerPhone();
    _labelTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _showLabels = false);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapEventSub = _mapController.mapEventStream.listen(_onMapEvent);
      _fetchLocationSilently();
    });
  }

  @override
  void dispose() {
    _mapEventSub?.cancel();
    _labelTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  // ── Location ───────────────────────────────────────────────────────────────

  Future<void> _fetchLocationSilently() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() =>
            _userLocation = LatLng(position.latitude, position.longitude));
      }
    } catch (_) {}
  }

  // ── Button-related methods ─────────────────────────────────────────────────

  Future<void> _loadCustomerPhone() async {
    final session = await SessionService.instance.loadCustomerSession();
    if (mounted && session != null) {
      setState(() => _customerPhone = session.customerPhone);
    }
  }

  void _showSnackBar(String message, {SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message), action: action));
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
        _showSnackBar(loc.quickLocationDeniedForever,
            action: SnackBarAction(
                label: loc.quickLocationSettings,
                onPressed: Geolocator.openAppSettings));
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
                  child: Text(loc.cancelButton)),
              ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(loc.mapAllowLocation)),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _goToNearestStation() async {
    if (_findingNearest) return;
    final loc = AppLocalizations.of(context)!;
    if (_userLocation == null) {
      await _locateUser();
      if (_userLocation == null) return;
    }
    if (_validStations.isEmpty) return;
    setState(() => _findingNearest = true);
    try {
      Station? nearest;
      double minDist = double.infinity;
      for (final s in _validStations) {
        final dx = s.latitude! - _userLocation!.latitude;
        final dy = s.longitude! - _userLocation!.longitude;
        final dist = dx * dx + dy * dy;
        if (dist < minDist) {
          minDist = dist;
          nearest = s;
        }
      }
      if (nearest != null && mounted) {
        _mapController.move(LatLng(nearest.latitude!, nearest.longitude!), 16);
        _showStationDetails(nearest);
      } else if (mounted) {
        _showSnackBar(loc.nearestStationNotFound);
      }
    } finally {
      if (mounted) setState(() => _findingNearest = false);
    }
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
              child: Text(loc.cancelButton)),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(loc.yesCancelBtn)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _cancellingAll = true);
    try {
      await SupabaseService.instance.cancelAllMapBookings(
          customerPhone: _customerPhone!, language: lang);
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _QuickBookingSheet(initialLocation: _userLocation),
    );
  }

  // ── Zoom tier tracking ─────────────────────────────────────────────────────

  void _onMapEvent(MapEvent event) {
    if (event is! MapEventMove &&
        event is! MapEventScrollWheelZoom &&
        event is! MapEventFlingAnimation) {
      return;
    }
    final newTier = _tierFor(_mapController.camera.zoom);
    if (newTier == _zoomTier) {
      return;
    }
    setState(() {
      _zoomTier = newTier;
      _cachedMarkers = _buildMarkers(_validStations);
    });
  }

  static int _tierFor(double zoom) {
    if (zoom >= 14) return 3; // pins + labels
    if (zoom >= 12) return 2; // pins only
    if (zoom >= 10) return 1; // small clusters
    return 0;                 // large clusters
  }

  // ── Marker building ────────────────────────────────────────────────────────

  List<Marker> _buildMarkers(List<Station> stations) {
    if (stations.isEmpty) return [];

    if (_zoomTier >= 3) {
      return stations.map((s) => _singleMarker(s, showLabel: true)).toList();
    }
    if (_zoomTier >= 2) {
      return stations.map((s) => _singleMarker(s, showLabel: false)).toList();
    }

    final cellSize = _zoomTier == 0 ? 0.4 : 0.15;
    final Map<String, List<Station>> cells = {};
    for (final s in stations) {
      final row = (s.latitude! / cellSize).floor();
      final col = (s.longitude! / cellSize).floor();
      cells.putIfAbsent('$row:$col', () => []).add(s);
    }

    final markers = <Marker>[];
    for (final entry in cells.entries) {
      final group = entry.value;
      if (group.length == 1) {
        markers.add(_singleMarker(group.first, showLabel: false));
      } else {
        final avgLat =
            group.map((s) => s.latitude!).reduce((a, b) => a + b) / group.length;
        final avgLng =
            group.map((s) => s.longitude!).reduce((a, b) => a + b) / group.length;
        markers.add(_clusterMarker(group, LatLng(avgLat, avgLng)));
      }
    }
    return markers;
  }

  Marker _singleMarker(Station station, {required bool showLabel}) {
    return Marker(
      width: showLabel ? 80 : 36,
      height: showLabel ? 62 : 36,
      point: LatLng(station.latitude!, station.longitude!),
      alignment: showLabel ? Alignment.bottomCenter : Alignment.center,
      child: GestureDetector(
        onTap: () => _showStationDetails(station),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_pin,
              color: Color(0xFF1565C0),
              size: 36,
              shadows: [
                Shadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2))
              ],
            ),
            if (showLabel)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1)),
                  ],
                ),
                child: Text(
                  station.name,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Marker _clusterMarker(List<Station> group, LatLng center) {
    final size = group.length > 9 ? 48.0 : 40.0;
    return Marker(
      width: size,
      height: size,
      point: center,
      child: GestureDetector(
        onTap: () {
          final bounds = LatLngBounds.fromPoints(
            group.map((s) => LatLng(s.latitude!, s.longitude!)).toList(),
          );
          _mapController.fitCamera(
            CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(80)),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1565C0),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1565C0).withAlpha(100),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Center(
            child: Text(
              '${group.length}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Station detail sheet ───────────────────────────────────────────────────

  void _showStationDetails(Station station) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final loc = AppLocalizations.of(context)!;

        String? distText;
        if (_userLocation != null && station.latitude != null) {
          final dx = (station.latitude! - _userLocation!.latitude) * 111.0;
          final dy = (station.longitude! - _userLocation!.longitude) * 94.5;
          final km = (dx.abs() + dy.abs()) / 2;
          distText = km < 1
              ? '${(km * 1000).toStringAsFixed(0)} م'
              : '${km.toStringAsFixed(1)}${loc.distanceKmAway}';
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(40),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.local_car_wash_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          station.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (distText != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.near_me_rounded,
                                  color: Colors.white70, size: 13),
                              const SizedBox(width: 4),
                              Text(distText,
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _DetailRow(
                    icon: Icons.location_on_rounded,
                    iconColor: Colors.redAccent,
                    text: station.address,
                  ),
                  if (station.detailedAddress != null) ...[
                    const SizedBox(height: 8),
                    _DetailRow(
                      icon: Icons.map_rounded,
                      iconColor: Colors.blueAccent,
                      text: station.detailedAddress!,
                    ),
                  ],
                  const SizedBox(height: 8),
                  _DetailRow(
                    icon: Icons.my_location_rounded,
                    iconColor: Colors.teal,
                    text:
                        '${station.latitude?.toStringAsFixed(4) ?? '-'}, ${station.longitude?.toStringAsFixed(4) ?? '-'}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: SizedBox(
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1565C0).withAlpha(80),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => BookingScreen(station: station)),
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.calendar_today_rounded,
                            color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          loc.bookAtThisStation,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return BottomNavScaffold(
      currentIndex: 2,
      title: loc.mapTitle,
      body: Stack(
        children: [
          // Map is isolated in its own StatefulWidget so FAB state changes
          // (loading spinners, label visibility) never cause it to rebuild.
          _MapBody(
            markers: _cachedMarkers,
            userLocation: _userLocation,
            mapController: _mapController,
            stationsFuture: _stationsFuture,
            noStationsText: loc.noStationsWithLocation,
            errorPrefix: loc.errorPrefix,
          ),

          // ── FABs — trailing edge (right LTR, left RTL)
          PositionedDirectional(
            bottom: 16,
            end: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _MapActionButton(
                  heroTag: 'fab_cancel_all',
                  label: loc.cancelAllBookingsButton,
                  icon: Icons.cancel,
                  backgroundColor: Colors.red,
                  loading: _cancellingAll,
                  showLabel: _showLabels,
                  onPressed: _cancelAllBookings,
                ),
                const SizedBox(height: 8),
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
                  heroTag: 'fab_nearest',
                  label: loc.nearestStationLabel,
                  icon: Icons.near_me_rounded,
                  backgroundColor: const Color(0xFF00897B),
                  loading: _findingNearest,
                  showLabel: _showLabels,
                  onPressed: _goToNearestStation,
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Map body — isolated StatefulWidget ──────────────────────────────────────
// Rebuilds ONLY when markers or userLocation change, not on FAB state changes.

class _MapBody extends StatefulWidget {
  final List<Marker> markers;
  final LatLng? userLocation;
  final MapController mapController;
  final Future<List<Station>> stationsFuture;
  final String noStationsText;
  final String errorPrefix;

  const _MapBody({
    required this.markers,
    required this.userLocation,
    required this.mapController,
    required this.stationsFuture,
    required this.noStationsText,
    required this.errorPrefix,
  });

  @override
  State<_MapBody> createState() => _MapBodyState();
}

class _MapBodyState extends State<_MapBody> {
  late List<Marker> _markers;
  LatLng? _userLocation;

  @override
  void initState() {
    super.initState();
    _markers = widget.markers;
    _userLocation = widget.userLocation;
  }

  @override
  void didUpdateWidget(_MapBody old) {
    super.didUpdateWidget(old);
    // Only trigger a rebuild when the data that the map actually cares about changes.
    if (!identical(widget.markers, old.markers) ||
        widget.userLocation != old.userLocation) {
      setState(() {
        _markers = widget.markers;
        _userLocation = widget.userLocation;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Station>>(
      future: widget.stationsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
              child: Text('${widget.errorPrefix}${snapshot.error}'));
        }

        final validStations = (snapshot.data ?? [])
            .where((s) => s.latitude != null && s.longitude != null)
            .toList();

        if (validStations.isEmpty) {
          return Center(child: Text(widget.noStationsText));
        }

        final bounds = LatLngBounds.fromPoints(
          validStations.map((s) => LatLng(s.latitude!, s.longitude!)).toList(),
        );

        return FlutterMap(
          mapController: widget.mapController,
          options: MapOptions(
            initialCenter: LatLng(
                validStations.first.latitude!, validStations.first.longitude!),
            initialZoom: 10,
            initialCameraFit: CameraFit.bounds(
              bounds: bounds,
              padding: const EdgeInsets.all(80),
            ),
            maxZoom: 18,
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c'],
              userAgentPackageName: 'com.example.washlly_mobile_app',
            ),
            MarkerLayer(markers: _markers),
            if (_userLocation != null)
              MarkerLayer(
                markers: [
                  Marker(
                    width: 28,
                    height: 28,
                    point: _userLocation!,
                    child: Icon(
                      Icons.location_pin,
                      color: Colors.red, 
                      size: 36
                    )
                  ),
                ],
              ),
          ],
        );
      },
    );
  }
}

// ─── Station detail row ───────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;

  const _DetailRow({
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withAlpha(20),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
          ),
        ),
      ],
    );
  }
}

// ─── Map Action Button ────────────────────────────────────────────────────────

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
        child: Text(label,
            style: const TextStyle(color: Colors.white, fontSize: 12)),
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

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: isRtl
          ? [labelWidget, const SizedBox(width: 8), fabWidget]
          : [fabWidget, const SizedBox(width: 8), labelWidget],
    );
  }
}

// ─── Quick Booking Sheet ──────────────────────────────────────────────────────

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
    setState(() { _loadingLocation = true; _locationError = null; });
    final loc = AppLocalizations.of(context)!;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) { setState(() => _locationError = loc.quickLocationDisabled); return; }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(loc.mapLocationPermissionTitle),
            content: Text(loc.mapLocationPermissionMessage),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(loc.cancelButton)),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(loc.mapAllowLocation)),
            ],
          ),
        ) ?? false;
        if (!confirmed) return;
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) { setState(() => _locationError = loc.quickLocationDeniedForever); return; }
      if (permission == LocationPermission.denied) { setState(() => _locationError = loc.quickLocationDenied); return; }
      final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      if (mounted) setState(() => _location = LatLng(position.latitude, position.longitude));
    } catch (_) {
      if (mounted) setState(() => _locationError = AppLocalizations.of(context)!.quickLocationFailed);
    } finally {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  String get _formattedDate => DateFormat('yyyy-MM-dd').format(_selectedDate);
  String get _formattedTime =>
      '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';

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
    setState(() { _loading = true; _resultMessage = null; });
    try {
      final booking = await SupabaseService.instance.createQuickBooking(
        customerName: _nameController.text.trim(),
        customerPhone: _phoneController.text.trim(),
        bookingDate: _formattedDate,
        bookingTime: _formattedTime,
        serviceKind: _selectedServiceName!,
        customerLat: _location!.latitude,
        customerLng: _location!.longitude,
      );
      final targets = (booking['targets'] as List?) ?? [];
      if (mounted) {
        setState(() {
          _success = true;
          _resultMessage = '${loc.quickBookingSentPrefix}${targets.length}${loc.quickBookingSentSuffix}';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _resultMessage = '${loc.quickBookingFailedPrefix}$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48, height: 6,
                decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(3)),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              const Icon(Icons.flash_on, color: AppColors.warning),
              const SizedBox(width: AppSpacing.sm),
              Text(loc.quickBookingTitle, style: AppTextStyles.titleLarge),
            ]),
            const SizedBox(height: 16),

            if (_success) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                    color: AppColors.successSurface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                child: Row(children: [
                  const Icon(Icons.check_circle, color: AppColors.success),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(_resultMessage ?? '',
                      style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.success, fontWeight: FontWeight.bold))),
                ]),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Icon(Icons.close)),
                ),
              ),
            ] else ...[
              Form(
                key: _formKey,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(labelText: loc.fullNameLabel),
                    validator: (v) => v?.trim().isEmpty == true ? loc.fullNameRequired : null,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(labelText: loc.phoneLabel),
                    validator: (v) => v?.trim().isEmpty == true ? loc.phoneRequired : null,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(children: [
                    Expanded(child: OutlinedButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 90)),
                          );
                          if (picked != null) setState(() => _selectedDate = picked);
                        },
                        child: Text('${loc.dateLabelPrefix}$_formattedDate'))),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: OutlinedButton(
                        onPressed: () async {
                          final picked = await showTimePicker(context: context, initialTime: _selectedTime);
                          if (picked != null) setState(() => _selectedTime = picked);
                        },
                        child: Text('${loc.timeLabelPrefix}${_selectedTime.format(context)}'))),
                  ]),
                  const SizedBox(height: AppSpacing.sm),
                  if (_serviceNames.isEmpty)
                    const Center(child: CircularProgressIndicator())
                  else
                    DropdownButtonFormField<String>(
                      value: _selectedServiceName,
                      decoration: InputDecoration(labelText: loc.chooseServiceLabel),
                      items: _serviceNames
                          .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedServiceName = v),
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  // Location status
                  if (_loadingLocation)
                    Row(children: [
                      const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: AppSpacing.sm),
                      Text(loc.quickLocationDetecting, style: AppTextStyles.bodySmall),
                    ])
                  else if (_location != null)
                    Row(children: [
                      const Icon(Icons.location_on, color: AppColors.success, size: 18),
                      const SizedBox(width: AppSpacing.xs),
                      Text(loc.quickLocationSuccess,
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.success)),
                    ])
                  else if (_locationError != null)
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.location_off, color: AppColors.error, size: 18),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(child: Text(_locationError!,
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.error))),
                      ]),
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(spacing: AppSpacing.sm, children: [
                        OutlinedButton.icon(
                            onPressed: _fetchLocation,
                            icon: const Icon(Icons.refresh, size: 14),
                            label: Text(loc.quickLocationRetry),
                            style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact)),
                        OutlinedButton.icon(
                            onPressed: Geolocator.openAppSettings,
                            icon: const Icon(Icons.settings, size: 14),
                            label: Text(loc.quickLocationSettings),
                            style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact)),
                      ]),
                    ])
                  else
                    Row(children: [
                      const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: AppSpacing.sm),
                      Text(loc.quickLocationDetecting, style: AppTextStyles.bodySmall),
                    ]),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Text(_loading ? loc.quickSendingText : loc.quickBookingButton),
                      ),
                    ),
                  ),
                  if (_resultMessage != null && !_success) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(_resultMessage!,
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error)),
                  ],
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
