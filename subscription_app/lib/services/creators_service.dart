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
    final list = (res['data'] as List<dynamic>?) ?? [];
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

  /// Create a Stripe Checkout Session for a paid subscription. Returns the checkout URL (web).
  static Future<String> checkout(String username) async {
    final res = await ApiClient.post('/creators/$username/checkout');
    final data = res['data'] as Map<String, dynamic>;
    return data['url'] as String;
  }

  /// Create a Stripe Checkout Session for a donation. Returns the checkout URL (web).
  static Future<String> donate(
    String username,
    int amountCents, {
    String? message,
  }) async {
    final res = await ApiClient.post('/creators/$username/donate', body: {
      'amount_cents': amountCents,
      if (message != null && message.isNotEmpty) 'message': message,
    });
    final data = res['data'] as Map<String, dynamic>;
    return data['url'] as String;
  }

  /// Mobile: creates a Checkout Session for a paid subscription. Returns the Stripe-hosted URL.
  static Future<String> checkoutIntent(String username) async {
    final res = await ApiClient.post('/creators/$username/checkout-intent');
    final data = res['data'] as Map<String, dynamic>;
    return data['url'] as String;
  }

  /// Mobile: creates a Checkout Session for a donation. Returns the Stripe-hosted URL.
  static Future<String> donateIntent(
    String username,
    int amountCents, {
    String? message,
  }) async {
    final res = await ApiClient.post('/creators/$username/donate-intent', body: {
      'amount_cents': amountCents,
      if (message != null && message.isNotEmpty) 'message': message,
    });
    final data = res['data'] as Map<String, dynamic>;
    return data['url'] as String;
  }

  /// Verify a completed subscription Stripe session and activate the subscription.
  static Future<void> verifySubscription(String sessionId) async {
    await ApiClient.post('/subscriptions/verify-session',
        body: {'session_id': sessionId});
  }

  /// Verify a completed donation Stripe session and record the donation.
  static Future<void> verifyDonation(String sessionId) async {
    await ApiClient.post('/donations/verify', body: {'session_id': sessionId});
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

  /// Fetch creators the current user is subscribed to.
  static Future<List<CreatorWithProfile>> getMySubscriptions() async {
    final res = await ApiClient.get('/users/me/subscriptions');
    final raw = res['data'];
    if (raw == null || raw is! List<dynamic>) return [];
    return raw
        .whereType<Map<String, dynamic>>()
        .where((e) => e['user'] != null && e['profile'] != null)
        .map((e) => CreatorWithProfile.fromJson(e))
        .toList();
  }

  /// Fetch posts published by a specific creator.
  static Future<List<Post>> getPosts(
    String username, {
    int limit = 20,
    int offset = 0,
  }) async {
    final res = await ApiClient.get(
        '/creators/$username/posts?limit=$limit&offset=$offset');
    final list = (res['data'] as List<dynamic>?) ?? [];
    return list.map((e) => Post.fromJson(e as Map<String, dynamic>)).toList();
  }
}
