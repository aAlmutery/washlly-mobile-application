import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/owner_session.dart';

class OwnerSessionService {
  OwnerSessionService._();
  static final OwnerSessionService instance = OwnerSessionService._();

  static const _keyStationId = 'owner_station_id';
  static const _keyPhone = 'owner_phone';
  static const _keyToken = 'owner_session_token';
  static const _keyStationName = 'owner_station_name';

  static const _secureStorage = FlutterSecureStorage();

  Future<void> saveOwnerSession(OwnerSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyStationId, session.stationId);
    await prefs.setString(_keyPhone, session.ownerPhone);
    await prefs.setString(_keyStationName, session.stationName);
    await _secureStorage.write(key: _keyToken, value: session.sessionToken);
  }

  Future<OwnerSession?> loadOwnerSession() async {
    final prefs = await SharedPreferences.getInstance();
    final stationId = prefs.getString(_keyStationId);
    final phone = prefs.getString(_keyPhone);
    final stationName = prefs.getString(_keyStationName);
    final token = await _secureStorage.read(key: _keyToken);
    if (stationId == null || phone == null || token == null || stationName == null) {
      return null;
    }
    return OwnerSession(
      stationId: stationId,
      ownerPhone: phone,
      sessionToken: token,
      stationName: stationName,
    );
  }

  Future<void> clearOwnerSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyStationId);
    await prefs.remove(_keyPhone);
    await prefs.remove(_keyStationName);
    await _secureStorage.delete(key: _keyToken);
  }
}
