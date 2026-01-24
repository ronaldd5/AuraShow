import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart' as vp;
import '../../../core/theme/palette.dart';
import '../models/projection_slide.dart';
import '../projection_constants.dart';
import 'background_media.dart';
import 'projected_layer.dart';
import '../../projection/widgets/scripture_display.dart';
import '../../../core/utils/liturgy_renderer.dart';

/// Widget for rendering a fully-styled slide with all layers.
///
/// This is the main rendering widget for projection slides,
/// handling background media, text styling, and foreground layers.
class StyledSlide extends StatefulWidget {
  const StyledSlide({
    super.key,
    required this.stageWidth,
    required this.stageHeight,
    required this.slide,
    this.output,
    this.backgroundActive = true,
    this.foregroundMediaActive = true,
    this.slideActive = true,
    this.overlayActive = true,
    this.isPlaying = false,
    this.videoPositionMs = 0,
    this.volume = 1.0,
  });

  final double stageWidth;
  final double stageHeight;
  final ProjectionSlide slide;
  final Map<String, dynamic>? output;
  final bool backgroundActive;
  final bool foregroundMediaActive;
  final bool slideActive;
  final bool overlayActive;
  final bool isPlaying;
  final double volume;

  /// Video position in milliseconds for synchronized playback
  final int videoPositionMs;

  @override
  State<StyledSlide> createState() => _StyledSlideState();

  // Cache for preloaded video controllers
  static final Map<String, vp.VideoPlayerController> _preloaded = {};

  /// Preloads a video controller for the given path.
  static Future<void> preload(String path) async {
    if (path.isEmpty) return;
    if (_preloaded.containsKey(path)) return; // Already preloaded

    // Enforce cache limit (max 2 preloaded videos) to prevent memory bloat
    if (_preloaded.length >= 2) {
      final oldestPath = _preloaded.keys.first;
      final oldController = _preloaded.remove(oldestPath);
      await oldController?.dispose();
      debugPrint('proj: preload cache full, disposed oldest=$oldestPath');
    }

    final file = File(path);
    if (!await file.exists()) return;

    debugPrint('proj: preloading video path=$path');
    try {
      final controller = vp.VideoPlayerController.file(file);
      // We don't initialize here to save memory/resources until needed?
      // No, we must initialize to be "ready".
      // But we shouldn't play.
      await controller.initialize();
      await controller.setLooping(true);
      _preloaded[path] = controller;
      debugPrint('proj: preload complete path=$path');
    } catch (e) {
      debugPrint('proj: preload failed for $path: $e');
    }
  }
}

class _StyledSlideState extends State<StyledSlide> {
  vp.VideoPlayerController? _vpController;
  bool _videoReady = false;
  int _currentHydrationId = 0;

  @override
  void initState() {
    super.initState();
    debugPrint(
      'proj: _StyledSlideState initState called, mediaPath=${widget.slide.mediaPath} mediaType=${widget.slide.mediaType}',
    );
    _hydrateVideo();
  }

  @override
  void didUpdateWidget(covariant StyledSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldPath = oldWidget.slide.mediaPath;
    final newPath = widget.slide.mediaPath;
    final oldType = oldWidget.slide.mediaType;
    final newType = widget.slide.mediaType;
    final oldPlaying = oldWidget.isPlaying;
    final newPlaying = widget.isPlaying;
    final oldPositionMs = oldWidget.videoPositionMs;
    final newPositionMs = widget.videoPositionMs;
    final oldVolume = oldWidget.volume;
    final newVolume = widget.volume;

    if (oldPath != newPath || oldType != newType) {
      debugPrint('proj: media changed, re-hydrating video');
      _disposeVideo();
      _hydrateVideo();
    } else if (oldPlaying != newPlaying) {
      // Playing state changed - play or pause video
      _updatePlayState();
    } else if (newPlaying && (newPositionMs - oldPositionMs).abs() > 500) {
      // Position changed significantly while playing - re-sync
      _updatePlayState();
    } else if (oldVolume != newVolume) {
      _vpController?.setVolume(newVolume);
    }
  }

