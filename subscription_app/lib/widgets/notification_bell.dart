import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../screens/notifications_page.dart';
import '../services/notifications_service.dart';

/// AppBar action: a bell with a live unread badge driven by
/// [NotificationsService.unreadCount] (updated via SSE). Opens the
/// notifications list and refreshes the count on return.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  @override
  void initState() {
    super.initState();
    NotificationsService.refreshUnread();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: NotificationsService.unreadCount,
      builder: (context, unread, _) {
        return IconButton(
          icon: Badge(
            isLabelVisible: unread > 0,
            label: Text('$unread'),
            child: const Icon(Icons.notifications_outlined),
          ),
          tooltip: L10n.t('notifications'),
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsPage()),
            );
            NotificationsService.refreshUnread();
          },
        );
      },
    );
  }
}
