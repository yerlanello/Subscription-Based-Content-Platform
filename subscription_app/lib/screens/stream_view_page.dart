import 'dart:async';

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

import '../config/app_config.dart';
import '../l10n/app_localizations.dart';
import '../models/stream.dart';
import '../services/streams_service.dart';
import '../widgets/stream_chat.dart';

/// Viewer screen for a live stream: subscribes to the publisher's video over
/// LiveKit and shows the realtime chat. Mirrors the web stream view.
class StreamViewPage extends StatefulWidget {
  const StreamViewPage({super.key, required this.streamId, this.preloaded});

  final String streamId;

  /// Optional stream fetched earlier (e.g. on the creator profile) so the header
  /// can render instantly while we connect.
  final LiveStream? preloaded;

  @override
  State<StreamViewPage> createState() => _StreamViewPageState();
}

class _StreamViewPageState extends State<StreamViewPage> {
  Room? _room;
  LiveStream? _stream;
  String? _error;
  bool _waited = false; // after a grace period, assume the host just has no video
  Timer? _graceTimer;

  @override
  void initState() {
    super.initState();
    _stream = widget.preloaded;
    _connect();
    _graceTimer = Timer(const Duration(seconds: 8), () {
      if (mounted) setState(() => _waited = true);
    });
  }

  @override
  void dispose() {
    _graceTimer?.cancel();
    _room?.removeListener(_onRoomChange);
    _room?.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    try {
      final info = await StreamsService.join(widget.streamId);
      final room = Room();
      await room.connect(AppConfig.livekitUrl(info.livekitUrl), info.token);
      room.addListener(_onRoomChange);
      if (!mounted) {
        await room.dispose();
        return;
      }
      setState(() {
        _room = room;
        _stream = info.stream;
      });
    } catch (_) {
      if (mounted) setState(() => _error = L10n.t('stream_unavailable'));
    }
  }

  void _onRoomChange() {
    if (mounted) setState(() {});
  }

  VideoTrack? get _videoTrack {
    final room = _room;
    if (room == null) return null;
    for (final p in room.remoteParticipants.values) {
      for (final pub in p.videoTrackPublications) {
        final track = pub.track;
        if (pub.subscribed && track != null) return track;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final stream = _stream;
    return Scaffold(
      appBar: AppBar(
        title: Text(stream?.title ?? L10n.t('live_stream')),
      ),
      body: _error != null
          ? _buildError()
          : Column(
              children: [
                _buildVideo(),
                if (stream != null) _buildInfoBar(stream),
                Expanded(child: _buildChat()),
              ],
            ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.videocam_off_outlined, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Text(_error!),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(L10n.t('back')),
          ),
        ],
      ),
    );
  }

  Widget _buildVideo() {
    final track = _videoTrack;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        color: Colors.black,
        child: track != null
            ? VideoTrackRenderer(track)
            : Center(
                child: _waited
                    ? Text(
                        L10n.t('video_unavailable'),
                        style: const TextStyle(color: Colors.white54),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: Colors.white54),
                          const SizedBox(height: 12),
                          Text(
                            L10n.t('connecting_stream'),
                            style: const TextStyle(color: Colors.white54),
                          ),
                        ],
                      ),
              ),
      ),
    );
  }

  Widget _buildInfoBar(LiveStream stream) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border:
            Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                Text(
                  L10n.t('live'),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '@${stream.username}',
              style: TextStyle(color: colorScheme.outline, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(Icons.visibility_outlined,
              size: 15, color: colorScheme.outline),
          const SizedBox(width: 4),
          Text('${stream.viewerCount}',
              style: TextStyle(color: colorScheme.outline, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildChat() {
    final room = _room;
    if (room == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return StreamChat(room: room, streamId: widget.streamId);
  }
}
