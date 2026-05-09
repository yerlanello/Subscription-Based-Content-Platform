import '../models/creator.dart';
import '../models/post.dart';
import 'api_client.dart';

class CreatorsService {
  /// List all creators.
  static Future<List<CreatorWithProfile>> list({
    int limit = 50,
    int offset = 0,
    String? category,
  }) async {
    final query = StringBuffer('/creators?limit=$limit&offset=$offset');
    if (category != null) query.write('&category=$category');
    final res = await ApiClient.get(query.toString());
    final list = res['data'] as List<dynamic>;
    return list
        .map((e) => CreatorWithProfile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetch a single creator page (includes is_subscribed, is_following).
  static Future<CreatorPage> getCreatorPage(String username) async {
    final res = await ApiClient.get('/creators/$username');
    return CreatorPage.fromJson(res['data'] as Map<String, dynamic>);
  }

  /// Subscribe to a creator (free subscriptions complete immediately;
  /// paid ones may require Stripe — the backend will reject if so).
  static Future<void> subscribe(String username) async {
    await ApiClient.post('/creators/$username/subscribe');
  }

  /// Cancel a subscription.
  static Future<void> unsubscribe(String username) async {
    await ApiClient.delete('/creators/$username/subscribe');
  }

  /// Upgrade the current patron account to a creator account.
  static Future<void> becomeCreator(String displayName) async {
    await ApiClient.post('/creators', body: {'display_name': displayName});
  }

  /// Follow a creator.
  static Future<void> follow(String username) async {
    await ApiClient.post('/creators/$username/follow');
  }

  /// Unfollow a creator.
  static Future<void> unfollow(String username) async {
    await ApiClient.delete('/creators/$username/follow');
  }

  /// Fetch posts published by a specific creator.
  static Future<List<Post>> getPosts(
    String username, {
    int limit = 20,
    int offset = 0,
  }) async {
    final res = await ApiClient.get(
        '/creators/$username/posts?limit=$limit&offset=$offset');
    final list = res['data'] as List<dynamic>;
    return list.map((e) => Post.fromJson(e as Map<String, dynamic>)).toList();
  }
}
