import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/comment.dart';
import '../models/post.dart';
import '../screens/creator_profile_page.dart';
import '../services/auth_service.dart';
import '../services/posts_service.dart';

class PostDetailPage extends StatefulWidget {
  const PostDetailPage({super.key, required this.post});
  final Post post;

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  late bool _liked;
  late int _likesCount;

  List<Comment>? _comments;
  bool _commentsLoading = true;
  String? _commentsError;

  String? _currentUsername;
  final _commentController = TextEditingController();
  bool _submitting = false;

  // When non-null we are replying to this comment.
  Comment? _replyingTo;

  @override
  void initState() {
    super.initState();
    _liked = widget.post.isLiked;
    _likesCount = widget.post.likesCount;
    _loadComments();
    _loadUsername();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadUsername() async {
    final u = await AuthService.getUsername();
    if (mounted) setState(() => _currentUsername = u);
  }

  Future<void> _loadComments() async {
    setState(() {
      _commentsLoading = true;
      _commentsError = null;
    });
    try {
      final comments = await PostsService.getComments(widget.post.id);
      if (mounted) setState(() => _comments = comments);
    } catch (e) {
      if (mounted) setState(() => _commentsError = e.toString());
    } finally {
      if (mounted) setState(() => _commentsLoading = false);
    }
  }

  Future<void> _toggleLike() async {
    final wasLiked = _liked;
    setState(() {
      _liked = !_liked;
      _likesCount += _liked ? 1 : -1;
    });
    try {
      if (wasLiked) {
        await PostsService.unlike(widget.post.id);
      } else {
        await PostsService.like(widget.post.id);
      }
    } catch (_) {
      setState(() {
        _liked = wasLiked;
        _likesCount += wasLiked ? 1 : -1;
      });
    }
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    setState(() => _submitting = true);
    try {
      await PostsService.createComment(
        widget.post.id,
        text,
        parentId: _replyingTo?.id,
      );
      _commentController.clear();
      setState(() => _replyingTo = null);
      await _loadComments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post comment: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _deleteComment(Comment comment) async {
    try {
      await PostsService.deleteComment(widget.post.id, comment.id);
      await _loadComments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: post.creator != null
            ? GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      CreatorProfilePage(username: post.creator!.username),
                )),
                child: Text('@${post.creator!.username}'),
              )
            : const Text('Post'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Title
                Text(
                  post.title,
                  style: textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                // Meta row
                Row(
                  children: [
                    if (post.creator != null) ...[
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CreatorProfilePage(
                                username: post.creator!.username),
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: colorScheme.primary,
                              backgroundImage: post.creator!.avatarUrl != null
                                  ? NetworkImage(post.creator!.avatarUrl!)
                                  : null,
                              child: post.creator!.avatarUrl == null
                                  ? Text(
                                      post.creator!.username[0].toUpperCase(),
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: colorScheme.onPrimary),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '@${post.creator!.username}',
                              style: textTheme.bodySmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Text(
                      _formatDate(post.publishedAt ?? post.createdAt),
                      style: textTheme.bodySmall
                          ?.copyWith(color: colorScheme.outline),
                    ),
                    const Spacer(),
                    if (!post.isFree)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          L10n.t('paid'),
                          style: textTheme.labelSmall
                              ?.copyWith(color: colorScheme.primary),
                        ),
                      ),
                  ],
                ),

                const Divider(height: 24),

                // Content or lock
                if (post.isLocked)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.lock_outline,
                            size: 36, color: colorScheme.outline),
                        const SizedBox(height: 8),
                        Text(
                          L10n.t('subscribe_to_read'),
                          style: textTheme.bodyMedium
                              ?.copyWith(color: colorScheme.outline),
                        ),
                      ],
                    ),
                  )
                else if (post.content != null && post.content!.isNotEmpty)
                  Text(post.content!, style: textTheme.bodyLarge),

                // Attachments
                if (post.attachments.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _AttachmentsSection(attachments: post.attachments),
                ],

                const SizedBox(height: 16),

                // Like / comment counts
                Row(
                  children: [
                    GestureDetector(
                      onTap: _toggleLike,
                      child: Row(
                        children: [
                          Icon(
                            _liked ? Icons.favorite : Icons.favorite_border,
                            size: 20,
                            color: _liked ? Colors.red : colorScheme.outline,
                          ),
                          const SizedBox(width: 4),
                          Text('$_likesCount',
                              style: textTheme.bodySmall
                                  ?.copyWith(color: colorScheme.outline)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.chat_bubble_outline,
                        size: 18, color: colorScheme.outline),
                    const SizedBox(width: 4),
                    Text('${_comments?.length ?? post.commentsCount}',
                        style: textTheme.bodySmall
                            ?.copyWith(color: colorScheme.outline)),
                  ],
                ),

                const Divider(height: 32),

                // Comments section
                Text(L10n.t('comments'),
                    style: textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),

                if (_commentsLoading)
                  const Center(child: CircularProgressIndicator())
                else if (_commentsError != null)
                  Center(
                    child: Column(
                      children: [
                        Text(_commentsError!,
                            style: const TextStyle(color: Colors.red)),
                        TextButton(
                            onPressed: _loadComments,
                            child: const Text('Retry')),
                      ],
                    ),
                  )
                else if (_comments == null || _comments!.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      L10n.t('no_comments'),
                      style:
                          textTheme.bodyMedium?.copyWith(color: colorScheme.outline),
                    ),
                  )
                else
                  ..._comments!
                      .map((c) => _CommentTile(
                            comment: c,
                            currentUsername: _currentUsername,
                            postId: post.id,
                            onReply: (c) =>
                                setState(() => _replyingTo = c),
                            onDelete: _deleteComment,
                            onRefresh: _loadComments,
                          ))
                      ,

                const SizedBox(height: 80),
              ],
            ),
          ),

          // Comment input bar
          _CommentInput(
            controller: _commentController,
            replyingTo: _replyingTo,
            submitting: _submitting,
            onCancelReply: () => setState(() => _replyingTo = null),
            onSubmit: _submitComment,
          ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}.${dt.month}.${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}

