import '../models/stream.dart';
import 'api_client.dart';

final _usernameRe = RegExp(r'^[a-zA-Z0-9_]{1,50}$');

void _validateUsername(String username) {
  if (!_usernameRe.hasMatch(username)) throw 'Invalid username';
}

class StreamsService {
  /// Returns the creator's currently-active stream, or null if they're offline.
  /// Mirrors `GET /streams/by-creator/{username}` which returns null `data`
  /// when there's no live stream.
  static Future<LiveStream?> getByCreator(String username) async {
    _validateUsername(username);
    final res = await ApiClient.get('/streams/by-creator/$username');
    final data = res['data'];
    if (data == null || data is! Map<String, dynamic>) return null;
    return LiveStream.fromJson(data);
  }

  /// Joins a live stream as a viewer — returns a LiveKit subscribe-only token,
  /// the server URL, and the stream. `POST /streams/{id}/join`.
  static Future<StreamJoinInfo> join(String id) async {
    final res = await ApiClient.post('/streams/$id/join');
    final data = res['data'] as Map<String, dynamic>;
    return StreamJoinInfo(
      token: data['token'] as String,
      livekitUrl: data['livekit_url'] as String,
      stream: LiveStream.fromJson(data['stream'] as Map<String, dynamic>),
    );
  }

  /// Loads persisted chat history for a stream. `GET /streams/{id}/messages`.
  static Future<List<StreamMessage>> getMessages(String id) async {
    final res = await ApiClient.get('/streams/$id/messages');
    final list = (res['data'] as List<dynamic>?) ?? [];
    return list
        .map((e) => StreamMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Persists a chat message so new joiners see it in history.
  /// `POST /streams/{id}/messages`.
  static Future<void> sendMessage(
    String id,
    String message,
    String displayName,
  ) async {
    await ApiClient.post('/streams/$id/messages', body: {
      'message': message,
      'display_name': displayName,
    });
  }
}
