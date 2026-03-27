import 'user.dart';

class CreatorProfile {
  final String id;
  final String userId;
  final String displayName;
  final String? description;
  final String? coverUrl;
  final String? category;
  final int subscriptionPriceCents;
  final String? subscriptionDescription;

  const CreatorProfile({
    required this.id,
    required this.userId,
    required this.displayName,
    this.description,
    this.coverUrl,
    this.category,
    required this.subscriptionPriceCents,
    this.subscriptionDescription,
  });

  factory CreatorProfile.fromJson(Map<String, dynamic> json) => CreatorProfile(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        displayName: json['display_name'] as String,
        description: json['description'] as String?,
        coverUrl: json['cover_url'] as String?,
        category: json['category'] as String?,
        subscriptionPriceCents: json['subscription_price_cents'] as int? ?? 0,
        subscriptionDescription: json['subscription_description'] as String?,
      );

  String get priceLabel {
    if (subscriptionPriceCents == 0) return 'Free';
    return '$subscriptionPriceCents ₸/mo';
  }

  bool get isFree => subscriptionPriceCents == 0;
}

/// Returned by GET /creators (list)
class CreatorWithProfile {
  final User user;
  final CreatorProfile profile;

  const CreatorWithProfile({required this.user, required this.profile});

  factory CreatorWithProfile.fromJson(Map<String, dynamic> json) =>
      CreatorWithProfile(
        user: User.fromJson(json['user'] as Map<String, dynamic>),
        profile: CreatorProfile.fromJson(json['profile'] as Map<String, dynamic>),
      );
}

/// Returned by GET /creators/{username} (single creator page)
class CreatorPage {
  final User user;
  final CreatorProfile profile;
  final bool isSubscribed;
  final bool isFollowing;

  const CreatorPage({
    required this.user,
    required this.profile,
    required this.isSubscribed,
    required this.isFollowing,
  });

  factory CreatorPage.fromJson(Map<String, dynamic> json) => CreatorPage(
        user: User.fromJson(json['user'] as Map<String, dynamic>),
        profile: CreatorProfile.fromJson(json['profile'] as Map<String, dynamic>),
        isSubscribed: json['is_subscribed'] as bool? ?? false,
        isFollowing: json['is_following'] as bool? ?? false,
      );
}
