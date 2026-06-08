import '../config/app_config.dart';

/// A live stream, mirroring the backend `Stream` model (with joined creator fields).
class LiveStream {
  final String id;
  final String creatorId;
  final String title;
  final String status;
  final double? latitude;
  final double? longitude;
  final String livekitRoom;
  final int viewerCount;
  final String startedAt;
  // Joined creator fields
  final String username;
  final String displayName;
  final String? avatarUrl;

  const LiveStream({
    required this.id,
    required this.creatorId,
    required this.title,
    required this.status,
    this.latitude,
    this.longitude,
    required this.livekitRoom,
    required this.viewerCount,
    required this.startedAt,
    required this.username,
    required this.displayName,
    this.avatarUrl,
  });

  bool get isLive => status == 'live';

  factory LiveStream.fromJson(Map<String, dynamic> json) {
    final avatar = json['avatar_url'] as String?;
    return LiveStream(
      id: json['id'] as String,
      creatorId: json['creator_id'] as String,
      title: json['title'] as String? ?? '',
      status: json['status'] as String? ?? 'live',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      livekitRoom: json['livekit_room'] as String? ?? '',
      viewerCount: json['viewer_count'] as int? ?? 0,
      startedAt: json['started_at'] as String? ?? '',
      username: json['username'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      avatarUrl: (avatar != null && avatar.isNotEmpty)
          ? AppConfig.absoluteUrl(avatar)
          : null,
    );
  }
}

/// A persisted chat message for a stream, mirroring the backend `StreamMessage`.
class StreamMessage {
  final String id;
  final String username;
  final String displayName;
  final String message;
  final String createdAt;

  const StreamMessage({
    required this.id,
    required this.username,
    required this.displayName,
    required this.message,
    required this.createdAt,
  });

  factory StreamMessage.fromJson(Map<String, dynamic> json) => StreamMessage(
        id: json['id'] as String,
        username: json['username'] as String? ?? '',
        displayName: json['display_name'] as String? ?? '',
        message: json['message'] as String? ?? '',
        createdAt: json['created_at'] as String? ?? '',
      );
}

/// Result of joining a stream: a LiveKit token + server URL + the stream itself.
class StreamJoinInfo {
  final String token;
  final String livekitUrl;
  final LiveStream stream;

  const StreamJoinInfo({
    required this.token,
    required this.livekitUrl,
    required this.stream,
  });
}
