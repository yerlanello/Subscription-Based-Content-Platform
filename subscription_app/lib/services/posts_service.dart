import '../models/comment.dart';
import '../models/post.dart';
import 'api_client.dart';

class PostsService {
  static Future<List<Post>> feed({int limit = 20, int offset = 0}) async {
    final res = await ApiClient.get('/posts/feed?limit=$limit&offset=$offset');
    final list = res['data'] as List<dynamic>;
    return list.map((e) => Post.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<List<Post>> explore({int limit = 20, int offset = 0}) async {
    final res = await ApiClient.get('/posts/explore?limit=$limit&offset=$offset');
    final list = res['data'] as List<dynamic>;
    return list.map((e) => Post.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<List<Post>> recommended({int limit = 20, int offset = 0}) async {
    final res = await ApiClient.get('/posts/recommended?limit=$limit&offset=$offset');
    final list = res['data'] as List<dynamic>;
    return list.map((e) => Post.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<Post> getById(String id) async {
    final res = await ApiClient.get('/posts/$id');
    return Post.fromJson(res['data'] as Map<String, dynamic>);
  }

  static Future<Post> create({
    required String title,
    String? content,
    bool isFree = false,
  }) async {
    final res = await ApiClient.post('/posts', body: {
      'title': title,
      if (content != null && content.isNotEmpty) 'content': content,
      'type': 'text',
      'is_free': isFree,
    });
    return Post.fromJson(res['data'] as Map<String, dynamic>);
  }

  static Future<Post> update(String id, {String? title, String? content, bool? isFree}) async {
    final res = await ApiClient.put('/posts/$id', body: {
      if (title != null) 'title': title,
      if (content != null) 'content': content,
      if (isFree != null) 'is_free': isFree,
    });
    return Post.fromJson(res['data'] as Map<String, dynamic>);
  }

  static Future<void> publish(String id) async {
    await ApiClient.post('/posts/$id/publish');
  }

  static Future<void> unpublish(String id) async {
    await ApiClient.post('/posts/$id/unpublish');
  }

  static Future<void> pin(String id) async {
    await ApiClient.post('/posts/$id/pin');
  }

  static Future<void> unpin(String id) async {
    await ApiClient.delete('/posts/$id/pin');
  }

  static Future<void> like(String id) async {
    await ApiClient.post('/posts/$id/like');
  }

  static Future<void> unlike(String id) async {
    await ApiClient.delete('/posts/$id/like');
  }

  static Future<List<Post>> byCreator(String username) async {
    final res = await ApiClient.get('/creators/$username/posts');
    final list = res['data'] as List<dynamic>;
    return list.map((e) => Post.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> delete(String id) async {
    await ApiClient.delete('/posts/$id');
  }

  // ---------- comments ----------

  static Future<List<Comment>> getComments(String postId) async {
    final res = await ApiClient.get('/posts/$postId/comments');
    final list = res['data'] as List<dynamic>;
    return list.map((e) => Comment.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<Comment> createComment(String postId, String content, {String? parentId}) async {
    final res = await ApiClient.post('/posts/$postId/comments', body: {
      'content': content,
      if (parentId != null) 'parent_id': parentId,
    });
    return Comment.fromJson(res['data'] as Map<String, dynamic>);
  }

  static Future<void> deleteComment(String postId, String commentId) async {
    await ApiClient.delete('/posts/$postId/comments/$commentId');
  }

  static Future<void> likeComment(String postId, String commentId) async {
    await ApiClient.post('/posts/$postId/comments/$commentId/like');
  }

  static Future<void> unlikeComment(String postId, String commentId) async {
    await ApiClient.delete('/posts/$postId/comments/$commentId/like');
  }
}
