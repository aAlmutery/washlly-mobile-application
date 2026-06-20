import 'package:flutter/foundation.dart';
import '../models/customer_session.dart';
import '../services/notification_service.dart';
import '../services/session_service.dart';

class CustomerSessionNotifier extends ChangeNotifier {
  static CustomerSessionNotifier? _instance;

  /// The single instance created in main(). Accessible to any code that needs
  /// to update the session (e.g. requireCustomerLogin in customer_login_sheet).
  static CustomerSessionNotifier get instance => _instance!;

  CustomerSession? _session;
  bool _loaded = false;

  CustomerSession? get session => _session;
  bool get loaded => _loaded;

  CustomerSessionNotifier() {
    _instance = this;
    _init();
  }

  Future<void> _init() async {
    final s = await SessionService.instance.loadCustomerSession();
    _session = s;
    _loaded = true;
    notifyListeners();
    if (s != null) {
      NotificationService.instance.linkToken(
        phone: s.customerPhone,
        role: 'customer',
      );
    }
  }

  Future<void> save(CustomerSession session) async {
    await SessionService.instance.saveCustomerSession(session);
    _session = session;
    notifyListeners();
    NotificationService.instance.linkToken(
      phone: session.customerPhone,
      role: 'customer',
    );
  }

  Future<void> logout() async {
    await NotificationService.instance.unlinkToken();
    await SessionService.instance.clearCustomerSession();
    _session = null;
    notifyListeners();
  }
}
