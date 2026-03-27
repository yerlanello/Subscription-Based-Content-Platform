class PostAttachment {
  final String id;
  final String postId;
  final String url;
  final String? mimeType;
  final int? sizeBytes;

  const PostAttachment({
    required this.id,
    required this.postId,
    required this.url,
    this.mimeType,
    this.sizeBytes,
  });

  factory PostAttachment.fromJson(Map<String, dynamic> json) => PostAttachment(
        id: json['id'] as String,
        postId: json['post_id'] as String,
        url: json['url'] as String,
        mimeType: json['mime_type'] as String?,
        sizeBytes: json['size_bytes'] as int?,
      );
}

class PostCreator {
  final String id;
  final String username;
  final String? avatarUrl;

  const PostCreator({
    required this.id,
    required this.username,
    this.avatarUrl,
  });

  factory PostCreator.fromJson(Map<String, dynamic> json) => PostCreator(
        id: json['id'] as String,
        username: json['username'] as String,
        avatarUrl: json['avatar_url'] as String?,
      );
}

class Post {
  final String id;
  final String creatorId;
  final String title;
  final String? content;
  final String type;
  final bool isFree;
  final bool isPublished;
  final String? publishedAt;
  final String createdAt;
  final List<PostAttachment> attachments;
  final int likesCount;
  final int commentsCount;
  final bool isLiked;
  final PostCreator? creator;

  const Post({
    required this.id,
    required this.creatorId,
    required this.title,
    this.content,
    required this.type,
    required this.isFree,
    required this.isPublished,
    this.publishedAt,
    required this.createdAt,
    required this.attachments,
    required this.likesCount,
    required this.commentsCount,
    required this.isLiked,
    this.creator,
  });

  /// A locked post is one that is not free AND has no content (server withheld it).
  bool get isLocked => !isFree && content == null;

  factory Post.fromJson(Map<String, dynamic> json) => Post(
        id: json['id'] as String,
        creatorId: json['creator_id'] as String,
        title: json['title'] as String,
        content: json['content'] as String?,
        type: json['type'] as String? ?? 'text',
        isFree: json['is_free'] as bool? ?? false,
        isPublished: json['is_published'] as bool? ?? false,
        publishedAt: json['published_at'] as String?,
        createdAt: json['created_at'] as String,
        attachments: (json['attachments'] as List<dynamic>?)
                ?.map((a) => PostAttachment.fromJson(a as Map<String, dynamic>))
                .toList() ??
            [],
        likesCount: json['likes_count'] as int? ?? 0,
        commentsCount: json['comments_count'] as int? ?? 0,
        isLiked: json['is_liked'] as bool? ?? false,
        creator: json['creator'] != null
            ? PostCreator.fromJson(json['creator'] as Map<String, dynamic>)
            : null,
      );
}
