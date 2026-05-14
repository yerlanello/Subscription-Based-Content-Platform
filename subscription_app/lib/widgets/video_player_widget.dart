import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerWidget extends StatefulWidget {
  const VideoPlayerWidget({super.key, required this.url});
  final String url;

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) setState(() => _initialized = true);
      }).catchError((_) {
        if (mounted) setState(() => _error = true);
      });
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    _controller.value.isPlaying ? _controller.pause() : _controller.play();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_error) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam_off_outlined, color: colorScheme.outline, size: 32),
              const SizedBox(height: 8),
              Text('Could not load video', style: TextStyle(color: colorScheme.outline)),
            ],
          ),
        ),
      );
    }

    if (!_initialized) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          ),
          // Play/pause overlay
          GestureDetector(
            onTap: _togglePlay,
            child: AnimatedOpacity(
              opacity: _controller.value.isPlaying ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(12),
                child: const Icon(Icons.play_arrow, color: Colors.white, size: 36),
              ),
            ),
          ),
          // Tap to toggle play when playing
          if (_controller.value.isPlaying)
            GestureDetector(onTap: _togglePlay, child: Container(color: Colors.transparent)),
          // Progress bar at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: VideoProgressIndicator(
              _controller,
              allowScrubbing: true,
              colors: VideoProgressColors(
                playedColor: colorScheme.primary,
                bufferedColor: colorScheme.primary.withAlpha(80),
                backgroundColor: Colors.black26,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
