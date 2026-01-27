import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:video_player/video_player.dart' as vp;
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../models/projection_slide.dart';
import '../projection_constants.dart';
import '../../../platforms/desktop_capture.dart';
import '../../../services/text_token_service.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../dashboard/widgets/shader_background.dart';
import '../../dashboard/widgets/qr_widget.dart';
import '../../../widgets/clock_layer_widget.dart';
import '../../../widgets/weather_layer_widget.dart';
import '../../../widgets/audio_layer_widget.dart';
import '../../../widgets/visualizer_layer_widget.dart';
import '../../../models/slide_model.dart';
import '../../../core/utils/liturgy_renderer.dart';

/// Widget for rendering a projected layer (media or text).
class ProjectedLayer extends StatelessWidget {
  const ProjectedLayer({
    super.key,
    required this.layer,
    required this.stageWidth,
    required this.stageHeight,
    required this.textStyle,
    this.isPlaying = false,
  });

  final ProjectionLayer layer;
  final double stageWidth;
  final double stageHeight;
  final TextStyle textStyle;
  final bool isPlaying;

  @override
  Widget build(BuildContext context) {
    final hasMedia = layer.path != null && layer.path!.isNotEmpty;
    final hasText = layer.text != null && layer.text!.isNotEmpty;

    // Handle screen capture layers
    if (layer.kind == 'screen') {
      return ScreenCaptureLayer(
        layer: layer,
        stageWidth: stageWidth,
        stageHeight: stageHeight,
      );
    }

    if (layer.kind == 'shader' || layer.kind == 'shader') {
      return ShaderWidget(
        shaderId: layer.shaderId,
        opacity: layer.opacity ?? 1.0,
        boxColor: layer.boxColor,
        color1: layer.boxColor,
        color2: layer.outlineColor,
        speed: layer.shaderParams?['speed'] ?? 1.0,
        intensity: layer.shaderParams?['intensity'] ?? 1.0,
      );
    }

    if (layer.kind == 'qr') {
      return QrWidget(
        data: layer.qrData ?? 'https://aurashow.app',
        foregroundColor: layer.qrForegroundColor ?? Colors.black,
        backgroundColor: layer.qrBackgroundColor ?? Colors.white,
      );
    }

    if (layer.kind == 'clock') {
      final slideLayer = SlideLayer(
        id: 'proj-clock',
        label: 'Clock',
        kind: LayerKind.clock,
        role: LayerRole.foreground,
        clockType: layer.clockType,
        clockShowSeconds: layer.clockShowSeconds,
        clock24Hour: layer.clock24Hour,
        textColor: layer.textColor,
        boxColor: layer.boxColor,
        fontFamily: layer.fontFamily,
        fontSize: layer.fontSize,
        isBold: layer.isBold,
        isItalic: layer.isItalic,
        isUnderline: layer.isUnderline,
        align: layer.align,
        // Map other potentially relevant fields if needed
      );
      final scale = stageWidth / 1920.0;
      return ClockLayerWidget(layer: slideLayer, scale: scale);
    }

    if (layer.kind == 'weather') {
      final slideLayer = SlideLayer(
        id: 'proj-weather',
        label: 'Weather',
        kind: LayerKind.weather,
        role: LayerRole.foreground,
        weatherCity: layer.weatherCity,
        weatherCelsius: layer.weatherCelsius,
        weatherShowCondition: layer.weatherShowCondition,
        weatherShowHumidity: layer.weatherShowHumidity,
        weatherShowWind: layer.weatherShowWind,
        weatherShowFeelsLike: layer.weatherShowFeelsLike,
        textColor: layer.textColor,
        boxColor: layer.boxColor,
        fontFamily: layer.fontFamily,
        fontSize: layer.fontSize,
        isBold: layer.isBold,
        isItalic: layer.isItalic,
        isUnderline: layer.isUnderline,
        align: layer.align,
        boxPadding: layer.boxPadding,
      );
      final scale = stageWidth / 1920.0;
      return WeatherLayerWidget(layer: slideLayer, scale: scale);
    }

    if (layer.kind == 'visualizer') {
      // Visualizer layer - render visualizer widget
      final slideLayer = SlideLayer(
        id: 'proj-visualizer',
        label: 'Visualizer',
        kind: LayerKind.visualizer,
        role: LayerRole.foreground,
        visualizerType: layer.visualizerType,
        visualizerBarCount: layer.visualizerBarCount,
        visualizerSensitivity: layer.visualizerSensitivity,
        visualizerSmoothing: layer.visualizerSmoothing,
        visualizerColor1: layer.visualizerColor1,
        visualizerColor2: layer.visualizerColor2,
        visualizerMirror: layer.visualizerMirror,
        visualizerGlow: layer.visualizerGlow,
        visualizerGlowIntensity: layer.visualizerGlowIntensity,
        visualizerColorMode: layer.visualizerColorMode,
        visualizerLineWidth: layer.visualizerLineWidth,
        visualizerGap: layer.visualizerGap,
        visualizerRadius: layer.visualizerRadius,
        visualizerRotationSpeed: layer.visualizerRotationSpeed,
        visualizerShape: layer.visualizerShape,
        visualizerFilled: layer.visualizerFilled,
        visualizerMinHeight: layer.visualizerMinHeight,
        visualizerFrequencyRange: layer.visualizerFrequencyRange,
        visualizerAudioSource: layer.visualizerAudioSource,
        visualizerPreviewMode: layer.visualizerPreviewMode,
      );
      final scale = stageWidth / 1920.0;
      return VisualizerLayerWidget(layer: slideLayer, scale: scale);
    }

    if (layer.kind == 'media' &&
        layer.mediaType == 'audio' &&
        layer.path != null) {
      // Audio layer - render audio widget
      final slideLayer = SlideLayer(
        id: 'proj-audio',
        label: 'Audio',
        kind: LayerKind.media,
        mediaType: SlideMediaType.audio,
        role: LayerRole.foreground,
        path: layer.path,
        textColor: layer.textColor,
        boxColor: layer.boxColor,
      );
      final scale = stageWidth / 1920.0;
      return AudioLayerWidget(
        layer: slideLayer,
        scale: scale,
        showControls: false,
      );
    }

    if (hasMedia && (layer.kind == 'media' || layer.mediaType != null)) {
      return ForegroundMediaLayer(
        layer: layer,
        stageWidth: stageWidth,
        stageHeight: stageHeight,
        isPlaying: isPlaying,
      );
    }
    if (hasText) {
      return ProjectedTextLayer(
        layer: layer,
        stageWidth: stageWidth,
        stageHeight: stageHeight,
        textStyle: textStyle,
      );
    }
    return const SizedBox.shrink();
  }
}

