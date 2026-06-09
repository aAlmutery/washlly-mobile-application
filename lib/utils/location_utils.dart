import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';

/// Returns [LocationAccuracy.high] when the device is on WiFi,
/// [LocationAccuracy.medium] when on mobile data or unknown.
/// Medium avoids Android's "enable WiFi scanning" system dialog.
Future<LocationAccuracy> resolveLocationAccuracy() async {
  final results = await Connectivity().checkConnectivity();
  final onWifi = results.contains(ConnectivityResult.wifi);
  return onWifi ? LocationAccuracy.high : LocationAccuracy.medium;
}
