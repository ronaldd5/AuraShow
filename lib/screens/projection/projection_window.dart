import 'dart:convert';
import 'dart:io';
import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:win32/win32.dart' as win32;

import '../../core/theme/palette.dart';
import 'models/projection_slide.dart';
import 'projection_constants.dart';
import 'widgets/styled_slide.dart';
import 'widgets/legacy_slide_surface.dart';
import 'widgets/stage_display_slide.dart';
import 'widgets/slide_transition_engine.dart';
import '../dashboard/models/stage_models.dart';

/// Secondary projection window for displaying slides on external displays.
class ProjectionWindow extends StatefulWidget {
  final int windowId;
  final Map initialData;
  const ProjectionWindow({
    super.key,
    required this.windowId,
    required this.initialData,
  });

  @override
  State<ProjectionWindow> createState() => _ProjectionWindowState();
}

class _ProjectionWindowState extends State<ProjectionWindow> {
  ProjectionSlide? slide;
  ProjectionSlide? nextSlide;
  StageLayout? stageLayout;
  String content = '';
  String? imagePath;
  TextAlign alignment = TextAlign.center;
  Map<String, dynamic>? outputConfig;
  bool layerBackgroundActive = true;
  bool layerForegroundMediaActive = true;
  bool layerSlideActive = true;
  bool layerOverlayActive = true;
  bool layerAudioActive = true;
  bool layerTimerActive = true;
  bool outputLocked = false;
  bool isPlaying = false;
  String transitionName = 'fade';
  Duration transitionDuration = const Duration(milliseconds: 600);
  int viewVersion = 0;

  // Video sync
  int videoPositionMs = 0;
  String? syncedVideoPath;

  // Stage Timer
  DateTime? stageTimerTarget;
  Duration stageTimerDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _applyProjectionState(Map<String, dynamic>.from(widget.initialData));

    // Initialize headless styling
    _initWindowStyling();

