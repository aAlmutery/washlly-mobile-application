import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../services/supabase_service.dart';
import '../screens/customer/inbox_screen.dart';

/// Bell icon with a red unread-count badge.
/// Pass [customerPhone] and [sessionToken] when the customer is logged in;
/// pass null to show a plain bell with no badge.
class NotificationBell extends StatefulWidget {
  final String? customerPhone;
  final String? sessionToken;

  const NotificationBell({
    super.key,
    this.customerPhone,
    this.sessionToken,
  });

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(NotificationBell old) {
    super.didUpdateWidget(old);
    if (old.customerPhone != widget.customerPhone ||
        old.sessionToken != widget.sessionToken) {
      _load();
    }
  }

  Future<void> _load() async {
    final phone = widget.customerPhone;
    final token = widget.sessionToken;
    if (phone == null || phone.isEmpty || token == null || token.isEmpty) return;
    try {
      final count = await SupabaseService.instance.fetchUnreadNotificationCount(
        customerPhone: phone,
        sessionToken: token,
      );
      if (mounted) setState(() => _unread = count);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return IconButton(
      tooltip: loc.notificationsLabel,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_outlined),
          if (_unread > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  _unread > 99 ? '99+' : '$_unread',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      onPressed: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const InboxScreen()),
        );
        _load();
      },
    );
  }
}
