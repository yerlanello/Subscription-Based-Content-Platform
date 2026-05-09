class CommentAuthor {
  final String id;
  final String username;
  final String? avatarUrl;

  const CommentAuthor({
    required this.id,
    required this.username,
    this.avatarUrl,
  });

  factory CommentAuthor.fromJson(Map<String, dynamic> json) => CommentAuthor(
        id: json['id'] as String,
        username: json['username'] as String,
        avatarUrl: json['avatar_url'] as String?,
      );
}

class Comment {
  final String id;
  final String postId;
  final String? parentId;
  final String content;
  final String createdAt;
  final int likesCount;
  final bool isLiked;
  final CommentAuthor? author;
  final List<Comment> replies;

  const Comment({
    required this.id,
    required this.postId,
    this.parentId,
    required this.content,
    required this.createdAt,
    required this.likesCount,
    required this.isLiked,
    this.author,
    required this.replies,
  });

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
        id: json['id'] as String,
        postId: json['post_id'] as String,
        parentId: json['parent_id'] as String?,
        content: json['content'] as String,
        createdAt: json['created_at'] as String,
        likesCount: json['likes_count'] as int? ?? 0,
        isLiked: json['is_liked'] as bool? ?? false,
        author: json['author'] != null
            ? CommentAuthor.fromJson(json['author'] as Map<String, dynamic>)
            : null,
        replies: (json['replies'] as List<dynamic>?)
                ?.map((r) => Comment.fromJson(r as Map<String, dynamic>))
                .toList() ??
            [],
      );
}
