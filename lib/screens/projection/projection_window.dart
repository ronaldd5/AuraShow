import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import '../../core/theme/palette.dart';
import 'models/projection_slide.dart';
import 'projection_constants.dart';
import 'widgets/styled_slide.dart';
import 'widgets/legacy_slide_surface.dart';

/// Secondary projection window for displaying slides on external displays.
///
/// This widget runs in a separate Flutter engine/window and receives
/// slide content from the primary dashboard via IPC method calls.
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
  int viewVersion = 0;

  @override
  void initState() {
    super.initState();
    debugPrint(
      'proj: _ProjectionWindowState initState, setting up method handler',
    );
    _applyProjectionState(Map<String, dynamic>.from(widget.initialData));

    try {
      DesktopMultiWindow.setMethodHandler((call, fromWindowId) async {
        debugPrint(
          'proj: method ${call.method} from=$fromWindowId payloadType=${call.arguments.runtimeType}',
        );
        if (call.method == "updateContent" || call.method == "updateSlide") {
          final data = _coerceProjectionPayload(call.arguments);
          if (data != null && mounted) {
            debugPrint('proj: applying projection payload keys=${data.keys}');
            setState(() => _applyProjectionState(data));
          }
        }
        // Note: Window closing is handled by the main window, not here
        return null;
      });
      debugPrint('proj: method handler set up successfully');
    } catch (e, st) {
      debugPrint('proj: setMethodHandler failed error=$e');
      debugPrint('$st');
    }
  }

  Map<String, dynamic>? _coerceProjectionPayload(dynamic payload) {
    if (payload == null) return null;
    try {
      if (payload is String) {
        if (payload.isEmpty) return null;
        debugPrint('proj: decode payload string length=${payload.length}');
        return Map<String, dynamic>.from(json.decode(payload) as Map);
      }
      if (payload is Map) {
        debugPrint('proj: decode payload map keys=${payload.keys}');
        return Map<String, dynamic>.from(payload);
      }
    } catch (_) {
      // Ignore malformed payloads; caller will remain unchanged.
    }
    return null;
  }

  void _applyProjectionState(Map data) {
    // Prefer rich slide payload; fallback to legacy text-only payload.
    if (data['clear'] == true) {
      debugPrint('proj: received clear payload');
      slide = null;
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
      transitionName = 'fade';
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
    }

    if (data['slide'] is Map) {
      debugPrint('proj: received slide payload');
      slide = ProjectionSlide.fromJson(
        Map<String, dynamic>.from(data['slide'] as Map),
      );
      debugPrint(
        'proj: parsed slide mediaPath=${slide?.mediaPath} mediaType=${slide?.mediaType}',
      );
    } else {
      slide = null;
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppPalette.carbonBlack,
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 600),
          transitionBuilder: (child, animation) {
            switch (transitionName) {
              case 'slide':
                final offsetTween = Tween<Offset>(
                  begin: const Offset(0.08, 0),
                  end: Offset.zero,
                );
                return SlideTransition(
                  position: offsetTween.animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
                  child: child,
                );
              case 'none':
                return child;
              case 'fade':
              default:
                return FadeTransition(opacity: animation, child: child);
            }
          },
          child: KeyedSubtree(
            key: ValueKey<int>(viewVersion),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Render a fixed stage surface and scale to fit so proportions match the editor preview.
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
                      );

                return Center(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: kStageWidth,
                      height: kStageHeight,
                      child: slideSurface,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
