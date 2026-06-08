import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/notification.dart';
import '../services/notifications_service.dart';
import '../services/posts_service.dart';
import 'creator_profile_page.dart';
import 'post_detail_page.dart';
import 'stream_view_page.dart';

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
    // Reload when a new notification arrives over SSE while this page is open.
    NotificationsService.revision.addListener(_onRevision);
  }

  @override
  void dispose() {
    NotificationsService.revision.removeListener(_onRevision);
    super.dispose();
  }

  void _onRevision() {
    if (mounted) _load();
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

  Future<void> _delete(AppNotification n) async {
    try {
      await NotificationsService.delete(n.id);
      if (mounted) setState(() => _notifications?.remove(n));
    } catch (_) {}
  }

  Future<void> _onTap(AppNotification n) async {
    if (!n.isRead) {
      NotificationsService.markRead(n.id).catchError((_) {});
    }
    await _openLink(n.link);
    if (mounted) _load(); // reflect read state / pick up anything new
  }

  // Maps a backend link (/streams/{id}, /posts/{id}, /{username}) to a screen.
  Future<void> _openLink(String? link) async {
    if (link == null || link.isEmpty) return;
    final segs = Uri.tryParse(link)?.pathSegments ?? const [];
    if (segs.isEmpty) return;

    final navigator = Navigator.of(context); // capture before any await

    Widget? page;
    if (segs[0] == 'streams' && segs.length >= 2) {
      page = StreamViewPage(streamId: segs[1]);
    } else if (segs[0] == 'posts' && segs.length >= 2) {
      try {
        final post = await PostsService.getById(segs[1]);
        page = PostDetailPage(post: post);
      } catch (_) {
        return; // post gone — silently ignore
      }
    } else if (segs.length == 1) {
      page = CreatorProfilePage(username: segs[0]);
    }

    if (page != null) {
      await navigator.push(MaterialPageRoute(builder: (_) => page!));
    }
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'new_comment':
        return Icons.mode_comment_outlined;
      case 'new_subscriber':
        return Icons.person_add_alt_1_outlined;
      case 'new_follower':
        return Icons.favorite_outline;
      case 'donation':
        return Icons.volunteer_activism_outlined;
      case 'stream_live':
        return Icons.sensors;
      default:
        return Icons.notifications_outlined;
    }
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
              final hasBody = n.body != null && n.body!.isNotEmpty;
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
                  onTap: () => _onTap(n),
                  leading: Icon(
                    _iconFor(n.type),
                    color: n.isRead ? colorScheme.outline : colorScheme.primary,
                  ),
                  title: Text(
                    n.title,
                    style: TextStyle(
                      fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  subtitle: hasBody ? Text(n.body!) : null,
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
