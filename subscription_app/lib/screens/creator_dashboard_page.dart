import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/creator.dart';
import '../models/post.dart';
import '../services/auth_service.dart';
import '../services/creators_service.dart';
import '../services/posts_service.dart';
import 'creator_settings_page.dart';
import 'edit_post_page.dart';

/// Creator Dashboard — the creator's home: a profile summary card with an
/// "Edit profile" entry, plus the list of the creator's posts with full
/// management actions (pin/unpin, publish/unpublish, edit, delete).
/// Mirrors the web `/dashboard` page.
class CreatorDashboardPage extends StatefulWidget {
  const CreatorDashboardPage({super.key});

  @override
  State<CreatorDashboardPage> createState() => _CreatorDashboardPageState();
}

class _CreatorDashboardPageState extends State<CreatorDashboardPage> {
  CreatorProfile? _profile;
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
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; _offset = 0; _hasMore = true; });
    try {
      final username = await AuthService.getUsername();
      if (username == null) throw 'Not logged in';
      final page = await CreatorsService.getCreatorPage(username);
      final posts = await PostsService.byCreator(username, limit: _limit, offset: 0);
      if (mounted) {
        setState(() {
          _profile = page.profile;
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
      final username = await AuthService.getUsername();
      if (username == null) return;
      final more = await PostsService.byCreator(username, limit: _limit, offset: _offset);
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

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _publish(Post post) async {
    try {
      await PostsService.publish(post.id);
      _snack(L10n.t('post_published'));
      _load();
    } catch (e) {
      _snack('Failed: $e');
    }
  }

  Future<void> _unpublish(Post post) async {
    try {
      await PostsService.unpublish(post.id);
      _snack(L10n.t('draft_saved'));
      _load();
    } catch (e) {
      _snack('Failed: $e');
    }
  }

  Future<void> _togglePin(Post post) async {
    try {
      if (post.isPinned) {
        await PostsService.unpin(post.id);
      } else {
        await PostsService.pin(post.id);
      }
      _load();
    } catch (e) {
      _snack('Failed: $e');
    }
  }

  Future<void> _delete(Post post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L10n.t('delete_post_confirm')),
        content: Text('"${post.title}" — ${L10n.t('delete_cannot_undo')}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(L10n.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(L10n.t('delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await PostsService.delete(post.id);
      _snack(L10n.t('post_deleted'));
      _load();
    } catch (e) {
      _snack('Failed: $e');
    }
  }

  Future<void> _editProfile() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreatorSettingsPage()),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.t('creator_dashboard')),
        actions: [
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

        return RefreshIndicator(
          onRefresh: _load,
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            // 0: profile card, 1: "My posts" header, then either the empty
            // placeholder (1 row) or the posts (+ a trailing loader).
            itemCount: 2 +
                (_posts.isEmpty ? 1 : _posts.length) +
                (_loadingMore ? 1 : 0),
            itemBuilder: (context, i) {
              if (i == 0) return _profileCard(colorScheme);
              if (i == 1) {
                return Padding(
                  padding: const EdgeInsets.only(top: 24, bottom: 8),
                  child: Text(
                    L10n.t('my_posts'),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                );
              }
              final postIndex = i - 2;
              if (_posts.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.article_outlined, size: 48, color: colorScheme.outlineVariant),
                        const SizedBox(height: 12),
                        Text(L10n.t('no_posts_yet'),
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                );
              }
              if (postIndex == _posts.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _postCard(_posts[postIndex], colorScheme),
              );
            },
          ),
        );
      }),
    );
  }

  Widget _profileCard(ColorScheme colorScheme) {
    final profile = _profile;
    final priceLabel = profile == null
        ? ''
        : profile.subscriptionPriceCents == 0
            ? L10n.t('free_subscription')
            : '${profile.subscriptionPriceCents} ₸${L10n.t('per_month')}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              L10n.t('my_profile'),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (profile != null) ...[
              Text(profile.displayName,
                  style: Theme.of(context).textTheme.bodyMedium),
              if (profile.description != null && profile.description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  profile.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: colorScheme.outline),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                priceLabel,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(L10n.t('edit_profile')),
                onPressed: _editProfile,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _postCard(Post post, ColorScheme colorScheme) {
    final isDraft = !post.isPublished;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (post.isPinned) ...[
                  Icon(Icons.push_pin, size: 16, color: colorScheme.primary),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    post.title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                _Badge(
                  label: isDraft ? L10n.t('draft') : L10n.t('published'),
                  color: isDraft
                      ? colorScheme.surfaceContainerHighest
                      : colorScheme.primaryContainer,
                  textColor: isDraft
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.onPrimaryContainer,
                ),
                if (!post.isFree) ...[
                  const SizedBox(width: 6),
                  _Badge(
                    label: L10n.t('paid'),
                    color: colorScheme.secondaryContainer,
                    textColor: colorScheme.onSecondaryContainer,
                  ),
                ],
              ],
            ),
            if (post.content != null && post.content!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                post.content!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ],
            if (!isDraft) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.favorite_outline, size: 16, color: colorScheme.outline),
                  const SizedBox(width: 4),
                  Text('${post.likesCount}',
                      style: TextStyle(fontSize: 13, color: colorScheme.outline)),
                  const SizedBox(width: 12),
                  Icon(Icons.comment_outlined, size: 16, color: colorScheme.outline),
                  const SizedBox(width: 4),
                  Text('${post.commentsCount}',
                      style: TextStyle(fontSize: 13, color: colorScheme.outline)),
                ],
              ),
            ],
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!isDraft)
                  IconButton(
                    icon: Icon(post.isPinned ? Icons.push_pin : Icons.push_pin_outlined, size: 20),
                    color: post.isPinned ? colorScheme.primary : null,
                    tooltip: post.isPinned ? L10n.t('unpin') : L10n.t('pin'),
                    onPressed: () => _togglePin(post),
                  ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  tooltip: L10n.t('edit'),
                  onPressed: () async {
                    final changed = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(builder: (_) => EditPostPage(post: post)),
                    );
                    if (changed == true) _load();
                  },
                ),
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: Text(L10n.t('delete')),
                  style: TextButton.styleFrom(foregroundColor: colorScheme.error),
                  onPressed: () => _delete(post),
                ),
                const SizedBox(width: 8),
                if (isDraft)
                  FilledButton.icon(
                    icon: const Icon(Icons.publish, size: 18),
                    label: Text(L10n.t('publish')),
                    onPressed: () => _publish(post),
                  )
                else
                  OutlinedButton.icon(
                    icon: const Icon(Icons.unpublished_outlined, size: 18),
                    label: Text(L10n.t('unpublish')),
                    onPressed: () => _unpublish(post),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color, required this.textColor});
  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Text(label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor)),
    );
  }
}
