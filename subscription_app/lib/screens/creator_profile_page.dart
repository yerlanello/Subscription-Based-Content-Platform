import 'package:flutter/material.dart';
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
  List<Post>? _posts;
  bool _loading = true;
  bool _subscribing = false;
  String? _error;
  String? _subscribeError;
  String? _myUsername;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _myUsername = await AuthService.getUsername();
      final creator = await CreatorsService.getCreatorPage(widget.username);
      final posts = await CreatorsService.getPosts(widget.username);
      if (mounted) {
        setState(() {
          _creator = creator;
          _posts = posts;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
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

  Future<void> _confirmUnsubscribe() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsubscribe?'),
        content: Text(
            'You will lose access to paid posts from ${_creator!.profile.displayName}.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  const Text('Unsubscribe', style: TextStyle(color: Colors.red))),
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
    final posts = await CreatorsService.getPosts(widget.username);
    if (mounted) {
      setState(() {
        _creator = creator;
        _posts = posts;
      });
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
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final creator = _creator!;
    final profile = creator.profile;
    final isOwnProfile = _myUsername == creator.user.username;

    return Scaffold(
      appBar: AppBar(
        title: Text('@${creator.user.username}'),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            // Cover banner
            Container(
              height: 120,
              color: colorScheme.primaryContainer,
              child: profile.coverUrl != null
                  ? Image.network(profile.coverUrl!, fit: BoxFit.cover,
                      width: double.infinity)
                  : null,
            ),

            // Avatar + name header
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
                                color: colorScheme.onPrimary,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      profile.displayName,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '@${creator.user.username}',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: colorScheme.outline),
                    ),
                    if (profile.category != null) ...[
                      const SizedBox(height: 6),
                      Chip(
                        label: Text(profile.category!,
                            style: const TextStyle(fontSize: 12)),
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

                    // Subscribe section
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
                                  : Text(
                                      creator.isSubscribed
                                          ? 'Subscribed ✓'
                                          : profile.isFree
                                              ? 'Subscribe (Free)'
                                              : 'Subscribe · ${profile.priceLabel}',
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Posts
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Posts',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),

            if (_posts == null || _posts!.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 32),
                child: Center(child: Text('No posts yet.')),
              )
            else
              ..._posts!.map((p) => PostCard(post: p)),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
