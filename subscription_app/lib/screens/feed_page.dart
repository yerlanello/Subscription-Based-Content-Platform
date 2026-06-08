import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/post.dart';
import '../services/app_settings_service.dart';
import '../services/posts_service.dart';
import '../widgets/post_card.dart';
import '../widgets/notification_bell.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  List<Post> _posts = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  int _offset = 0;
  static const _limit = 20;

  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    AppSettingsService.locale.addListener(_onLocaleChange);
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    AppSettingsService.locale.removeListener(_onLocaleChange);
    super.dispose();
  }

  void _onLocaleChange() => setState(() {});

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; _offset = 0; _hasMore = true; _posts = []; });
    try {
      final posts = await PostsService.feed(limit: _limit, offset: 0);
      if (mounted) {
        setState(() {
          _posts = posts;
          _offset = posts.length;
          _hasMore = posts.length == _limit;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading) return;
    setState(() => _loadingMore = true);
    try {
      final more = await PostsService.feed(limit: _limit, offset: _offset);
      if (mounted) {
        setState(() {
          _posts.addAll(more);
          _offset += more.length;
          _hasMore = more.length == _limit;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.t('feed')),
        centerTitle: false,
        actions: [
          const NotificationBell(),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: L10n.t('refresh'),
          ),
        ],
      ),
      body: Builder(builder: (_) {
        if (_loading) return const Center(child: CircularProgressIndicator());

        if (_error != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _load, child: Text(L10n.t('retry'))),
                ],
              ),
            ),
          );
        }

        if (_posts.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.rss_feed, size: 56, color: colorScheme.outlineVariant),
                  const SizedBox(height: 16),
                  Text(L10n.t('feed_empty'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(L10n.t('feed_empty_subtitle'),
                      style: TextStyle(color: colorScheme.outline, fontSize: 13),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _load,
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _posts.length + (_loadingMore ? 1 : 0),
            itemBuilder: (context, i) {
              if (i == _posts.length) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return PostCard(post: _posts[i]);
            },
          ),
        );
      }),
    );
  }
}