/// Widget for rendering a live screen capture layer.
/// Screen capture layer for the projection window.
/// Uses static capture (not real-time) to avoid blocking the UI thread.
/// Real-time screen capture would require a separate process or native plugin.
class ScreenCaptureLayer extends StatefulWidget {
  const ScreenCaptureLayer({
    super.key,
    required this.layer,
    required this.stageWidth,
    required this.stageHeight,
  });

  final ProjectionLayer layer;
  final double stageWidth;
  final double stageHeight;

  @override
  State<ScreenCaptureLayer> createState() => _ScreenCaptureLayerState();
}

class _ScreenCaptureLayerState extends State<ScreenCaptureLayer>
    with SingleTickerProviderStateMixin {
  Uint8List? _currentFrame;
  bool _isCapturing = false;
  bool _hasError = false;
  Ticker? _ticker;
  DateTime _lastCaptureTime = DateTime.now();
  int _frameTimeMs = 16; // Target 60fps
  int _missedFrames = 0;

  @override
  void initState() {
    super.initState();
    // Start ticker for 60fps capture
    _ticker = createTicker(_onTick);
    _ticker!.start();
    // Initial capture
    Future.delayed(const Duration(milliseconds: 100), _captureOnce);
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ScreenCaptureLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.layer.path != widget.layer.path ||
        oldWidget.layer.text != widget.layer.text) {
      _currentFrame = null;
      _hasError = false;
      Future.delayed(const Duration(milliseconds: 50), _captureOnce);
    }
  }

  void _onTick(Duration elapsed) {
    if (_isCapturing || !mounted) return;

    // Check if it's time for next frame
    final now = DateTime.now();
    final timeSinceCapture = now.difference(_lastCaptureTime);
    if (timeSinceCapture.inMilliseconds < _frameTimeMs) {
      return; // Not time yet
    }

    _captureOnce();
  }

  Future<void> _captureOnce() async {
    if (_isCapturing || !mounted) return;
    _isCapturing = true;

    final startTime = DateTime.now();

    try {
      final pathValue = widget.layer.path ?? '';
      final captureType = widget.layer.text ?? 'display';

      // Parse hwnd or displayIndex from path
      int? hwnd;
      int? displayIndex;

      if (pathValue.startsWith('hwnd:')) {
        hwnd = int.tryParse(pathValue.substring(5));
      } else if (pathValue.startsWith('display:')) {
        displayIndex = int.tryParse(pathValue.substring(8));
      }

      Uint8List? bytes;

      // Use 320x180 for projection (better quality than dashboard)
      const thumbWidth = 320;
      const thumbHeight = 180;

      switch (captureType) {
        case 'window':
          if (hwnd != null && hwnd > 0) {
            bytes = await DesktopCapture.instance.captureWindow(
              hwnd,
              thumbnailWidth: thumbWidth,
              thumbnailHeight: thumbHeight,
            );
          }
          break;
        case 'display':
          final idx = displayIndex ?? 0;
          bytes = await DesktopCapture.instance.captureDisplay(
            idx,
            thumbnailWidth: thumbWidth,
            thumbnailHeight: thumbHeight,
          );
          break;
        case 'desktop':
        default:
          bytes = await DesktopCapture.instance.captureScreen(
            thumbnailWidth: thumbWidth,
            thumbnailHeight: thumbHeight,
          );
          break;
      }

      if (!mounted) return;

      if (bytes != null && bytes.isNotEmpty) {
        setState(() {
          _currentFrame = bytes;
          _hasError = false;
        });
      } else if (_currentFrame == null) {
        setState(() {
          _hasError = true;
        });
      }

      // Adaptive frame rate based on capture time
      final captureTime = DateTime.now().difference(startTime).inMilliseconds;
      if (captureTime > 25) {
        // Too slow for 60fps, fall back to 30fps
        _frameTimeMs = 33;
        _missedFrames++;
      } else if (_missedFrames == 0 && captureTime < 12) {
        // Fast enough for 60fps
        _frameTimeMs = 16;
      }

      // Reset missed frames counter
      if (_missedFrames > 10) _missedFrames = 0;

      _lastCaptureTime = DateTime.now();
    } catch (e) {
      debugPrint('ScreenCaptureLayer error: $e');
      if (mounted && _currentFrame == null) {
        setState(() {
          _hasError = true;
        });
      }
    } finally {
      _isCapturing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final left = (widget.layer.left ?? 0) * widget.stageWidth;
    final top = (widget.layer.top ?? 0) * widget.stageHeight;
    final width = (widget.layer.width ?? 1) * widget.stageWidth;
    final height = (widget.layer.height ?? 1) * widget.stageHeight;
    final opacity = (widget.layer.opacity ?? 1.0).clamp(0.0, 1.0);

    Widget content;
    if (_hasError) {
      content = Container(
        color: Colors.black87,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.desktop_windows, color: Colors.white38, size: 48),
              SizedBox(height: 8),
              Text(
                'Screen Capture',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    } else if (_currentFrame == null || _currentFrame!.isEmpty) {
      content = Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.screen_share, color: Colors.white38, size: 48),
              SizedBox(height: 8),
              Text(
                'Loading...',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    } else {
      content = Image.memory(
        _currentFrame!,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => Container(
          color: Colors.black,
          child: const Center(
            child: Icon(Icons.error_outline, color: Colors.red, size: 48),
          ),
        ),
      );
    }

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Opacity(
        opacity: opacity,
        child: Container(color: Colors.black, child: content),
      ),
    );
  }
}

