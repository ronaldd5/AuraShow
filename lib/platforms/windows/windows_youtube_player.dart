import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';

/// Custom YouTube player widget using webview_windows (Edge WebView2)
/// for better YouTube DRM and playback support on Windows.
class WindowsYouTubePlayer extends StatefulWidget {
  const WindowsYouTubePlayer({
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
  State<WindowsYouTubePlayer> createState() => _WindowsYouTubePlayerState();
}

class _WindowsYouTubePlayerState extends State<WindowsYouTubePlayer> {
  final _controller = WebviewController();
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    // Defer initialization to avoid layout mutation during build phase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initWebView();
    });
  }

  Future<void> _initWebView() async {
    try {
      await _controller.initialize();
      if (!mounted) return;

      // Build the YouTube embed URL with proper parameters
      final autoplay = widget.autoPlay ? '1' : '0';
      final mute = widget.muted ? '1' : '0';
      final controls = widget.showControls ? '1' : '0';

      // Create HTML page with proper Referrer-Policy for YouTube embed
      // YouTube requires strict-origin-when-cross-origin referrer policy
      final html =
          '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="referrer" content="strict-origin-when-cross-origin">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body { width: 100%; height: 100%; background: #000; overflow: hidden; }
    iframe { width: 100%; height: 100%; border: none; }
  </style>
</head>
<body>
  <iframe 
    id="ytplayer"
    src="https://www.youtube.com/embed/${widget.videoId}?autoplay=$autoplay&mute=$mute&controls=$controls&playsinline=1&enablejsapi=1&rel=0&modestbranding=1&origin=https://www.youtube.com"
    allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
    referrerpolicy="strict-origin-when-cross-origin"
    allowfullscreen>
  </iframe>
</body>
</html>
''';

      // Load the HTML content as a data URI
      final dataUri =
          'data:text/html;charset=utf-8,${Uri.encodeComponent(html)}';
      await _controller.loadUrl(dataUri);

      if (mounted) {
        setState(() => _isInitialized = true);
        widget.onReady?.call();
      }
    } catch (e) {
      debugPrint('WindowsYouTubePlayer: init error: $e');
      if (mounted) {
        setState(() => _hasError = true);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Play the video
  void play() {
    if (_isInitialized) {
      _controller.executeScript("document.querySelector('video')?.play()");
    }
  }

  /// Pause the video
  void pause() {
    if (_isInitialized) {
      _controller.executeScript("document.querySelector('video')?.pause()");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 32),
            const SizedBox(height: 8),
            const Text(
              'Failed to load YouTube video',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (!_isInitialized) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(
          color: Colors.white54,
          strokeWidth: 2,
        ),
      );
    }

    return Webview(_controller);
  }
}
