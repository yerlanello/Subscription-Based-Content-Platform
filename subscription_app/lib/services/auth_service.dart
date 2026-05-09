import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // Android emulator: 10.0.2.2 maps to host machine's localhost.
  // Change to 'localhost' for Flutter web or iOS simulator.
  static const _base = 'http://localhost:8080/api';

  static const _keyAccess = 'access_token';
  static const _keyRefresh = 'refresh_token';
  static const _keyUsername = 'username';
  static const _keyEmail = 'email';
  static const _keyRole = 'role';

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
  static Future<void> saveUser(String username, String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUsername, username);
    await prefs.setString(_keyEmail, email);
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

  /// Clear stored tokens and user info (logout).
  static Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAccess);
    await prefs.remove(_keyRefresh);
    await prefs.remove(_keyUsername);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyRole);
  }
}
