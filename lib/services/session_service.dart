import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/customer_session.dart';

class SessionService {
  SessionService._();
  static final SessionService instance = SessionService._();

  static const _keyPhone = 'customer_phone';
  static const _keyName = 'customer_name';
  static const _keyToken = 'session_token';
  static const _keyExpiry = 'session_expiry';

  static const _secureStorage = FlutterSecureStorage();

  Future<void> saveCustomerSession(CustomerSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPhone, session.customerPhone);
    await prefs.setString(_keyName, session.customerName);
    await prefs.setString(_keyExpiry, session.expiresAt.toIso8601String());
    await _secureStorage.write(key: _keyToken, value: session.sessionToken);
  }

  Future<CustomerSession?> loadCustomerSession() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString(_keyPhone);
    final name = prefs.getString(_keyName);
    final expiry = prefs.getString(_keyExpiry);
    final token = await _secureStorage.read(key: _keyToken);
    if (phone == null || name == null || token == null || expiry == null) {
      return null;
    }
    final session = CustomerSession(
      customerPhone: phone,
      customerName: name,
      sessionToken: token,
      expiresAt: DateTime.parse(expiry),
    );
    if (!session.isValid) {
      await clearCustomerSession();
      return null;
    }
    return session;
  }

  Future<void> clearCustomerSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPhone);
    await prefs.remove(_keyName);
    await prefs.remove(_keyExpiry);
    await _secureStorage.delete(key: _keyToken);
  }
}
