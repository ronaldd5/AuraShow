import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Service for managing video thumbnail cache
/// Works with video player to capture and cache first frames
class VideoThumbnailService {
  static final Map<String, Uint8List?> _thumbnailCache = {};
  static final Map<String, bool> _isGenerating = {};

  /// Get cached thumbnail for a video path
  static Uint8List? getCachedThumbnail(String videoPath) {
    return _thumbnailCache[videoPath];
  }

  /// Check if thumbnail exists in cache
  static bool hasCachedThumbnail(String videoPath) {
    return _thumbnailCache.containsKey(videoPath) &&
        _thumbnailCache[videoPath] != null;
  }

  /// Check if thumbnail is currently being generated
  static bool isGenerating(String videoPath) {
    return _isGenerating[videoPath] ?? false;
  }

  /// Mark thumbnail as being generated
  static void markGenerating(String videoPath) {
    _isGenerating[videoPath] = true;
  }

  /// Store a thumbnail for a video path
  static void cacheThumbnail(String videoPath, Uint8List thumbnail) {
    _thumbnailCache[videoPath] = thumbnail;
    _isGenerating.remove(videoPath);
  }

  /// Mark thumbnail generation as failed
  static void markFailed(String videoPath) {
    _isGenerating.remove(videoPath);
    // Cache null to indicate we tried and failed
    _thumbnailCache[videoPath] = null;
  }

  /// Clear thumbnail cache (useful when videos are deleted/modified)
  static void clearCache([String? specificPath]) {
    if (specificPath != null) {
      _thumbnailCache.remove(specificPath);
      _isGenerating.remove(specificPath);
    } else {
      _thumbnailCache.clear();
      _isGenerating.clear();
    }
  }

  /// Capture screenshot from a widget using RepaintBoundary
  static Future<Uint8List?> captureWidget(GlobalKey key) async {
    try {
      // Wait for post-frame callback to ensure rendering is complete
      await Future.delayed(const Duration(milliseconds: 100));

      // Use a Completer to wait for the actual frame to be rendered
      final completer = Completer<void>();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        completer.complete();
      });
      await completer.future;

      // Additional delay for video frame buffering
      await Future.delayed(const Duration(milliseconds: 150));

      final RenderRepaintBoundary? boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;

      if (boundary == null) {
        debugPrint('VideoThumbnail: RepaintBoundary not found');
        return null;
      }

      // Check if the boundary still needs to paint - if so, we can't capture yet
      if (boundary.debugNeedsPaint) {
        debugPrint('VideoThumbnail: Widget still needs paint, waiting...');
        await Future.delayed(const Duration(milliseconds: 200));
        // Try one more time after waiting
        if (boundary.debugNeedsPaint) {
          debugPrint(
            'VideoThumbnail: Widget still painting after wait, skipping capture',
          );
          return null;
        }
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('VideoThumbnail: Failed to capture screenshot: $e');
      return null;
    }
  }
}
