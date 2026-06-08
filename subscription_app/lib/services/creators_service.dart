import 'dart:io';
import '../models/creator.dart';
import '../models/post.dart';
import 'api_client.dart';

final _usernameRe = RegExp(r'^[a-zA-Z0-9_]{1,50}$');
final _categoryRe = RegExp(r'^[a-zA-Z0-9 _\-]{1,50}$');

void _validateUsername(String username) {
  if (!_usernameRe.hasMatch(username)) throw 'Invalid username';
}

void _validateCategory(String category) {
  if (!_categoryRe.hasMatch(category)) throw 'Invalid category';
}

void _validatePagination(int limit, int offset) {
  if (limit < 1 || limit > 100) throw 'Invalid limit: $limit';
  if (offset < 0) throw 'Invalid offset: $offset';
}

class CreatorsService {
  /// List all creators.
  static Future<List<CreatorWithProfile>> list({
    int limit = 50,
    int offset = 0,
    String? category,
  }) async {
    _validatePagination(limit, offset);
    if (category != null) _validateCategory(category);
    final query = StringBuffer('/creators?limit=$limit&offset=$offset');
    if (category != null) query.write('&category=${Uri.encodeQueryComponent(category)}');
    final res = await ApiClient.get(query.toString());
    final list = (res['data'] as List<dynamic>?) ?? [];
    return list
        .map((e) => CreatorWithProfile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetch a single creator page (includes is_subscribed, is_following).
  static Future<CreatorPage> getCreatorPage(String username) async {
    _validateUsername(username);
    final res = await ApiClient.get('/creators/$username');
    return CreatorPage.fromJson(res['data'] as Map<String, dynamic>);
  }

  /// Subscribe to a creator (free subscriptions complete immediately;
  /// paid ones may require Stripe — the backend will reject if so).
  static Future<void> subscribe(String username) async {
    _validateUsername(username);
    await ApiClient.post('/creators/$username/subscribe');
  }

  /// Cancel a subscription.
  static Future<void> unsubscribe(String username) async {
    _validateUsername(username);
    await ApiClient.delete('/creators/$username/subscribe');
  }

  /// Create a Stripe Checkout Session for a paid subscription. Returns the checkout URL (web).
  static Future<String> checkout(String username) async {
    _validateUsername(username);
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
    _validateUsername(username);
    final res = await ApiClient.post('/creators/$username/donate', body: {
      'amount_cents': amountCents,
      if (message != null && message.isNotEmpty) 'message': message,
    });
    final data = res['data'] as Map<String, dynamic>;
    return data['url'] as String;
  }

  /// Mobile: creates a Checkout Session for a paid subscription. Returns the Stripe-hosted URL.
  static Future<String> checkoutIntent(String username) async {
    _validateUsername(username);
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
    _validateUsername(username);
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

  /// Update the current creator's profile. Only non-null fields are sent.
  static Future<CreatorProfile> updateProfile(
    String username, {
    String? displayName,
    String? description,
    String? category,
    int? subscriptionPriceCents,
    String? subscriptionDescription,
  }) async {
    _validateUsername(username);
    final res = await ApiClient.put('/creators/$username', body: {
      'display_name': ?displayName,
      'description': ?description,
      'category': ?category,
      'subscription_price_cents': ?subscriptionPriceCents,
      'subscription_description': ?subscriptionDescription,
    });
    return CreatorProfile.fromJson(res['data'] as Map<String, dynamic>);
  }

  /// Upload a new banner/cover image for the current creator.
  /// Returns the updated profile (with the new cover_url).
  static Future<CreatorProfile> uploadCover(String username, File file) async {
    _validateUsername(username);
    final res =
        await ApiClient.postMultipart('/creators/$username/cover', file, 'cover');
    return CreatorProfile.fromJson(res['data'] as Map<String, dynamic>);
  }

  /// Follow a creator.
  static Future<void> follow(String username) async {
    _validateUsername(username);
    await ApiClient.post('/creators/$username/follow');
  }

  /// Unfollow a creator.
  static Future<void> unfollow(String username) async {
    _validateUsername(username);
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
    _validateUsername(username);
    _validatePagination(limit, offset);
    final res = await ApiClient.get(
        '/creators/$username/posts?limit=$limit&offset=$offset');
    final list = (res['data'] as List<dynamic>?) ?? [];
    return list.map((e) => Post.fromJson(e as Map<String, dynamic>)).toList();
  }
}
