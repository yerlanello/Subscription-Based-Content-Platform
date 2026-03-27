enum UserRole { patron, creator, both }

class User {
  final String id;
  final String username;
  final String? email;
  final UserRole role;
  final String? avatarUrl;
  final String? bio;

  const User({
    required this.id,
    required this.username,
    this.email,
    required this.role,
    this.avatarUrl,
    this.bio,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      username: json['username'] as String,
      email: json['email'] as String?,
      role: _parseRole(json['role'] as String? ?? 'patron'),
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
    );
  }

  static UserRole _parseRole(String raw) {
    switch (raw) {
      case 'creator':
        return UserRole.creator;
      case 'both':
        return UserRole.both;
      default:
        return UserRole.patron;
    }
  }

  bool get isCreator => role == UserRole.creator || role == UserRole.both;

  String get roleLabel {
    switch (role) {
      case UserRole.creator:
        return 'Creator';
      case UserRole.both:
        return 'Creator & Patron';
      case UserRole.patron:
        return 'Patron';
    }
  }
}
