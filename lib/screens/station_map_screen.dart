import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../models/station.dart';
import '../services/supabase_service.dart';
import '../widgets/bottom_nav_scaffold.dart';
import 'booking_screen.dart';

class StationMapScreen extends StatefulWidget {
  static const routeName = '/map';

  const StationMapScreen({super.key});

  @override
  State<StationMapScreen> createState() => _StationMapScreenState();
}

class _StationMapScreenState extends State<StationMapScreen> {
  late final Future<List<Station>> _stationsFuture;

  @override
  void initState() {
    super.initState();
    _stationsFuture = SupabaseService.instance.fetchStations();
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
              .where((station) => station.latitude != null && station.longitude != null)
              .toList();

          if (validStations.isEmpty) {
            return Center(child: Text(loc.noStationsWithLocation));
          }

          final markers = validStations.map((station) {
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
            validStations.map((station) => LatLng(station.latitude!, station.longitude!)).toList(),
          );

          return FlutterMap(
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
              MarkerLayer(markers: markers),
            ],
          );
        },
      ),
    );
  }
}