    try {
      DesktopMultiWindow.setMethodHandler((call, fromWindowId) async {
        if (call.method == "updateContent" || call.method == "updateSlide") {
          final data = _coerceProjectionPayload(call.arguments);
          if (data != null && mounted) {
            setState(() => _applyProjectionState(data));
          }
        }
        return null;
      });
    } catch (e) {
      debugPrint('proj: setMethodHandler failed error=$e');
    }
  }

  Map<String, dynamic>? _coerceProjectionPayload(dynamic payload) {
    if (payload == null) return null;
    try {
      if (payload is String) {
        if (payload.isEmpty) return null;
        return Map<String, dynamic>.from(json.decode(payload) as Map);
      }
      if (payload is Map) {
        return Map<String, dynamic>.from(payload);
      }
    } catch (_) {}
    return null;
  }

  void _applyProjectionState(Map data) {
    if (data['clear'] == true) {
      slide = null;
      nextSlide = null;
      stageLayout = null;
      outputConfig = null;
      content = '';
      imagePath = null;
      alignment = TextAlign.center;
      layerBackgroundActive = false;
      layerForegroundMediaActive = false;
      layerSlideActive = false;
      layerOverlayActive = false;
      layerAudioActive = false;
      layerTimerActive = false;
      outputLocked = false;
      isPlaying = false;
      viewVersion++;
      return;
    }

    final state = data['state'] as Map?;
    if (state != null) {
      final layers = state['layers'] as Map?;
      layerBackgroundActive = layers?['background'] ?? true;
      layerForegroundMediaActive = layers?['foregroundMedia'] ?? true;
      layerSlideActive = layers?['slide'] ?? true;
      layerOverlayActive = layers?['overlay'] ?? true;
      layerAudioActive = layers?['audio'] ?? true;
      layerTimerActive = layers?['timer'] ?? true;
      outputLocked = state['locked'] ?? false;
      isPlaying = state['isPlaying'] ?? false;
      transitionName = state['transition'] ?? transitionName;
      if (state['transitionDuration'] is int) {
        transitionDuration = Duration(
          milliseconds: state['transitionDuration'],
        );
      }
      videoPositionMs = state['videoPositionMs'] ?? 0;
      syncedVideoPath = state['videoPath'] as String?;
    }

    if (data['stageTimerTarget'] != null) {
      stageTimerTarget = DateTime.tryParse(data['stageTimerTarget']);
    } else {
      stageTimerTarget = null;
    }
    if (data['stageTimerDuration'] != null) {
      stageTimerDuration = Duration(seconds: data['stageTimerDuration']);
    }

    if (data['slide'] is Map) {
      slide = ProjectionSlide.fromJson(
        Map<String, dynamic>.from(data['slide'] as Map),
      );
    } else {
      slide = null;
    }

    if (data['nextSlide'] is Map) {
      nextSlide = ProjectionSlide.fromJson(
        Map<String, dynamic>.from(data['nextSlide'] as Map),
      );
      if (nextSlide!.mediaType == 'video' &&
          (nextSlide!.mediaPath?.isNotEmpty ?? false)) {
        StyledSlide.preload(nextSlide!.mediaPath!);
      }
    } else {
      nextSlide = null;
    }

    if (data['stageLayout'] is Map) {
      stageLayout = StageLayout.fromJson(
        Map<String, dynamic>.from(data['stageLayout'] as Map),
      );
    } else {
      stageLayout = null;
    }

    if (data['output'] is Map) {
      outputConfig = Map<String, dynamic>.from(data['output'] as Map);
    } else {
      outputConfig = null;
    }

    content = data['content'] ?? "";
    final rawImagePath = data['imagePath'];
    imagePath = (rawImagePath is String && rawImagePath.isNotEmpty)
        ? rawImagePath
        : null;
    String alignStr = data['alignment'] ?? "center";
    alignment = TextAlign.values.firstWhere(
      (e) => e.name == alignStr,
      orElse: () => TextAlign.center,
    );

    viewVersion++;
  }

  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Request focus aggressively
    if (!_focusNode.hasFocus) {
      _focusNode.requestFocus();
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (event) async {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            debugPrint('proj: ESC pressed (KeyboardListener), closing window');
            try {
              // Notify main window before closing
              await DesktopMultiWindow.invokeMethod(0, 'outputClosed', {
                'windowId': widget.windowId,
              });
              await WindowController.fromWindowId(widget.windowId).close();
            } catch (e) {
              debugPrint('proj: error closing window: $e');
            }
          }
        },
        child: Scaffold(
          backgroundColor: (outputConfig?['transparent'] == true)
              ? Colors.transparent
              : AppPalette.carbonBlack,
          body: SlideTransitionEngine(
            duration: transitionDuration,
            transitionType: transitionName,
            child: KeyedSubtree(
              key: ValueKey<int>(viewVersion),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final slideSurface = slide != null
                      ? StyledSlide(
                          stageWidth: kStageWidth,
                          stageHeight: kStageHeight,
                          slide: slide!,
                          output: outputConfig,
                          backgroundActive: layerBackgroundActive,
                          foregroundMediaActive: layerForegroundMediaActive,
                          slideActive: layerSlideActive,
                          overlayActive: layerOverlayActive,
                          isPlaying: isPlaying,
                          videoPositionMs: videoPositionMs,
                          volume:
                              (layerAudioActive &&
                                  (outputConfig?['ndiAudio'] ?? true))
                              ? 1.0
                              : 0.0,
                        )
                      : LegacySlideSurface(
                          stageWidth: kStageWidth,
                          stageHeight: kStageHeight,
                          content: content,
                          alignment: alignment,
                          imagePath: imagePath,
                          output: outputConfig,
                          backgroundActive: layerBackgroundActive,
                          slideActive: layerSlideActive,
                          overlayActive: layerOverlayActive,
                        );

                  final isStageMode =
                      outputConfig?['styleProfile'] == 'stageNotes' &&
                      stageLayout != null;
                  final displayWidget = isStageMode
                      ? StageDisplaySlide(
                          layout: stageLayout!,
                          currentSlide: slide,
                          nextSlide: nextSlide,
                          timerTarget: stageTimerTarget,
                          timerDuration: stageTimerDuration,
                          stageWidth: kStageWidth,
                          stageHeight: kStageHeight,
                        )
                      : slideSurface;

                  return Center(
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: kStageWidth,
                        height: kStageHeight,
                        child: displayWidget,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Native Window Styling (Headless/Borderless) ---

  Future<void> _initWindowStyling() async {
    // Native styling is now handled in C++ (flutter_window.cpp)
    // trying to do it here caused race conditions.
  }
}
