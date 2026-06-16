import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';

@pragma('vm:entry-point')
Future<void> _backgroundMessageHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  // Expose this to MaterialApp so we can navigate from outside the widget tree.
  static final navigatorKey = GlobalKey<NavigatorState>();

  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  static const _channelId = 'washlly_channel';
  static const _channelName = 'Washlly Notifications';

  // Kept in memory so token-refresh and tap-navigation know the current user.
  String? _linkedPhone;
  String? _linkedRole;

  Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(_backgroundMessageHandler);

    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    // iOS: show notification banner even when app is in foreground
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Android: create a high-importance channel (required for Android 8+)
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    // Android foreground: FCM does not show a banner automatically — do it manually.
    FirebaseMessaging.onMessage.listen((message) {
      if (!Platform.isAndroid) return;
      final notification = message.notification;
      if (notification == null) return;
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    });

    // Background tap: app was in background, user tapped the notification.
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Terminated tap: app was closed, opened via notification tap.
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      // Defer until after the first frame so the navigator is ready.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _handleNotificationTap(initial),
      );
    }

    // Keep the DB token fresh whenever FCM rotates it.
    _messaging.onTokenRefresh.listen(_onTokenRefresh);
  }

  Future<String?> getToken() => _messaging.getToken();

  /// Call after login to link this device's FCM token to the user.
  /// [role] is either 'customer' or 'owner'.
  Future<void> linkToken({required String phone, required String role}) async {
    _linkedPhone = phone;
    _linkedRole = role;
    try {
      final token = await getToken();
      if (token == null) return;
      final prefs = await SharedPreferences.getInstance();
      final language = prefs.getString('app_locale') ?? 'ar';
      await SupabaseService.instance.saveDeviceToken(
        phone: phone,
        role: role,
        token: token,
        platform: Platform.isIOS ? 'ios' : 'android',
        language: language,
      );
    } catch (_) {}
  }

  /// Call on logout to stop this device from receiving notifications.
  Future<void> unlinkToken() async {
    _linkedPhone = null;
    _linkedRole = null;
    try {
      final token = await getToken();
      if (token == null) return;
      await SupabaseService.instance.deleteDeviceToken(token);
    } catch (_) {}
  }

  // ── Private helpers ──────────────────────────────────────────────

  Future<void> _onTokenRefresh(String newToken) async {
    if (_linkedPhone == null || _linkedRole == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final language = prefs.getString('app_locale') ?? 'ar';
      await SupabaseService.instance.saveDeviceToken(
        phone: _linkedPhone!,
        role: _linkedRole!,
        token: newToken,
        platform: Platform.isIOS ? 'ios' : 'android',
        language: language,
      );
    } catch (_) {}
  }

  void _handleNotificationTap(RemoteMessage message) {
    final role = _linkedRole;
    if (role == null) return;
    if (role == 'customer') {
      navigatorKey.currentState?.pushNamed('/inbox');
    } else if (role == 'owner') {
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/owner-shell',
        (_) => false,
      );
    }
  }
}
