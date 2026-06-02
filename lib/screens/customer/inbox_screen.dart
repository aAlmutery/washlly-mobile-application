import 'package:flutter/material.dart';
import '../../models/customer_notification.dart';
import '../../services/session_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/bottom_nav_scaffold.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class InboxScreen extends StatefulWidget {
  static const routeName = '/inbox';

  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  late Future<void> _loadFuture;
  String customerPhone = '';
  String sessionToken = '';
  bool _markingAll = false;
  List<CustomerNotification> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadFuture = _initAndLoad();
  }

  Future<void> _initAndLoad() async {
    final session = await SessionService.instance.loadCustomerSession();
    if (session == null) return;
    customerPhone = session.customerPhone;
    sessionToken = session.sessionToken;
    final data = await SupabaseService.instance.customerGetInbox(
      customerPhone: customerPhone,
      sessionToken: sessionToken,
    );
    if (mounted) {
      setState(() {
        _notifications = (data['notifications'] as List? ?? [])
            .map((n) => CustomerNotification.fromJson(n as Map<String, dynamic>))
            .toList();
      });
    }
  }

  Future<void> _markAllRead() async {
    if (_markingAll || customerPhone.isEmpty) return;
    setState(() {
      _markingAll = true;
      _notifications = _notifications
          .map((n) => CustomerNotification(
                id: n.id,
                title: n.title,
                body: n.body,
                referenceBookingId: n.referenceBookingId,
                isRead: true,
                createdAt: n.createdAt,
              ))
          .toList();
    });
    try {
      await SupabaseService.instance.customerMarkNotificationRead(
        customerPhone: customerPhone,
        sessionToken: sessionToken,
        markAll: true,
      );
    } catch (_) {
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  void _markNotificationRead(String notificationId) {
    setState(() {
      _notifications = _notifications
          .map((n) => n.id == notificationId
              ? CustomerNotification(
                  id: n.id,
                  title: n.title,
                  body: n.body,
                  referenceBookingId: n.referenceBookingId,
                  isRead: true,
                  createdAt: n.createdAt,
                )
              : n)
          .toList();
    });
    SupabaseService.instance.customerMarkNotificationRead(
      customerPhone: customerPhone,
      sessionToken: sessionToken,
      notificationId: notificationId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return BottomNavScaffold(
      currentIndex: 2,
      title: loc.notificationsLabel,
      notificationPhone: customerPhone.isNotEmpty ? customerPhone : null,
      body: FutureBuilder<void>(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              _notifications.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError && _notifications.isEmpty) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (_notifications.isEmpty) {
            return Center(
              child: Text(loc.noNotifications, style: AppTextStyles.bodyMedium),
            );
          }

          return Column(
            children: [
              if (_notifications.any((n) => !n.isRead))
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: _markingAll ? null : _markAllRead,
                        icon: _markingAll
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.done_all_rounded, size: 16),
                        label: Text(
                          loc.markAllRead,
                          style: const TextStyle(fontSize: 13),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final notif = _notifications[index];
                    return GestureDetector(
                      onTap: () {
                        if (!notif.isRead) {
                          _markNotificationRead(notif.id);
                        }
                      },
                      child: Card(
                        color: notif.isRead
                            ? null
                            : Theme.of(context).brightness == Brightness.dark
                                ? AppColors.success.withAlpha(30)
                                : AppColors.successSurface,
                        child: ListTile(
                          title: Text(
                            notif.title,
                            style: AppTextStyles.bodyMedium
                                .copyWith(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(notif.body,
                              style: AppTextStyles.bodySmall),
                          trailing: !notif.isRead
                              ? const Icon(Icons.circle,
                                  color: AppColors.success, size: 12)
                              : null,
                          contentPadding:
                              const EdgeInsets.all(AppSpacing.md),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
