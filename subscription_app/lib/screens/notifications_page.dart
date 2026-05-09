import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/notification.dart';
import '../services/notifications_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<AppNotification>? _notifications;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await NotificationsService.list();
      if (mounted) setState(() => _notifications = list);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    try {
      await NotificationsService.markAllRead();
      await _load();
    } catch (_) {}
  }

  Future<void> _markRead(AppNotification n) async {
    if (n.isRead) return;
    try {
      await NotificationsService.markRead(n.id);
      await _load();
    } catch (_) {}
  }

  Future<void> _delete(AppNotification n) async {
    try {
      await NotificationsService.delete(n.id);
      if (mounted) setState(() => _notifications?.remove(n));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasUnread = _notifications?.any((n) => !n.isRead) ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.t('notifications')),
        actions: [
          if (hasUnread)
            TextButton(
              onPressed: _markAllRead,
              child: Text(L10n.t('mark_all_read')),
            ),
        ],
      ),
      body: Builder(builder: (_) {
        if (_loading) return const Center(child: CircularProgressIndicator());

        if (_error != null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text(_error!),
                const SizedBox(height: 16),
                FilledButton(onPressed: _load, child: Text(L10n.t('retry'))),
              ],
            ),
          );
        }

        if (_notifications == null || _notifications!.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.notifications_none, size: 56, color: colorScheme.outlineVariant),
                const SizedBox(height: 16),
                Text(L10n.t('no_notifications'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Text(L10n.t('no_notifications_subtitle'),
                    style: TextStyle(color: colorScheme.outline, fontSize: 13)),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _load,
          child: ListView.separated(
            itemCount: _notifications!.length,
            separatorBuilder: (context, i) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final n = _notifications![i];
              return Dismissible(
                key: Key(n.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: colorScheme.error,
                  child: Icon(Icons.delete_outline, color: colorScheme.onError),
                ),
                onDismissed: (_) => _delete(n),
                child: ListTile(
                  onTap: () => _markRead(n),
                  leading: Icon(
                    Icons.notifications,
                    color: n.isRead ? colorScheme.outline : colorScheme.primary,
                  ),
                  title: Text(
                    n.message,
                    style: TextStyle(
                      fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  trailing: n.isRead
                      ? null
                      : Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colorScheme.primary,
                          ),
                        ),
                ),
              );
            },
          ),
        );
      }),
    );
  }
}
