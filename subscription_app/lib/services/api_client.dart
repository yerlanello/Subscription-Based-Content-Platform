import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

/// Thin HTTP client that attaches the stored access token to every request.
/// Matches the base URL used in AuthService.
class ApiClient {
  static const _base = 'http://localhost:8080/api';

  // ---------- helpers ----------

  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Map<String, dynamic> _handle(http.Response res) {
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw body['error'] as String? ?? 'Request failed (${res.statusCode})';
  }

  // ---------- verbs ----------

  static Future<Map<String, dynamic>> get(String path) async {
    final res = await http.get(
      Uri.parse('$_base$path'),
      headers: await _headers(),
    );
    return _handle(res);
  }

  static Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final res = await http.post(
      Uri.parse('$_base$path'),
      headers: await _headers(),
      body: body != null ? jsonEncode(body) : null,
    );
    return _handle(res);
  }

  static Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final res = await http.put(
      Uri.parse('$_base$path'),
      headers: await _headers(),
      body: body != null ? jsonEncode(body) : null,
    );
    return _handle(res);
  }

  static Future<Map<String, dynamic>> delete(String path) async {
    final res = await http.delete(
      Uri.parse('$_base$path'),
      headers: await _headers(),
    );
    return _handle(res);
  }
}