/// Widget for rendering a foreground media layer (image or video).
class ForegroundMediaLayer extends StatefulWidget {
  const ForegroundMediaLayer({
    super.key,
    required this.layer,
    required this.stageWidth,
    required this.stageHeight,
    this.isPlaying = false,
  });

  final ProjectionLayer layer;
  final double stageWidth;
  final double stageHeight;
  final bool isPlaying;

  @override
  State<ForegroundMediaLayer> createState() => _ForegroundMediaLayerState();
}

class _ForegroundMediaLayerState extends State<ForegroundMediaLayer> {
  vp.VideoPlayerController? _vpController;
  bool _ready = false;
  bool _hydrating = false;

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  @override
  void didUpdateWidget(covariant ForegroundMediaLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.layer.path != widget.layer.path ||
        oldWidget.layer.mediaType != widget.layer.mediaType) {
      _disposeController();
      _hydrate();
    } else if (oldWidget.isPlaying != widget.isPlaying) {
      // Playing state changed - play or pause video
      _updatePlayState();
    }
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  void _disposeController() {
    _ready = false;
    _hydrating = false;
    final controller = _vpController;
    _vpController = null;
    // Dispose in a microtask to avoid dispose during build
    if (controller != null) {
      Future.microtask(() {
        try {
          controller.dispose();
        } catch (e) {
          debugPrint('proj: foreground video dispose error=$e');
        }
      });
    }
  }