  @override
  void dispose() {
    _disposeVideo();
    super.dispose();
  }

  void _disposeVideo() {
    _currentHydrationId++; // Invalidate pending hydrations
    _videoReady = false;
    _vpController?.dispose();
    _vpController = null;
  }

  void _updatePlayState() async {
    final controller = _vpController;
    if (controller == null || !controller.value.isInitialized) return;

    if (widget.isPlaying) {
      // Seek to synced position before playing for frame-accurate sync
      if (widget.videoPositionMs > 0) {
        final syncPosition = Duration(milliseconds: widget.videoPositionMs);
        final currentPos = controller.value.position;
        final drift = (syncPosition - currentPos).abs();
        // Only seek if drift is > 500ms to avoid constant seeking
        if (drift > const Duration(milliseconds: 500)) {
          debugPrint(
            'proj: syncing video position to ${widget.videoPositionMs}ms (drift=${drift.inMilliseconds}ms)',
          );
          await controller.seekTo(syncPosition);
        }
      }
      if (!controller.value.isPlaying) {
        controller.play();
        debugPrint('proj: background video started playing');
      }
    } else {
      if (controller.value.isPlaying) {
        controller.pause();
        debugPrint('proj: background video paused');
      }
    }
  }

  Future<void> _hydrateVideo() async {
    final hydrationId = ++_currentHydrationId;
    debugPrint(
      'proj: _hydrateVideo called id=$hydrationId, kEnableProjectionVideo=$kEnableProjectionVideo',
    );
    if (!kEnableProjectionVideo) {
      debugPrint(
        'proj: background video disabled (AURASHOW_ENABLE_PROJECTION_VIDEO=false)',
      );
      return;
    }
    final path = widget.slide.mediaPath;
    final type = widget.slide.mediaType;
    debugPrint('proj: _hydrateVideo checking path=$path type=$type');
    if (path == null || path.isEmpty || type != 'video') {
      debugPrint(
        'proj: _hydrateVideo skipping - path null/empty or type!=video',
      );
      return;
    }

    // Check if the same video exists as a foreground layer
    // This prevents double-initialization of video players for the same file, which can crash the app
    final hasDuplicateForeground = widget.slide.layers.any(
      (l) =>
          l.role == 'foreground' &&
          l.path == path &&
          (l.mediaType == 'video' || type == 'video'),
    );

    if (hasDuplicateForeground) {
      debugPrint(
        'proj: skipping background video hydration - duplicate found in foreground layers',
      );
      return;
    }

    // Verify file exists before attempting to create controller
    final file = File(path);
    if (!await file.exists()) {
      debugPrint('proj: background video file not found path=$path');
      return;
    }

    if (hydrationId != _currentHydrationId) return;

    debugPrint('proj: hydrate background video path=$path id=$hydrationId');

    // Use the queue to serialize video initialization
    await VideoInitQueue.instance.enqueue(() async {
      if (!mounted || hydrationId != _currentHydrationId) return;

      try {
        vp.VideoPlayerController? controller;

        // Check preloaded cache first
        if (StyledSlide._preloaded.containsKey(path)) {
          debugPrint('proj: using preloaded controller for path=$path');
          controller = StyledSlide._preloaded.remove(path);
          // Skip the 300ms delay for preloaded content
        } else {
          // Delay to allow the secondary engine/window to finish its first frame (only for fresh loads)
          await Future.delayed(const Duration(milliseconds: 300));
          if (!mounted || hydrationId != _currentHydrationId) return;

          controller = vp.VideoPlayerController.file(file);
          await controller.initialize().timeout(const Duration(seconds: 8));
        }

        if (controller == null) return; // Should not happen

        _vpController = controller;

        if (!mounted || hydrationId != _currentHydrationId) {
          try {
            // Only dispose if we created it or took ownership
            controller.dispose();
          } catch (_) {}
          return;
        }

        if (!controller.value.isInitialized) {
          // Fallback if preloaded but not init (unlikely) or just created
          // If we came from preload, it should be init.
        }

        await controller.setLooping(true);
        await controller.setVolume(widget.volume);

        // Check again before playing
        if (hydrationId != _currentHydrationId) {
          try {
            controller.dispose();
          } catch (_) {}
          return;
        }

        // Only start playing if isPlaying is true
        if (widget.isPlaying) {
          await controller.play();
          debugPrint('proj: background video ready and playing (video_player)');
        } else {
          debugPrint(
            'proj: background video ready but paused (isPlaying=false)',
          );
        }

        if (!mounted || hydrationId != _currentHydrationId) {
          try {
            controller.dispose();
          } catch (_) {}
          return;
        }
        setState(() => _videoReady = true);
      } on TimeoutException catch (_) {
        debugPrint(
          'proj: hydrate background video timed out; skipping playback',
        );
        if (hydrationId == _currentHydrationId) _disposeVideo();
      } catch (e, st) {
        debugPrint('proj: hydrate background video failed error=$e');
        debugPrint('$st');
        if (hydrationId == _currentHydrationId) _disposeVideo();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final slide = widget.slide;
    final stageWidth = widget.stageWidth;
    final stageHeight = widget.stageHeight;
    final output = widget.output;
    final backgroundActive = widget.backgroundActive;
    final foregroundMediaActive = widget.foregroundMediaActive;
    final slideActive = widget.slideActive;
    final overlayActive = widget.overlayActive;

    final allLayers = slide.layers;
    final backgroundLayers = allLayers
        .where(
          (l) =>
              l.role == 'background' &&
              ((l.path?.isNotEmpty ?? false) || (l.text?.isNotEmpty ?? false)),
        )
        .toList();
    // Foreground layers - filter based on visibility:
    // - Media layers: show if foregroundMediaActive
    // - Textbox layers: show if slideActive
    final foregroundLayers = allLayers
        .where(
          (l) =>
              l.role == 'foreground' &&
              ((l.path?.isNotEmpty ?? false) || (l.text?.isNotEmpty ?? false)),
        )
        .where((l) {
          if (l.kind == 'textbox') {
            return slideActive;
          }
          // Media layers (image/video) controlled by foregroundMediaActive
          return foregroundMediaActive;
        })
        .toList();

    // Check if there's a textbox layer - if so, don't show the default slide text box
    final hasTextboxLayer = allLayers.any(
      (l) => l.kind == 'textbox' && (l.text?.isNotEmpty ?? false),
    );
    final showDefaultTextbox =
        slideActive && !hasTextboxLayer && slide.body.trim().isNotEmpty;

    final align = slide.alignOverride ?? slide.templateAlign;
    final baseFontSize = slide.fontSizeOverride ?? slide.templateFontSize;
    final fontWeight = (slide.isBold ?? true)
        ? FontWeight.w700
        : FontWeight.w400;
    final fontStyle = (slide.isItalic ?? false)
        ? FontStyle.italic
        : FontStyle.normal;
    final decoration = (slide.isUnderline ?? false)
        ? TextDecoration.underline
        : TextDecoration.none;
    final height = (slide.lineHeight ?? 1.3).clamp(0.6, 3.0);
    final letterSpacing = (slide.letterSpacing ?? 0).clamp(-2.0, 10.0);

    final String? styleProfile = output?['styleProfile'] as String?;
    final bool isStageNotes =
        styleProfile == 'stageNotes' || (output?['stageNotes'] == true);
    final double lowerThirdHeight =
        (output?['lowerThirdHeight'] as num?)?.toDouble() ?? 0.32;
    final bool lowerThirdGradient = output?['lowerThirdGradient'] == true;
    final double stageNotesScale =
        (output?['stageNotesScale'] as num?)?.toDouble() ?? 0.9;
    final double textScale = (output?['textScale'] as num?)?.toDouble() ?? 1.0;
    final int maxLines = (output?['maxLines'] as num?)?.toInt() ?? 12;
    final textColor = slide.textColorOverride ?? slide.templateTextColor;

    final rect = _resolvedBoxRect(slide);
    double boxLeft = rect.left * stageWidth;
    double boxTop = rect.top * stageHeight;
    double boxWidth = rect.width * stageWidth;
    double boxHeight = rect.height * stageHeight;

    if (styleProfile == 'streamLowerThird') {
      final double heightFraction = lowerThirdHeight.clamp(0.1, 0.6);
      boxTop = stageHeight * (1 - heightFraction) + 12;
      boxHeight = stageHeight * heightFraction - 24;
    }

    final double scaledFontSize = baseFontSize * textScale;
    final double stageNotesFactor = isStageNotes ? stageNotesScale * 0.8 : 1.0;
    final textStyle = TextStyle(
      color: textColor,
      fontSize: scaledFontSize * stageNotesFactor,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      height: height,
      fontFamily: slide.fontFamilyOverride,
      letterSpacing: letterSpacing,
      decoration: decoration,
      decorationColor: textColor,
      shadows: _textShadows(slide),
    );

    final bgPath = slide.mediaPath;

    // Check for redundancy in build method as well
    final hasDuplicateForeground = slide.layers.any(
      (l) =>
          l.role == 'foreground' &&
          l.path == bgPath &&
          (l.mediaType == 'video' || slide.mediaType == 'video'),
    );

    final effectiveBackgroundActive =
        backgroundActive && !hasDuplicateForeground;
    final baseBgColor = slide.backgroundColor ?? slide.templateBackground;

    return Stack(
      children: [
        BackgroundMedia(
          path: effectiveBackgroundActive ? bgPath : null,
          mediaType: slide.mediaType,
          baseColor: effectiveBackgroundActive
              ? baseBgColor
              : AppPalette.carbonBlack,
          overlayOpacity: 0.25,
          videoController: _vpController,
          videoReady: _videoReady,
          opacity: (slide.mediaOpacity ?? 1.0).clamp(0.0, 1.0),
          hueRotate: slide.hueRotate,
          invert: slide.invert,
          blur: slide.blur,
          brightness: slide.brightness,
          contrast: slide.contrast,
          saturate: slide.saturate,
        ),
        // Background layers from the editor canvas
        for (final layer in backgroundLayers)
          ProjectedLayer(
            layer: layer,
            stageWidth: stageWidth,
            stageHeight: stageHeight,
            textStyle: textStyle,
            isPlaying: widget.isPlaying,
          ),
        if (backgroundActive &&
            styleProfile == 'streamLowerThird' &&
            lowerThirdGradient)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppPalette.carbonBlack.withOpacity(0.0),
                    AppPalette.carbonBlack.withOpacity(0.45),
                  ],
                ),
              ),
            ),
          ),
        // Render foreground media layers
        for (final layer in foregroundLayers)
          ProjectedLayer(
            layer: layer,
            stageWidth: stageWidth,
            stageHeight: stageHeight,
            textStyle: textStyle,
            isPlaying: widget.isPlaying,
          ),
        if (foregroundLayers.any((l) => l.kind == 'scripture'))
          for (final layer in foregroundLayers.where(
            (l) => l.kind == 'scripture',
          ))
            Positioned(
              left: (layer.left ?? 0) * stageWidth,
              top: (layer.top ?? 0) * stageHeight,
              width: (layer.width ?? 1) * stageWidth,
              height: (layer.height ?? 1) * stageHeight,
              child: ScriptureDisplay(
                text: layer.text ?? '',
                reference: layer.scriptureReference ?? '',
                highlightedIndices: layer.highlightedIndices ?? [],
                fontSize: layer.fontSize ?? 50,
                textColor: layer.textColor ?? Colors.white,
                fontFamily: layer.fontFamily ?? 'Roboto',
                textAlign: layer.align ?? TextAlign.center,
              ),
            ),
        if (showDefaultTextbox)
          Positioned(
            left: boxLeft,
            top: boxTop,
            width: boxWidth,
            height: boxHeight,
            child: Transform.rotate(
              angle: (slide.rotation ?? 0) * (3.1415926535 / 180),
              child: Container(
                padding: EdgeInsets.all(
                  ((slide.boxPadding ?? 8).clamp(0, 48)).toDouble(),
                ),
                alignment: _textAlignToAlignment(align),
                decoration: BoxDecoration(
                  color:
                      slide.boxBackgroundColor ??
                      AppPalette.carbonBlack.withOpacity(0.26),
                  borderRadius: BorderRadius.circular(
                    (slide.boxBorderRadius ?? 0).toDouble(),
                  ),
                ),
                child: LiturgyTextRenderer.build(
                  _applyTransform(slide.body, slide.textTransform),
                  align: align,
                  style: textStyle,
                  maxLines: maxLines.clamp(1, 24).toInt(),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        if (overlayActive)
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppPalette.willowGreen.withOpacity(0.85),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Overlay',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ),
      ],
    );
  }

  static Rect _resolvedBoxRect(ProjectionSlide slide) {
    const defaultBox = Rect.fromLTWH(0.1, 0.18, 0.8, 0.64);
    final left = slide.boxLeft ?? defaultBox.left;
    final top = slide.boxTop ?? defaultBox.top;
    final width = slide.boxWidth ?? defaultBox.width;
    final height = slide.boxHeight ?? defaultBox.height;
    return Rect.fromLTWH(left, top, width, height);
  }

  static Alignment _textAlignToAlignment(TextAlign align) {
    switch (align) {
      case TextAlign.left:
        return Alignment.centerLeft;
      case TextAlign.right:
        return Alignment.centerRight;
      case TextAlign.center:
      default:
        return Alignment.center;
    }
  }

  static String _applyTransform(String text, String? transform) {
    switch (transform) {
      case 'uppercase':
        return text.toUpperCase();
      case 'lowercase':
        return text.toLowerCase();
      case 'title':
        return text
            .split(' ')
            .map(
              (w) => w.isEmpty
                  ? w
                  : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}',
            )
            .join(' ');
      case 'none':
      default:
        return text;
    }
  }

  static List<Shadow> _textShadows(ProjectionSlide slide) {
    final shadows = <Shadow>[];
    final blur = (slide.shadowBlur ?? 0).clamp(0, 24).toDouble();
    final offsetX = (slide.shadowOffsetX ?? 0).clamp(-24, 24).toDouble();
    final offsetY = (slide.shadowOffsetY ?? 0).clamp(-24, 24).toDouble();
    final shadowColor = (slide.shadowColor ?? AppPalette.carbonBlack)
        .withOpacity(0.9);
    if (blur > 0 || offsetX != 0 || offsetY != 0) {
      shadows.add(
        Shadow(
          color: shadowColor,
          blurRadius: blur,
          offset: Offset(offsetX, offsetY),
        ),
      );
    }

    final outlineWidth = (slide.outlineWidth ?? 0).clamp(0, 8).toDouble();
    final outlineColor = slide.outlineColor ?? AppPalette.carbonBlack;
    if (outlineWidth > 0) {
      final step = outlineWidth;
      for (double dx = -outlineWidth; dx <= outlineWidth; dx += step) {
        for (double dy = -outlineWidth; dy <= outlineWidth; dy += step) {
          if (dx == 0 && dy == 0) continue;
          shadows.add(
            Shadow(
              color: outlineColor.withOpacity(0.9),
              offset: Offset(dx, dy),
              blurRadius: 0,
            ),
          );
        }
      }
    }

    return shadows;
  }
}
