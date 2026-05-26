import 'package:flutter/foundation.dart';
import '../models/customer_session.dart';
import '../services/session_service.dart';

class CustomerSessionNotifier extends ChangeNotifier {
  CustomerSession? _session;
  bool _loaded = false;

  CustomerSession? get session => _session;
  bool get loaded => _loaded;

  CustomerSessionNotifier() {
    _init();
  }

  Future<void> _init() async {
    final s = await SessionService.instance.loadCustomerSession();
    _session = s;
    _loaded = true;
    notifyListeners();
  }

  Future<void> save(CustomerSession session) async {
    await SessionService.instance.saveCustomerSession(session);
    _session = session;
    notifyListeners();
  }

  Future<void> logout() async {
    await SessionService.instance.clearCustomerSession();
    _session = null;
    notifyListeners();
  }
}