  void _updatePlayState() {
    final controller = _vpController;
    if (controller == null || !controller.value.isInitialized) return;

    if (widget.isPlaying) {
      if (!controller.value.isPlaying) {
        controller.play();
        debugPrint('proj: foreground video started playing');
      }
    } else {
      if (controller.value.isPlaying) {
        controller.pause();
        debugPrint('proj: foreground video paused');
      }
    }
  }

  Future<void> _hydrate() async {
    if (!kEnableProjectionVideo || !kEnableProjectionForegroundVideo) {
      debugPrint('proj: foreground video disabled by config');
      return;
    }

    // Guard against concurrent hydration
    if (_hydrating) return;
    _hydrating = true;

    final layer = widget.layer;
    final path = layer.path;
    final type = layer.mediaType;

    // Only attempt to hydrate VideoPlayerController for local video files
    if (path == null ||
        path.isEmpty ||
        type != 'video' ||
        path.startsWith('yt:') ||
        path.startsWith('ytm:') ||
        path.startsWith('vimeo:') ||
        path.startsWith('http')) {
      _hydrating = false;
      return;
    }

    // Verify file exists before attempting to create controller
    final file = File(path);
    if (!await file.exists()) {
      debugPrint('proj: foreground video file not found path=$path');
      _hydrating = false;
      return;
    }

    debugPrint('proj: hydrate foreground video path=$path (queued)');

    // Use the queue to serialize video initialization
    await VideoInitQueue.instance.enqueue(() async {
      if (!mounted) {
        _hydrating = false;
        return;
      }

      try {
        // Delay to ensure the window surface is ready
        await Future.delayed(const Duration(milliseconds: 300));
        if (!mounted) {
          _hydrating = false;
          return;
        }

        final controller = vp.VideoPlayerController.file(file);
        _vpController = controller;

        // Initialize with timeout
        await controller.initialize().timeout(const Duration(seconds: 10));
        if (!mounted) {
          try {
            controller.dispose();
          } catch (_) {}
          _hydrating = false;
          return;
        }

        await controller.setLooping(true);
        await controller.setVolume(0);
        // Only start playing if isPlaying is true
        if (widget.isPlaying) {
          await controller.play();
          debugPrint('proj: foreground video ready and playing (video_player)');
        } else {
          debugPrint(
            'proj: foreground video ready but paused (isPlaying=false)',
          );
        }
        if (!mounted) {
          try {
            controller.dispose();
          } catch (_) {}
          _hydrating = false;
          return;
        }
        _hydrating = false;
        setState(() => _ready = true);
      } on TimeoutException catch (_) {
        debugPrint(
          'proj: hydrate foreground video timed out; skipping playback',
        );
        _hydrating = false;
        _disposeController();
      } catch (e, st) {
        debugPrint('proj: hydrate foreground video failed error=$e');
        debugPrint('$st');
        _hydrating = false;
        _disposeController();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final layer = widget.layer;
    final path = layer.path;
    if (path == null || path.isEmpty) {
      return const SizedBox.shrink();
    }

    final rect = _rectForLayer(layer);
    final left = rect.left * widget.stageWidth;
    final top = rect.top * widget.stageHeight;
    final width = rect.width * widget.stageWidth;
    final height = rect.height * widget.stageHeight;
    final opacity = (layer.opacity ?? 1.0).clamp(0.0, 1.0);

    // YouTube / YouTube Music
    if (path.startsWith('yt:') || path.startsWith('ytm:')) {
      final videoId = path.split(':').last;
      return Positioned(
        left: left,
        top: top,
        width: width,
        height: height,
        child: Transform.rotate(
          angle: (layer.rotation ?? 0) * (3.1415926535 / 180),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Opacity(
              opacity: opacity,
              child: YoutubePlayer(
                key: ValueKey('yt-proj-$videoId'),
                aspectRatio: 16 / 9,
                controller: YoutubePlayerController.fromVideoId(
                  videoId: videoId,
                  autoPlay: widget.isPlaying,
                  params: const YoutubePlayerParams(
                    mute: false, // Play sound in projection
                    showFullscreenButton: false,
                    showControls: true,
                    playsInline: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Vimeo Placeholder
    if (path.startsWith('vimeo:')) {
      return Positioned(
        left: left,
        top: top,
        width: width,
        height: height,
        child: Transform.rotate(
          angle: (layer.rotation ?? 0) * (3.1415926535 / 180),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Opacity(
              opacity: opacity,
              child: Container(
                color: Colors.black,
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.video_library,
                      color: Colors.blue,
                      size: 48,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Vimeo Video: ${path.split(':').last}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final isImage = layer.mediaType == 'image' || layer.mediaType == null;
    final isNetwork = path.startsWith('http');
    final boxFit = _mapFit(layer.fit);
    Widget content;

    if (isImage) {
      if (isNetwork) {
        content = Image.network(
          path,
          fit: boxFit,
          errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black26),
        );
      } else {
        content = Image.file(
          File(path),
          fit: boxFit,
          errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black26),
        );
      }
    } else if (_vpController != null && _ready) {
      content = FittedBox(
        fit: boxFit,
        child: SizedBox(
          width: _vpController!.value.size.width,
          height: _vpController!.value.size.height,
          child: vp.VideoPlayer(_vpController!),
        ),
      );
    } else {
      content = const ColoredBox(color: Colors.black45);
    }

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Transform.rotate(
        angle: (layer.rotation ?? 0) * (3.1415926535 / 180),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Opacity(opacity: opacity, child: content),
        ),
      ),
    );
  }

  BoxFit _mapFit(String? fit) {
    switch (fit) {
      case 'contain':
        return BoxFit.contain;
      case 'fill':
        return BoxFit.fill;
      case 'fitWidth':
        return BoxFit.fitWidth;
      case 'fitHeight':
        return BoxFit.fitHeight;
      case 'none':
        return BoxFit.none;
      case 'cover':
      default:
        return BoxFit.cover;
    }
  }

  Rect _rectForLayer(ProjectionLayer layer) {
    // Background layers fill the entire stage
    if (layer.role == 'background') {
      return const Rect.fromLTWH(0, 0, 1, 1);
    }
    // Foreground layers use same defaults as dashboard
    const defaultRect = Rect.fromLTWH(0.15, 0.15, 0.6, 0.6);
    final left = (layer.left ?? defaultRect.left).clamp(-0.25, 1.25);
    final top = (layer.top ?? defaultRect.top).clamp(-0.25, 1.25);
    final width = (layer.width ?? defaultRect.width).clamp(0.05, 2.0);
    final height = (layer.height ?? defaultRect.height).clamp(0.05, 2.0);
    return Rect.fromLTWH(left, top, width, height);
  }
}

/// Widget for rendering a projected text layer.
class ProjectedTextLayer extends StatefulWidget {
  const ProjectedTextLayer({
    super.key,
    required this.layer,
    required this.stageWidth,
    required this.stageHeight,
    required this.textStyle,
  });

  final ProjectionLayer layer;
  final double stageWidth;
  final double stageHeight;
  final TextStyle textStyle;

  @override
  State<ProjectedTextLayer> createState() => _ProjectedTextLayerState();
}

class _ProjectedTextLayerState extends State<ProjectedTextLayer> {
  String _resolvedText = '';
  bool _isDynamic = false;

  @override
  void initState() {
    super.initState();
    _updateText();
    if (_isDynamic) {
      TextTokenService().ticker.addListener(_onTick);
    }
  }

  @override
  void didUpdateWidget(covariant ProjectedTextLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.layer.text != widget.layer.text) {
      bool wasDynamic = _isDynamic;
      _updateText();
      if (_isDynamic != wasDynamic) {
        if (_isDynamic) {
          TextTokenService().ticker.addListener(_onTick);
        } else {
          TextTokenService().ticker.removeListener(_onTick);
        }
      }
    }
  }

  @override
  void dispose() {
    if (_isDynamic) {
      TextTokenService().ticker.removeListener(_onTick);
    }
    super.dispose();
  }

  void _onTick() {
    if (mounted) {
      setState(() {
        _resolvedText = TextTokenService().resolve(widget.layer.text ?? '');
      });
    }
  }

  void _updateText() {
    final raw = widget.layer.text ?? '';
    _isDynamic = TextTokenService().hasTokens(raw);
    _resolvedText = _isDynamic ? TextTokenService().resolve(raw) : raw;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.layer.text == null || widget.layer.text!.isEmpty) {
      return const SizedBox.shrink();
    }

    final rect = _rectForLayer(widget.layer);
    final left = rect.left * widget.stageWidth;
    final top = rect.top * widget.stageHeight;
    final width = rect.width * widget.stageWidth;
    final height = rect.height * widget.stageHeight;
    final opacity = (widget.layer.opacity ?? 1.0).clamp(0.0, 1.0);

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Transform.rotate(
        angle: (widget.layer.rotation ?? 0) * (3.1415926535 / 180),
        child: Opacity(
          opacity: opacity,
          child: Container(
            padding: EdgeInsets.all(widget.layer.boxPadding ?? 0),
            decoration: BoxDecoration(
              color: widget.layer.boxColor,
              borderRadius: BorderRadius.circular(
                (widget.layer.boxBorderRadius ?? 0).toDouble(),
              ),
              border: (widget.layer.outlineWidth ?? 0) > 0
                  ? Border.all(
                      color: widget.layer.outlineColor ?? Colors.black,
                      width: widget.layer.outlineWidth ?? 0,
                    )
                  : null,
            ),
            alignment: _textAlignToAlignment(
              widget.layer.align ?? TextAlign.center,
              VerticalAlign.middle,
            ),
            child: LiturgyTextRenderer.build(
              _resolvedText,
              align: widget.layer.align ?? TextAlign.center,
              style: widget.textStyle.copyWith(
                fontSize: widget.layer.fontSize,
                fontFamily: widget.layer.fontFamily,
                color:
                    (widget.layer.textColor ??
                            widget.textStyle.color ??
                            Colors.white)
                        .withOpacity(opacity),
                fontWeight: (widget.layer.isBold ?? false)
                    ? FontWeight.bold
                    : FontWeight.normal,
                fontStyle: (widget.layer.isItalic ?? false)
                    ? FontStyle.italic
                    : FontStyle.normal,
                decoration: (widget.layer.isUnderline ?? false)
                    ? TextDecoration.underline
                    : TextDecoration.none,
                shadows: const [
                  Shadow(
                    color: Colors.black54,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              maxLines: 12,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }

  Rect _rectForLayer(ProjectionLayer layer) {
    if (layer.role == 'background') {
      return const Rect.fromLTWH(0, 0, 1, 1);
    }
    const defaultRect = Rect.fromLTWH(0.15, 0.15, 0.6, 0.6);
    final left = (layer.left ?? defaultRect.left).clamp(-0.25, 1.25);
    final top = (layer.top ?? defaultRect.top).clamp(-0.25, 1.25);
    final width = (layer.width ?? defaultRect.width).clamp(0.05, 2.0);
    final height = (layer.height ?? defaultRect.height).clamp(0.05, 2.0);
    return Rect.fromLTWH(left, top, width, height);
  }

  Alignment _textAlignToAlignment(TextAlign align, VerticalAlign vertical) {
    double x;
    switch (align) {
      case TextAlign.left:
        x = -1;
        break;
      case TextAlign.right:
        x = 1;
        break;
      case TextAlign.center:
      case TextAlign.justify:
      case TextAlign.start:
      case TextAlign.end:
        x = 0;
        break;
    }

    double y;
    switch (vertical) {
      case VerticalAlign.top:
        y = -1;
        break;
      case VerticalAlign.bottom:
        y = 1;
        break;
      case VerticalAlign.middle:
        y = 0;
        break;
    }

    return Alignment(x, y);
  }
}
