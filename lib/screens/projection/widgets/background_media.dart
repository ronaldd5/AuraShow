import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart' as vp;
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

/// Widget for rendering background media (image or video) with filters.
///
/// Supports various image filters like hue rotation, saturation,
/// contrast, brightness, blur, and invert.
class BackgroundMedia extends StatelessWidget {
  const BackgroundMedia({
    super.key,
    required this.path,
    required this.mediaType,
    required this.baseColor,
    this.overlayOpacity = 0.25,
    this.videoController,
    this.videoReady = false,
    this.opacity = 1.0,
    this.hueRotate,
    this.invert,
    this.blur,
    this.brightness,
    this.contrast,
    this.saturate,
  });

  final String? path;
  final String? mediaType;
  final Color baseColor;
  final double overlayOpacity;
  final vp.VideoPlayerController? videoController;
  final bool videoReady;
  final double opacity;
  final double? hueRotate;
  final double? invert;
  final double? blur;
  final double? brightness;
  final double? contrast;
  final double? saturate;

  bool get _isVideo => mediaType == 'video';
  bool get _isImage => mediaType == 'image';

  @override
  Widget build(BuildContext context) {
    final hasPath = path != null && path!.isNotEmpty;
    Widget content = Container(color: baseColor);

    if (hasPath) {
      // YouTube / YouTube Music
      if (path!.startsWith('yt:') || path!.startsWith('ytm:')) {
        final videoId = path!.split(':').last;
        content = YoutubePlayer(
          key: ValueKey('yt-bg-$videoId'),
          aspectRatio: 16 / 9,
          controller: YoutubePlayerController.fromVideoId(
            videoId: videoId,
            autoPlay: true, // Auto-play background videos
            params: const YoutubePlayerParams(
              mute: true, // Mute background videos
              showFullscreenButton: false,
              showControls: false,
              playsInline: true,
            ),
          ),
        );
      }
      // Vimeo Placeholder
      else if (path!.startsWith('vimeo:')) {
        content = Container(
          color: Colors.black,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.video_library, color: Colors.blue, size: 48),
              const SizedBox(height: 8),
              Text(
                'Vimeo Video: ${path!.split(':').last}',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        );
      }
      // Image (Network or File)
      else if (_isImage) {
        if (path!.startsWith('http')) {
          content = Image.network(
            path!,
            fit: BoxFit.cover,
            color: Colors.white.withOpacity(opacity),
            colorBlendMode: BlendMode.modulate,
            errorBuilder: (_, __, ___) => Container(color: baseColor),
          );
        } else {
          content = Image.file(
            File(path!),
            fit: BoxFit.cover,
            color: Colors.white.withOpacity(opacity),
            colorBlendMode: BlendMode.modulate,
            errorBuilder: (_, __, ___) => Container(color: baseColor),
          );
        }
      }
      // Local Video File
      else if (_isVideo && videoController != null && videoReady) {
        content = ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(1 - opacity),
            BlendMode.srcOver,
          ),
          child: SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: videoController!.value.size.width,
                height: videoController!.value.size.height,
                child: vp.VideoPlayer(videoController!),
              ),
            ),
          ),
        );
      }
    }

    final filtered = _applyFilters(content);

    return Stack(
      children: [
        Positioned.fill(child: filtered),
        if (hasPath) Positioned.fill(child: Container(color: Colors.black.withOpacity(overlayOpacity))),
        if (!hasPath) Positioned.fill(child: Container(color: baseColor)),
      ],
    );
  }
  Widget _applyFilters(Widget child) {
    final matrix = _colorMatrix();
    Widget filtered = ColorFiltered(colorFilter: ColorFilter.matrix(matrix), child: child);
    final blurSigma = (blur ?? 0).clamp(0, 40).toDouble();
    if (blurSigma > 0) {
      filtered = ImageFiltered(imageFilter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma), child: filtered);
    }
    return filtered;
  }

  List<double> _colorMatrix() {
    List<double> matrix = _identityMatrix();
    matrix = _matrixMultiply(matrix, _hueMatrix(((hueRotate ?? 0) * math.pi / 180)));
    matrix = _matrixMultiply(matrix, _saturationMatrix(saturate ?? 1));
    matrix = _matrixMultiply(matrix, _contrastMatrix(contrast ?? 1));
    matrix = _matrixMultiply(matrix, _brightnessMatrix(brightness ?? 1));
    final invertAmount = (invert ?? 0).clamp(0, 1).toDouble();
    if (invertAmount > 0) {
      matrix = _lerpMatrix(matrix, _invertMatrix(), invertAmount);
    }
    return matrix;
  }

  List<double> _identityMatrix() => [
        1, 0, 0, 0, 0,
        0, 1, 0, 0, 0,
        0, 0, 1, 0, 0,
        0, 0, 0, 1, 0,
      ];

  List<double> _invertMatrix() => [
        -1, 0, 0, 0, 255,
        0, -1, 0, 0, 255,
        0, 0, -1, 0, 255,
        0, 0, 0, 1, 0,
      ];

  List<double> _saturationMatrix(double s) {
    const rw = 0.2126, gw = 0.7152, bw = 0.0722;
    final inv = 1 - s;
    final r = inv * rw;
    final g = inv * gw;
    final b = inv * bw;
    return [
      r + s, g, b, 0, 0,
      r, g + s, b, 0, 0,
      r, g, b + s, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }

  List<double> _contrastMatrix(double c) {
    final t = (1 - c) * 128;
    return [
      c, 0, 0, 0, t,
      0, c, 0, 0, t,
      0, 0, c, 0, t,
      0, 0, 0, 1, 0,
    ];
  }

  List<double> _brightnessMatrix(double b) {
    final t = 255 * (b - 1);
    return [
      1, 0, 0, 0, t,
      0, 1, 0, 0, t,
      0, 0, 1, 0, t,
      0, 0, 0, 1, 0,
    ];
  }

  List<double> _hueMatrix(double radians) {
    final cosA = math.cos(radians);
    final sinA = math.sin(radians);
    const lumR = 0.213;
    const lumG = 0.715;
    const lumB = 0.072;
    return [
      lumR + cosA * (1 - lumR) + sinA * (-lumR), lumG + cosA * (-lumG) + sinA * (-lumG), lumB + cosA * (-lumB) + sinA * (1 - lumB), 0, 0,
      lumR + cosA * (-lumR) + sinA * 0.143, lumG + cosA * (1 - lumG) + sinA * 0.14, lumB + cosA * (-lumB) + sinA * -0.283, 0, 0,
      lumR + cosA * (-lumR) + sinA * (-(1 - lumR)), lumG + cosA * (-lumG) + sinA * lumG, lumB + cosA * (1 - lumB) + sinA * lumB, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }

  List<double> _lerpMatrix(List<double> a, List<double> b, double t) {
    final out = <double>[];
    for (var i = 0; i < a.length; i++) {
      out.add(a[i] + (b[i] - a[i]) * t);
    }
    return out;
  }

  List<double> _matrixMultiply(List<double> a, List<double> b) {
    List<double> result = List.filled(20, 0);
    for (var row = 0; row < 4; row++) {
      for (var col = 0; col < 5; col++) {
        result[row * 5 + col] =
            a[row * 5] * b[col] +
            a[row * 5 + 1] * b[5 + col] +
            a[row * 5 + 2] * b[10 + col] +
            a[row * 5 + 3] * b[15 + col] +
            (col == 4 ? a[row * 5 + 4] : 0);
      }
    }
    return result;
  }
}
