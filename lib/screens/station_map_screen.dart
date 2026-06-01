import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../models/station.dart';
import '../services/supabase_service.dart';
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

  @override
  void initState() {
    super.initState();
    _stationsFuture = SupabaseService.instance.fetchStations();
  }

  @override
  void dispose() {
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
      floatingActionButton: FloatingActionButton(
        onPressed: _locateUser,
        tooltip: loc.mapMyLocation,
        child: _locating
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.my_location),
      ),
      body: FutureBuilder<List<Station>>(
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
    );
  }
}
