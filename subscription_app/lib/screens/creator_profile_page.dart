import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/creator.dart';
import '../models/post.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/creators_service.dart';
import '../services/posts_service.dart';
import '../widgets/post_card.dart';

class CreatorProfilePage extends StatefulWidget {
  const CreatorProfilePage({super.key, required this.username});
  final String username;

  @override
  State<CreatorProfilePage> createState() => _CreatorProfilePageState();
}

class _CreatorProfilePageState extends State<CreatorProfilePage> {
  CreatorPage? _creator;
  User? _basicUser; // fallback when user is not a creator
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
  String _postFilter = 'all'; // 'all', 'free', 'paid'
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
    setState(() {
      _loading = true;
      _error = null;
      _posts = [];
      _postsOffset = 0;
      _hasMorePosts = true;
      _basicUser = null;
    });
    try {
      _myUsername = await AuthService.getUsername();
      final creator = await CreatorsService.getCreatorPage(widget.username);
      final posts = await CreatorsService.getPosts(widget.username,
          limit: _postsLimit, offset: 0);
      if (mounted) {
        setState(() {
          _creator = creator;
          _posts = posts;
          _postsOffset = posts.length;
          _hasMorePosts = posts.length == _postsLimit;
        });
      }
    } catch (e) {
      // Creator profile not found — try basic user lookup
      try {
        final res = await ApiClient.get('/users/${widget.username}');
        final user = User.fromJson(res['data'] as Map<String, dynamic>);
        if (mounted) setState(() => _basicUser = user);
      } catch (_) {
        if (mounted) setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMorePosts() async {
    if (_loadingMorePosts || !_hasMorePosts || _loading) return;
    setState(() => _loadingMorePosts = true);
    try {
      final more = await CreatorsService.getPosts(widget.username,
          limit: _postsLimit, offset: _postsOffset);
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
    setState(() {
      _subscribing = true;
      _subscribeError = null;
    });
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
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
        content: Text(
            'You will lose access to paid posts from ${_creator!.profile.displayName}.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(L10n.t('cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(L10n.t('unsubscribe'),
                style: const TextStyle(color: Colors.red)),
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

  Future<void> _togglePin(Post post) async {
    try {
      if (post.isPinned) {
        await PostsService.unpin(post.id);
      } else {
        await PostsService.pin(post.id);
      }
      // Reload posts to reflect pinned state
      final posts = await CreatorsService.getPosts(widget.username,
          limit: _postsOffset > 0 ? _postsOffset : _postsLimit, offset: 0);
      if (mounted) setState(() => _posts = posts);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  List<Post> get _filteredPosts {
    switch (_postFilter) {
      case 'free':
        return _posts.where((p) => p.isFree).toList();
      case 'paid':
        return _posts.where((p) => !p.isFree).toList();
      default:
        return _posts;
    }
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

    // Non-creator user fallback
    if (_creator == null) {
      return _buildBasicUserProfile(colorScheme);
    }

    final creator = _creator!;
    final profile = creator.profile;
    final isOwnProfile = _myUsername == creator.user.username;
    final displayed = _filteredPosts;

    return Scaffold(
      appBar: AppBar(
          title: Text('@${creator.user.username}'), centerTitle: false),
      body: ListView.builder(
        controller: _scrollController,
        itemCount: displayed.length + 3 + (_loadingMorePosts ? 1 : 0),
        itemBuilder: (context, i) {
          // Header slot
          if (i == 0) return _buildHeader(creator, profile, isOwnProfile, colorScheme);

          // Filter chips
          if (i == 1) return _buildFilterRow(colorScheme);

          // "Posts" section label
          if (i == 2) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text('Posts',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
            );
          }

          // Loading more indicator
          if (i == displayed.length + 3) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final postIndex = i - 3;
          if (displayed.isEmpty && postIndex == 0) {
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 32),
              child: Center(child: Text('No posts yet.')),
            );
          }
          if (postIndex >= displayed.length) return const SizedBox.shrink();

          final post = displayed[postIndex];
          if (isOwnProfile) return _buildOwnPost(post);
          return PostCard(post: post);
        },
      ),
    );
  }

  Widget _buildHeader(CreatorPage creator, dynamic profile, bool isOwnProfile,
      ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cover
        Container(
          height: 120,
          color: colorScheme.primaryContainer,
          child: profile.coverUrl != null
              ? Image.network(profile.coverUrl!,
                  fit: BoxFit.cover, width: double.infinity)
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
                    label: Text(profile.category!,
                        style: const TextStyle(fontSize: 12)),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
                // Bio / description
                if (profile.description != null &&
                    profile.description!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(profile.description!,
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
                const SizedBox(height: 12),
                // Subscriber / follower counts
                Row(
                  children: [
                    _CountChip(
                      count: creator.subscriberCount,
                      label: L10n.t('subscribers'),
                    ),
                    const SizedBox(width: 12),
                    _CountChip(
                      count: creator.followerCount,
                      label: L10n.t('followers'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (!isOwnProfile) ...[
                  if (_subscribeError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(_subscribeError!,
                          style: const TextStyle(
                              color: Colors.red, fontSize: 13)),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: _subscribing ? null : _toggleSubscribe,
                          style: creator.isSubscribed
                              ? FilledButton.styleFrom(
                                  backgroundColor:
                                      colorScheme.surfaceContainerHighest,
                                  foregroundColor: colorScheme.onSurface,
                                )
                              : null,
                          child: _subscribing
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : Text(creator.isSubscribed
                                  ? L10n.t('subscribed')
                                  : profile.isFree
                                      ? L10n.t('subscribe_free')
                                      : '${L10n.t('subscribe')} · ${profile.priceLabel}'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _following ? null : _toggleFollow,
                        child: _following
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
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

  Widget _buildFilterRow(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(
        spacing: 8,
        children: [
          ChoiceChip(
            label: Text(L10n.t('filter_all')),
            selected: _postFilter == 'all',
            onSelected: (_) => setState(() => _postFilter = 'all'),
          ),
          ChoiceChip(
            label: Text(L10n.t('filter_free')),
            selected: _postFilter == 'free',
            onSelected: (_) => setState(() => _postFilter = 'free'),
          ),
          ChoiceChip(
            label: Text(L10n.t('filter_paid')),
            selected: _postFilter == 'paid',
            onSelected: (_) => setState(() => _postFilter = 'paid'),
          ),
        ],
      ),
    );
  }

  Widget _buildOwnPost(Post post) {
    return Stack(
      children: [
        PostCard(post: post),
        if (post.isPinned)
          Positioned(
            top: 14,
            right: 48,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.push_pin,
                      size: 11,
                      color:
                          Theme.of(context).colorScheme.onSecondaryContainer),
                  const SizedBox(width: 3),
                  Text(L10n.t('pinned'),
                      style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer)),
                ],
              ),
            ),
          ),
        Positioned(
          top: 6,
          right: 22,
          child: PopupMenuButton<String>(
            iconSize: 18,
            onSelected: (value) => _togglePin(post),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'pin',
                child: Row(
                  children: [
                    Icon(
                      post.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(post.isPinned
                        ? L10n.t('unpin')
                        : L10n.t('pin')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBasicUserProfile(ColorScheme colorScheme) {
    final user = _basicUser;
    return Scaffold(
      appBar: AppBar(title: Text('@${widget.username}')),
      body: _error != null && user == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text(_error!),
                  const SizedBox(height: 16),
                  FilledButton(
                      onPressed: _load, child: Text(L10n.t('retry'))),
                ],
              ),
            )
          : ListView(
              children: [
                Container(
                  color: colorScheme.primaryContainer,
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: colorScheme.primary,
                        backgroundImage: user?.avatarUrl != null
                            ? NetworkImage(user!.avatarUrl!)
                            : null,
                        child: user?.avatarUrl == null
                            ? Text(
                                (user?.username[0] ?? widget.username[0])
                                    .toUpperCase(),
                                style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onPrimary),
                              )
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '@${user?.username ?? widget.username}',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onPrimaryContainer),
                      ),
                      if (user?.bio != null && user!.bio!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            user.bio!,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                    color: colorScheme.onPrimaryContainer
                                        .withAlpha(200)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      Icon(Icons.person_off_outlined,
                          size: 48, color: colorScheme.outlineVariant),
                      const SizedBox(height: 12),
                      Text(L10n.t('not_a_creator'),
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(L10n.t('not_a_creator_subtitle'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: colorScheme.outline)),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.count, required this.label});
  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$count',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(
                    color: Theme.of(context).colorScheme.outline)),
      ],
    );
  }
}
