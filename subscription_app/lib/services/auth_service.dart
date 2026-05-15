import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  static final _base = AppConfig.baseUrl;

  // Tokens are stored in the platform secure keystore (Keychain / Keystore).
  // Both tokens are written as a single JSON blob so the write is atomic.
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _keyTokens = 'auth_tokens';

  /// Fires whenever the stored role changes (e.g. patron → creator).
  static final roleNotifier = ValueNotifier<String?>('patron');

  // Non-sensitive profile data stays in SharedPreferences.
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

  /// Persist tokens to the platform secure keystore (atomic single-key write).
  static Future<void> saveTokens(String accessToken, String refreshToken) async {
    await _secureStorage.write(
      key: _keyTokens,
      value: jsonEncode({'access': accessToken, 'refresh': refreshToken}),
    );
  }

  /// Retrieve the stored access token, or null if not logged in.
  static Future<String?> getAccessToken() async {
    final raw = await _secureStorage.read(key: _keyTokens);
    if (raw == null) return null;
    return (jsonDecode(raw) as Map<String, dynamic>)['access'] as String?;
  }

  /// Retrieve the stored refresh token, or null if not logged in.
  static Future<String?> getRefreshToken() async {
    final raw = await _secureStorage.read(key: _keyTokens);
    if (raw == null) return null;
    return (jsonDecode(raw) as Map<String, dynamic>)['refresh'] as String?;
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

  // Executes [fn] with the current access token. On a 401 it attempts one
  // silent refresh and retries. Throws a String message on failure.
  static Future<http.Response> _authenticatedRequest(
    Future<http.Response> Function(String token) fn,
  ) async {
    var token = await getAccessToken();
    if (token == null) throw 'Not logged in';
    var res = await fn(token);
    if (res.statusCode != 401) return res;

    // 401 — try a refresh then retry once.
    final refreshToken = await getRefreshToken();
    if (refreshToken == null) {
      await clearTokens();
      throw 'Session expired. Please log in again.';
    }
    final refreshRes = await http.post(
      Uri.parse('$_base/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh_token': refreshToken}),
    );
    if (refreshRes.statusCode < 200 || refreshRes.statusCode >= 300) {
      await clearTokens();
      throw 'Session expired. Please log in again.';
    }
    final data =
        (jsonDecode(refreshRes.body) as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    await saveTokens(data['access_token'] as String, data['refresh_token'] as String);
    token = (await getAccessToken())!;
    return fn(token);
  }

  /// Change the authenticated user's password.
  static Future<void> changePassword(String currentPassword, String newPassword) async {
    final res = await _authenticatedRequest((token) => http.put(
          Uri.parse('$_base/auth/change-password'),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
          body: jsonEncode({'current_password': currentPassword, 'new_password': newPassword}),
        ));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw body['error'] as String? ?? 'Failed to change password';
    }
  }

  /// Request a new verification email for the currently authenticated user.
  static Future<void> resendVerification() async {
    final res = await _authenticatedRequest((token) => http.post(
          Uri.parse('$_base/auth/resend-verification'),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        ));
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

  /// Persist the user's role to local storage and notify listeners.
  static Future<void> saveRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyRole, role);
    roleNotifier.value = role;
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
    final res = await _authenticatedRequest((token) => http.get(
          Uri.parse('$_base/users/me'),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        ));
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
    final res = await _authenticatedRequest((token) => http.put(
          Uri.parse('$_base/users/me'),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
          body: jsonEncode({'bio': bio ?? ''}),
        ));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw body['error'] as String? ?? 'Failed to update profile';
    }
  }

  /// Clear stored tokens and user info (logout).
  static Future<void> clearTokens() async {
    await _secureStorage.delete(key: _keyTokens);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUsername);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyRole);
    await prefs.remove(_keyAvatarUrl);
    await prefs.remove(_keyEmailVerified);
  }
}
