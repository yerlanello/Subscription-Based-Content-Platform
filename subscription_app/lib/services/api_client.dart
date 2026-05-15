import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../config/app_config.dart';

const _kTimeout = Duration(seconds: 15);

class ApiClient {
  static final _base = AppConfig.baseUrl;

  // Non-null while a refresh is in progress; all concurrent callers await the same future.
  static Completer<bool>? _refreshCompleter;

  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Returns true if refresh succeeded. Concurrent callers wait on the same Completer
  // so only one refresh request is ever in-flight at a time.
  static Future<bool> _tryRefresh() async {
    if (_refreshCompleter != null) return _refreshCompleter!.future;
    _refreshCompleter = Completer<bool>();
    try {
      final refreshToken = await AuthService.getRefreshToken();
      if (refreshToken == null) {
        _refreshCompleter!.complete(false);
        return false;
      }
      final res = await http
          .post(
            Uri.parse('$_base/auth/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh_token': refreshToken}),
          )
          .timeout(_kTimeout);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        _refreshCompleter!.complete(false);
        return false;
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>;
      await AuthService.saveTokens(
        data['access_token'] as String,
        data['refresh_token'] as String,
      );
      _refreshCompleter!.complete(true);
      return true;
    } catch (_) {
      _refreshCompleter!.complete(false);
      return false;
    } finally {
      _refreshCompleter = null;
    }
  }

  static Map<String, dynamic> _parse(http.Response res) {
    final isSuccess = res.statusCode >= 200 && res.statusCode < 300;
    if (res.body.isEmpty) {
      if (isSuccess) return {};
      throw 'Request failed (${res.statusCode})';
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (isSuccess) return body;
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

  static Future<Map<String, dynamic>> get(String path) => _withRefresh(
        (h) => http.get(Uri.parse('$_base$path'), headers: h).timeout(_kTimeout),
      );

  static Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) =>
      _withRefresh((h) => http
          .post(
            Uri.parse('$_base$path'),
            headers: h,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(_kTimeout));

  static Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
  }) =>
      _withRefresh((h) => http
          .put(
            Uri.parse('$_base$path'),
            headers: h,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(_kTimeout));

  static Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
  }) =>
      _withRefresh((h) => http
          .patch(
            Uri.parse('$_base$path'),
            headers: h,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(_kTimeout));

  static Future<Map<String, dynamic>> delete(String path) => _withRefresh(
        (h) => http.delete(Uri.parse('$_base$path'), headers: h).timeout(_kTimeout),
      );

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
      final streamed = await request.send().timeout(_kTimeout);
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
