import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/creator.dart';
import '../models/post.dart';
import '../services/auth_service.dart';
import '../services/creators_service.dart';
import '../widgets/post_card.dart';

class CreatorProfilePage extends StatefulWidget {
  const CreatorProfilePage({super.key, required this.username});
  final String username;

  @override
  State<CreatorProfilePage> createState() => _CreatorProfilePageState();
}

class _CreatorProfilePageState extends State<CreatorProfilePage> {
  CreatorPage? _creator;
  List<Post> _posts = [];
  bool _loading = true;
  bool _loadingMorePosts = false;
  bool _hasMorePosts = true;
  bool _subscribing = false;
  bool _following = false;
  String? _error;
  String? _subscribeError;
  String? _myUsername;
  int _postsOffset = 0;
  static const _postsLimit = 20;

  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMorePosts();
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; _posts = []; _postsOffset = 0; _hasMorePosts = true; });
    try {
      _myUsername = await AuthService.getUsername();
      final creator = await CreatorsService.getCreatorPage(widget.username);
      final posts = await CreatorsService.getPosts(widget.username, limit: _postsLimit, offset: 0);
      if (mounted) {
        setState(() {
          _creator = creator;
          _posts = posts;
          _postsOffset = posts.length;
          _hasMorePosts = posts.length == _postsLimit;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMorePosts() async {
    if (_loadingMorePosts || !_hasMorePosts || _loading) return;
    setState(() => _loadingMorePosts = true);
    try {
      final more = await CreatorsService.getPosts(widget.username, limit: _postsLimit, offset: _postsOffset);
      if (mounted) {
        setState(() {
          _posts.addAll(more);
          _postsOffset += more.length;
          _hasMorePosts = more.length == _postsLimit;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingMorePosts = false);
    }
  }

  Future<void> _toggleSubscribe() async {
    if (_creator == null) return;
    setState(() { _subscribing = true; _subscribeError = null; });
    try {
      if (_creator!.isSubscribed) {
        await _confirmUnsubscribe();
      } else {
        await CreatorsService.subscribe(widget.username);
        await _reload();
      }
    } catch (e) {
      if (mounted) setState(() => _subscribeError = e.toString());
    } finally {
      if (mounted) setState(() => _subscribing = false);
    }
  }

  Future<void> _toggleFollow() async {
    if (_creator == null) return;
    setState(() => _following = true);
    try {
      if (_creator!.isFollowing) {
        await CreatorsService.unfollow(widget.username);
      } else {
        await CreatorsService.follow(widget.username);
      }
      await _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _following = false);
    }
  }

  Future<void> _confirmUnsubscribe() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L10n.t('unsubscribe_confirm')),
        content: Text('You will lose access to paid posts from ${_creator!.profile.displayName}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(L10n.t('cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(L10n.t('unsubscribe'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await CreatorsService.unsubscribe(widget.username);
      await _reload();
    }
  }

  Future<void> _reload() async {
    final creator = await CreatorsService.getCreatorPage(widget.username);
    if (mounted) setState(() => _creator = creator);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text('@${widget.username}')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _creator == null) {
      return Scaffold(
        appBar: AppBar(title: Text('@${widget.username}')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(_error ?? 'Creator not found'),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: Text(L10n.t('retry'))),
            ],
          ),
        ),
      );
    }

    final creator = _creator!;
    final profile = creator.profile;
    final isOwnProfile = _myUsername == creator.user.username;

    return Scaffold(
      appBar: AppBar(title: Text('@${creator.user.username}'), centerTitle: false),
      body: ListView.builder(
        controller: _scrollController,
        itemCount: _posts.length + 2 + (_loadingMorePosts ? 1 : 0),
        itemBuilder: (context, i) {
          // Header slot
          if (i == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cover
                Container(
                  height: 120,
                  color: colorScheme.primaryContainer,
                  child: profile.coverUrl != null
                      ? Image.network(profile.coverUrl!, fit: BoxFit.cover, width: double.infinity)
                      : null,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: Transform.translate(
                    offset: const Offset(0, -28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: colorScheme.primary,
                          backgroundImage: creator.user.avatarUrl != null
                              ? NetworkImage(creator.user.avatarUrl!)
                              : null,
                          child: creator.user.avatarUrl == null
                              ? Text(
                                  profile.displayName[0].toUpperCase(),
                                  style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onPrimary),
                                )
                              : null,
                        ),
                        const SizedBox(height: 8),
                        Text(profile.displayName,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        Text('@${creator.user.username}',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: colorScheme.outline)),
                        if (profile.category != null) ...[
                          const SizedBox(height: 6),
                          Chip(
                            label: Text(profile.category!, style: const TextStyle(fontSize: 12)),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                        if (profile.description != null) ...[
                          const SizedBox(height: 8),
                          Text(profile.description!,
                              style: Theme.of(context).textTheme.bodyMedium),
                        ],
                        const SizedBox(height: 12),
                        if (!isOwnProfile) ...[
                          if (_subscribeError != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(_subscribeError!,
                                  style: const TextStyle(color: Colors.red, fontSize: 13)),
                            ),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton(
                                  onPressed: _subscribing ? null : _toggleSubscribe,
                                  style: creator.isSubscribed
                                      ? FilledButton.styleFrom(
                                          backgroundColor: colorScheme.surfaceContainerHighest,
                                          foregroundColor: colorScheme.onSurface,
                                        )
                                      : null,
                                  child: _subscribing
                                      ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : Text(
                                          creator.isSubscribed
                                              ? L10n.t('subscribed')
                                              : profile.isFree
                                                  ? L10n.t('subscribe_free')
                                                  : '${L10n.t('subscribe')} · ${profile.priceLabel}',
                                        ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: _following ? null : _toggleFollow,
                                child: _following
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                    : Text(creator.isFollowing
                                        ? L10n.t('following')
                                        : L10n.t('follow')),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          // "Posts" section header
          if (i == 1) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('Posts',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
            );
          }

          // Loading more indicator
          if (i == _posts.length + 2) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          // Post items (offset by 2 for header slots)
          final postIndex = i - 2;
          if (_posts.isEmpty && postIndex == 0) {
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 32),
              child: Center(child: Text('No posts yet.')),
            );
          }
          if (postIndex >= _posts.length) return const SizedBox.shrink();
          return PostCard(post: _posts[postIndex]);
        },
      ),
    );
  }
}
