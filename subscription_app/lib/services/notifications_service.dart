import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/notification.dart';
import 'api_client.dart';
import 'auth_service.dart';

class NotificationsService {
  /// Live unread count — the bell badge listens to this. Updated by [list]
  /// (from the server's `unread_count`) and incremented on each SSE event.
  static final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  /// Bumped whenever a new notification arrives over SSE, so an open
  /// notifications screen can reload itself.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static http.Client? _sseClient;
  static StreamSubscription<String>? _sseSub;
  static Timer? _reconnectTimer;
  static bool _active = false;

  // ---------- REST ----------

  static Future<List<AppNotification>> list() async {
    final res = await ApiClient.get('/notifications');
    final payload = res['data'] as Map<String, dynamic>? ?? {};
    final data = payload['notifications'] as List<dynamic>? ?? [];
    final unread = payload['unread_count'];
    if (unread is int) unreadCount.value = unread;
    return data
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Refresh just the unread count from the server (side effect of [list]).
  static Future<void> refreshUnread() async {
    try {
      await list();
    } catch (_) {/* best-effort */}
  }

  static Future<void> markRead(String id) async {
    await ApiClient.post('/notifications/$id/read');
    if (unreadCount.value > 0) unreadCount.value -= 1;
  }

  static Future<void> markAllRead() async {
    await ApiClient.post('/notifications/read-all');
    unreadCount.value = 0;
  }

  static Future<void> delete(String id) async {
    await ApiClient.delete('/notifications/$id');
  }

  // ---------- realtime (SSE) ----------

  /// Opens the SSE stream and starts tracking unread count. Safe to call
  /// multiple times — only one connection is kept.
  static Future<void> connect() async {
    if (_active) return;
    _active = true;
    await refreshUnread();
    _openStream();
  }

  /// Closes the stream and stops reconnecting (call on logout / shell dispose).
  static void disconnect() {
    _active = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _sseSub?.cancel();
    _sseSub = null;
    _sseClient?.close();
    _sseClient = null;
  }

  static Future<void> _openStream() async {
    if (!_active) return;
    final token = await AuthService.getAccessToken();
    if (token == null) return;

    final client = http.Client();
    _sseClient = client;
    try {
      // EventSource-style: token via query param (SSE can't set headers).
      final req = http.Request(
        'GET',
        Uri.parse('${AppConfig.baseUrl}/notifications/stream?token=$token'),
      );
      req.headers['Accept'] = 'text/event-stream';
      final resp = await client.send(req);
      if (resp.statusCode != 200) {
        _scheduleReconnect();
        return;
      }
      _sseSub = resp.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            _onLine,
            onError: (_) => _scheduleReconnect(),
            onDone: _scheduleReconnect,
            cancelOnError: true,
          );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  static void _onLine(String line) {
    // Keepalive comments arrive as ": ping" — ignore anything but data lines.
    if (!line.startsWith('data:')) return;
    final payload = line.substring(5).trim();
    if (payload.isEmpty) return;
    try {
      jsonDecode(payload); // validate it's a real event, not a stray line
      unreadCount.value = unreadCount.value + 1;
      revision.value = revision.value + 1;
    } catch (_) {/* ignore malformed */}
  }

  static void _scheduleReconnect() {
    _sseSub?.cancel();
    _sseSub = null;
    _sseClient?.close();
    _sseClient = null;
    if (!_active) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), _openStream);
  }
}
