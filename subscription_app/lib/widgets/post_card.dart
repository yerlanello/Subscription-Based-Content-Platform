import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/post.dart';
import '../screens/creator_profile_page.dart';
import '../screens/post_detail_page.dart';
import '../services/posts_service.dart';

class PostCard extends StatefulWidget {
  const PostCard({super.key, required this.post});
  final Post post;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late bool _liked;
  late int _likesCount;

  @override
  void initState() {
    super.initState();
    _liked = widget.post.isLiked;
    _likesCount = widget.post.likesCount;
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
      // revert on error
      setState(() {
        _liked = wasLiked;
        _likesCount += wasLiked ? 1 : -1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PostDetailPage(
            post: post,
            initialIsLiked: _liked,
            initialLikesCount: _likesCount,
          ),
        )),
        child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Creator row
            if (post.creator != null)
              _CreatorRow(
                creator: post.creator!,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      CreatorProfilePage(username: post.creator!.username),
                )),
              ),

            // Title + badges
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    post.title,
                    style: textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                if (!post.isFree) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_outline,
                            size: 11, color: colorScheme.primary),
                        const SizedBox(width: 3),
                        Text(
                          L10n.t('paid'),
                          style: textTheme.labelSmall
                              ?.copyWith(color: colorScheme.primary),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),

            // Content or lock placeholder
            const SizedBox(height: 6),
            if (post.isLocked)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline,
                        size: 15, color: colorScheme.outline),
                    const SizedBox(width: 8),
                    Text(
                      L10n.t('subscribe_to_read'),
                      style: textTheme.bodySmall
                          ?.copyWith(color: colorScheme.outline),
                    ),
                  ],
                ),
              )
            else if (post.content != null && post.content!.isNotEmpty)
              Text(
                post.content!,
                style: textTheme.bodyMedium,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),

            // Attachment thumbnails (images only)
            if (post.attachments.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: post.attachments.length,
                  separatorBuilder: (context, i) => const SizedBox(width: 6),
                  itemBuilder: (context, i) {
                    final att = post.attachments[i];
                    final isImage = att.mimeType?.startsWith('image/') ?? true;
                    if (isImage) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          att.url,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) => Container(
                            width: 80,
                            height: 80,
                            color: colorScheme.surfaceContainerHighest,
                            child: Icon(Icons.broken_image_outlined,
                                color: colorScheme.outline),
                          ),
                        ),
                      );
                    }
                    return Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.attach_file, color: colorScheme.outline),
                          const SizedBox(height: 4),
                          Text(att.mimeType ?? 'file',
                              style: TextStyle(fontSize: 9, color: colorScheme.outline),
                              textAlign: TextAlign.center),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],

            // Timestamp
            const SizedBox(height: 6),
            Text(
              _formatDate(post.publishedAt ?? post.createdAt),
              style: textTheme.bodySmall?.copyWith(color: colorScheme.outline),
            ),

            // Actions row
            const SizedBox(height: 10),
            Row(
              children: [
                GestureDetector(
                  onTap: _toggleLike,
                  child: Row(
                    children: [
                      Icon(
                        _liked ? Icons.favorite : Icons.favorite_border,
                        size: 18,
                        color: _liked ? Colors.red : colorScheme.outline,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$_likesCount',
                        style: textTheme.bodySmall
                            ?.copyWith(color: colorScheme.outline),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Row(
                  children: [
                    Icon(Icons.chat_bubble_outline,
                        size: 16, color: colorScheme.outline),
                    const SizedBox(width: 4),
                    Text(
                      '${post.commentsCount}',
                      style: textTheme.bodySmall
                          ?.copyWith(color: colorScheme.outline),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 30) return '${diff.inDays}d ago';
      return '${dt.day}.${dt.month}.${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}

class _CreatorRow extends StatelessWidget {
  const _CreatorRow({required this.creator, this.onTap});
  final PostCreator creator;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: colorScheme.primary,
          backgroundImage: creator.avatarUrl != null
              ? NetworkImage(creator.avatarUrl!)
              : null,
          child: creator.avatarUrl == null
              ? Text(
                  creator.username[0].toUpperCase(),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimary),
                )
              : null,
        ),
        const SizedBox(width: 8),
        Text(
          '@${creator.username}',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    ),
    );
  }
}