// ---------- Attachments ----------

class _AttachmentsSection extends StatelessWidget {
  const _AttachmentsSection({required this.attachments});
  final List<PostAttachment> attachments;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: attachments.map((a) {
        final mime = a.mimeType ?? '';
        if (mime.startsWith('image/')) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                a.url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, _) => Container(
                  height: 120,
                  color: colorScheme.surfaceContainerHighest,
                  child: const Center(child: Icon(Icons.broken_image_outlined)),
                ),
              ),
            ),
          );
        }
        final isVideo = mime.startsWith('video/');
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  isVideo ? Icons.videocam_outlined : Icons.audiotrack_outlined,
                  size: 20,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  isVideo ? 'Video' : 'Audio',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ---------- Comment tile ----------

class _CommentTile extends StatefulWidget {
  const _CommentTile({
    required this.comment,
    required this.currentUsername,
    required this.postId,
    required this.onReply,
    required this.onDelete,
    required this.onRefresh,
  });

  final Comment comment;
  final String? currentUsername;
  final String postId;
  final void Function(Comment) onReply;
  final Future<void> Function(Comment) onDelete;
  final Future<void> Function() onRefresh;

  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile> {
  late bool _liked;
  late int _likesCount;

  @override
  void initState() {
    super.initState();
    _liked = widget.comment.isLiked;
    _likesCount = widget.comment.likesCount;
  }

  Future<void> _toggleLike() async {
    final wasLiked = _liked;
    setState(() {
      _liked = !_liked;
      _likesCount += _liked ? 1 : -1;
    });
    try {
      if (wasLiked) {
        await PostsService.unlikeComment(widget.postId, widget.comment.id);
      } else {
        await PostsService.likeComment(widget.postId, widget.comment.id);
      }
    } catch (_) {
      setState(() {
        _liked = wasLiked;
        _likesCount += wasLiked ? 1 : -1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.comment;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isOwn = c.author?.username == widget.currentUsername;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: c.author != null
                    ? () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => CreatorProfilePage(
                              username: c.author!.username),
                        ))
                    : null,
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: colorScheme.secondaryContainer,
                  backgroundImage: c.author?.avatarUrl != null
                      ? NetworkImage(c.author!.avatarUrl!)
                      : null,
                  child: c.author?.avatarUrl == null
                      ? Text(
                          (c.author?.username[0] ?? '?').toUpperCase(),
                          style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.onSecondaryContainer),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '@${c.author?.username ?? 'unknown'}',
                          style: textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(c.createdAt),
                          style: textTheme.bodySmall
                              ?.copyWith(color: colorScheme.outline),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(c.content, style: textTheme.bodyMedium),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: _toggleLike,
                          child: Row(
                            children: [
                              Icon(
                                _liked
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                size: 14,
                                color: _liked
                                    ? Colors.red
                                    : colorScheme.outline,
                              ),
                              const SizedBox(width: 3),
                              Text('$_likesCount',
                                  style: textTheme.bodySmall?.copyWith(
                                      color: colorScheme.outline)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => widget.onReply(c),
                          child: Text(L10n.t('reply'),
                              style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w500)),
                        ),
                        if (isOwn) ...[
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () => widget.onDelete(c),
                            child: Text(L10n.t('delete'),
                                style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.error)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Nested replies
          if (c.replies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 36, top: 8),
              child: Column(
                children: c.replies
                    .map((r) => _CommentTile(
                          comment: r,
                          currentUsername: widget.currentUsername,
                          postId: widget.postId,
                          onReply: widget.onReply,
                          onDelete: widget.onDelete,
                          onRefresh: widget.onRefresh,
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return iso;
    }
  }
}

// ---------- Comment input ----------

class _CommentInput extends StatelessWidget {
  const _CommentInput({
    required this.controller,
    required this.replyingTo,
    required this.submitting,
    required this.onCancelReply,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final Comment? replyingTo;
  final bool submitting;
  final VoidCallback onCancelReply;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      padding: EdgeInsets.only(
        left: 12,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (replyingTo != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Text(
                    '${L10n.t('replying_to')} @${replyingTo!.author?.username ?? 'unknown'}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: onCancelReply,
                    child: Icon(Icons.close,
                        size: 16, color: colorScheme.outline),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: L10n.t('write_comment'),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                ),
              ),
              submitting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: onSubmit,
                      color: colorScheme.primary,
                    ),
            ],
          ),
        ],
      ),
    );
  }
}
