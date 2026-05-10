import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class UserStats {
  final int subscriptionsCount;
  final int followingCount;
  final String? avatarUrl;
  final String? bio;
  final bool emailVerified;

  const UserStats({
    required this.subscriptionsCount,
    required this.followingCount,
    this.avatarUrl,
    this.bio,
    this.emailVerified = false,
  });
}

class AuthService {
  static const _base = AppConfig.baseUrl;

  static const _keyAccess = 'access_token';
  static const _keyRefresh = 'refresh_token';
  static const _keyUsername = 'username';
  static const _keyEmail = 'email';
  static const _keyRole = 'role';
  static const _keyAvatarUrl = 'avatar_url';
  static const _keyEmailVerified = 'email_verified';

  /// Login with email and password. Returns the response data map.
  /// Throws a [String] error message on failure.
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('$_base/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw body['error'] as String? ?? 'Login failed';
    }
    return body['data'] as Map<String, dynamic>;
  }

  /// Register a new account. Returns the response data map.
  /// Throws a [String] error message on failure.
  static Future<Map<String, dynamic>> register(
      String username, String email, String password) async {
    final res = await http.post(
      Uri.parse('$_base/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'email': email, 'password': password}),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 201) {
      throw body['error'] as String? ?? 'Registration failed';
    }
    return body['data'] as Map<String, dynamic>;
  }

  /// Persist tokens to local storage.
  static Future<void> saveTokens(String accessToken, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAccess, accessToken);
    await prefs.setString(_keyRefresh, refreshToken);
  }

  /// Retrieve the stored access token, or null if not logged in.
  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAccess);
  }

  /// Retrieve the stored refresh token, or null if not logged in.
  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRefresh);
  }

  /// Persist basic user info to local storage.
  static Future<void> saveUser(
    String username,
    String email, {
    bool emailVerified = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUsername, username);
    await prefs.setString(_keyEmail, email);
    await prefs.setBool(_keyEmailVerified, emailVerified);
  }

  static Future<void> saveEmailVerified(bool verified) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEmailVerified, verified);
  }

  static Future<bool> getEmailVerified() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyEmailVerified) ?? false;
  }

  /// Change the authenticated user's password.
  static Future<void> changePassword(String currentPassword, String newPassword) async {
    final token = await getAccessToken();
    if (token == null) throw 'Not logged in';
    final res = await http.put(
      Uri.parse('$_base/auth/change-password'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'current_password': currentPassword,
        'new_password': newPassword,
      }),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw body['error'] as String? ?? 'Failed to change password';
    }
  }

  /// Request a new verification email for the currently authenticated user.
  static Future<void> resendVerification() async {
    final token = await getAccessToken();
    if (token == null) throw 'Not logged in';
    final res = await http.post(
      Uri.parse('$_base/auth/resend-verification'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw body['error'] as String? ?? 'Failed to resend verification email';
    }
  }

  static Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUsername);
  }

  static Future<String?> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyEmail);
  }

  /// Persist the user's role to local storage.
  static Future<void> saveRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyRole, role);
  }

  /// Retrieve the stored role, or null if not logged in.
  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRole);
  }

  static Future<void> saveAvatarUrl(String? url) async {
    final prefs = await SharedPreferences.getInstance();
    if (url != null) {
      await prefs.setString(_keyAvatarUrl, url);
    } else {
      await prefs.remove(_keyAvatarUrl);
    }
  }

  static Future<String?> getAvatarUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAvatarUrl);
  }

  /// Fetch live user data from the server and update cached values.
  static Future<UserStats> getMe() async {
    final token = await getAccessToken();
    if (token == null) throw 'Not logged in';
    final res = await http.get(
      Uri.parse('$_base/users/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw body['error'] as String? ?? 'Failed to load profile';
    }
    final data = body['data'] as Map<String, dynamic>;
    final avatarUrl = data['avatar_url'] as String?;
    final emailVerified = data['email_verified'] as bool? ?? false;
    await saveAvatarUrl(avatarUrl);
    await saveEmailVerified(emailVerified);
    return UserStats(
      subscriptionsCount: data['subscriptions_count'] as int? ?? 0,
      followingCount: data['following_count'] as int? ?? 0,
      avatarUrl: avatarUrl,
      bio: data['bio'] as String?,
      emailVerified: emailVerified,
    );
  }

  /// Update user bio.
  static Future<void> updateProfile({String? bio}) async {
    final token = await getAccessToken();
    if (token == null) throw 'Not logged in';
    final res = await http.put(
      Uri.parse('$_base/users/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'bio': bio ?? ''}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw body['error'] as String? ?? 'Failed to update profile';
    }
  }

  /// Clear stored tokens and user info (logout).
  static Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAccess);
    await prefs.remove(_keyRefresh);
    await prefs.remove(_keyUsername);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyRole);
    await prefs.remove(_keyAvatarUrl);
    await prefs.remove(_keyEmailVerified);
  }
}
