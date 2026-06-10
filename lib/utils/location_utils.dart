import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';

/// WiFi  → [LocationAccuracy.high]  (PRIORITY_HIGH_ACCURACY: GPS + WiFi + cell)
/// Other → [LocationAccuracy.low]   (PRIORITY_LOW_POWER: GPS + cell, no WiFi
///          scanning — suppresses the "enable WiFi scanning" system dialog)
Future<LocationAccuracy> resolveLocationAccuracy() async {
  final results = await Connectivity().checkConnectivity();
  final onWifi = results.contains(ConnectivityResult.wifi);
  return onWifi ? LocationAccuracy.high : LocationAccuracy.low;
}
