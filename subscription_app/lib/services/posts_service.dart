import '../models/post.dart';
import 'api_client.dart';

class PostsService {
  /// Fetch the subscription feed for the logged-in user.
  static Future<List<Post>> feed({int limit = 20, int offset = 0}) async {
    final res = await ApiClient.get('/posts/feed?limit=$limit&offset=$offset');
    final list = res['data'] as List<dynamic>;
    return list.map((e) => Post.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Create a draft post and return it.
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

  /// Publish a previously created draft.
  static Future<void> publish(String id) async {
    await ApiClient.post('/posts/$id/publish');
  }

  /// Like a post.
  static Future<void> like(String id) async {
    await ApiClient.post('/posts/$id/like');
  }

  /// Unlike a post.
  static Future<void> unlike(String id) async {
    await ApiClient.delete('/posts/$id/like');
  }

  /// Fetch all posts by a specific creator username.
  static Future<List<Post>> byCreator(String username) async {
    final res = await ApiClient.get('/posts?creator=$username');
    final list = res['data'] as List<dynamic>;
    return list.map((e) => Post.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Delete a post by id.
  static Future<void> delete(String id) async {
    await ApiClient.delete('/posts/$id');
  }
}
