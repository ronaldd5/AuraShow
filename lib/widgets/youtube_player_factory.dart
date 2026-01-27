import 'dart:io';
import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../platforms/windows/windows_youtube_player.dart' deferred as win;

/// Factory widget that provides a platform-appropriate YouTube player.
///
/// On Windows, it uses the high-performance `webview_windows` (Edge WebView2)
/// via a deferred import to isolate dependencies. On other platforms (macOS, Linux),
/// it uses the standard `youtube_player_iframe`.
class YouTubePlayerFactory extends StatefulWidget {
  const YouTubePlayerFactory({
    super.key,
    required this.videoId,
    this.autoPlay = false,
    this.muted = false,
    this.showControls = true,
    this.onReady,
  });

  final String videoId;
  final bool autoPlay;
  final bool muted;
  final bool showControls;
  final VoidCallback? onReady;

  @override
  State<YouTubePlayerFactory> createState() => _YouTubePlayerFactoryState();
}

class _YouTubePlayerFactoryState extends State<YouTubePlayerFactory> {
  bool _isWinLoaded = false;
  late YoutubePlayerController _iframeController;

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) {
      win.loadLibrary().then((_) {
        if (mounted) setState(() => _isWinLoaded = true);
      });
    } else {
      _initIframeController();
    }
  }

  void _initIframeController() {
    _iframeController = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      autoPlay: widget.autoPlay,
      params: YoutubePlayerParams(
        mute: widget.muted,
        showControls: widget.showControls,
        showFullscreenButton: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isWindows) {
      if (!_isWinLoaded) {
        return Container(
          color: Colors.black,
          alignment: Alignment.center,
          child: const CircularProgressIndicator(color: Colors.white54),
        );
      }
      return win.WindowsYouTubePlayer(
        videoId: widget.videoId,
        autoPlay: widget.autoPlay,
        muted: widget.muted,
        showControls: widget.showControls,
        onReady: widget.onReady,
      );
    }

    // macOS/Linux/Other Fallback
    return YoutubePlayer(controller: _iframeController, aspectRatio: 16 / 9);
  }

  @override
  void dispose() {
    if (!Platform.isWindows) {
      _iframeController.close();
    }
    super.dispose();
  }
}
