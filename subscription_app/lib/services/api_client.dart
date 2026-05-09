import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ApiClient {
  static const _base = 'http://localhost:8080/api';

  // Prevent concurrent refresh calls.
  static bool _refreshing = false;

  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Returns true if refresh succeeded and new tokens were saved.
  static Future<bool> _tryRefresh() async {
    if (_refreshing) return false;
    _refreshing = true;
    try {
      final refreshToken = await AuthService.getRefreshToken();
      if (refreshToken == null) return false;
      final res = await http.post(
        Uri.parse('$_base/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );
      if (res.statusCode < 200 || res.statusCode >= 300) return false;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>;
      await AuthService.saveTokens(
        data['access_token'] as String,
        data['refresh_token'] as String,
      );
      return true;
    } catch (_) {
      return false;
    } finally {
      _refreshing = false;
    }
  }

  static Map<String, dynamic> _parse(http.Response res) {
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw body['error'] as String? ?? 'Request failed (${res.statusCode})';
  }

  // Executes [fn], and if it returns a 401 attempts one token refresh then retries.
  static Future<Map<String, dynamic>> _withRefresh(
    Future<http.Response> Function(Map<String, String> headers) fn,
  ) async {
    var headers = await _headers();
    var res = await fn(headers);
    if (res.statusCode == 401) {
      final refreshed = await _tryRefresh();
      if (!refreshed) {
        await AuthService.clearTokens();
        throw 'Session expired. Please log in again.';
      }
      headers = await _headers();
      res = await fn(headers);
    }
    return _parse(res);
  }

  static Future<Map<String, dynamic>> get(String path) =>
      _withRefresh((h) => http.get(Uri.parse('$_base$path'), headers: h));

  static Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) =>
      _withRefresh((h) => http.post(
            Uri.parse('$_base$path'),
            headers: h,
            body: body != null ? jsonEncode(body) : null,
          ));

  static Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
  }) =>
      _withRefresh((h) => http.put(
            Uri.parse('$_base$path'),
            headers: h,
            body: body != null ? jsonEncode(body) : null,
          ));

  static Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
  }) =>
      _withRefresh((h) => http.patch(
            Uri.parse('$_base$path'),
            headers: h,
            body: body != null ? jsonEncode(body) : null,
          ));

  static Future<Map<String, dynamic>> delete(String path) =>
      _withRefresh((h) => http.delete(Uri.parse('$_base$path'), headers: h));

  /// Upload a file via multipart/form-data. Handles token refresh like other methods.
  static Future<Map<String, dynamic>> postMultipart(
    String path,
    File file,
    String fieldName,
  ) async {
    Future<http.Response> send(Map<String, String> headers) async {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_base$path'),
      );
      final token = await AuthService.getAccessToken();
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath(fieldName, file.path));
      final streamed = await request.send();
      return http.Response.fromStream(streamed);
    }

    var res = await send(await _headers());
    if (res.statusCode == 401) {
      final refreshed = await _tryRefresh();
      if (!refreshed) {
        await AuthService.clearTokens();
        throw 'Session expired. Please log in again.';
      }
      res = await send(await _headers());
    }
    return _parse(res);
  }
}
