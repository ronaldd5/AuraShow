import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:screen_capturer/screen_capturer.dart';
import 'package:screen_retriever/screen_retriever.dart';
import '../interface/capture_platform_interface.dart';

class MacosCaptureService implements CapturePlatform {
  final _audioController = StreamController<AudioCaptureData>.broadcast();

  @override
  Stream<AudioCaptureData> get audioDataStream => _audioController.stream;

  @override
  Future<bool> startCapture({
    required AudioCaptureMode mode,
    String? deviceId,
  }) async {
    // Note: True system audio capture on macOS requires a custom kernel extension (like BlackHole).
    // For a Flutter app without custom drivers, we can only simulate audio or capture Microphone.
    // For now, we return false for Loopback to trigger the visualizer's "Simulation Mode" fallback,
    // which looks better than a flat line.
    return false;
  }

  @override
  Future<void> stopCapture() async {
    // Cleanup if we add real mic capture later
  }

  // --- Real Screen Capture Implementation ---

  @override
  Future<List<WindowInfo>> getWindows({bool refresh = false}) async {
    // macOS sandbox restricts listing other apps' windows.
    // We return empty to prevent crashes, as standard plugins can't do this yet.
    return [];
  }

  @override
  Future<List<DisplayInfo>> getDisplays({bool refresh = false}) async {
    try {
      final displays = await ScreenRetriever.instance.getAllDisplays();
      return displays.asMap().entries.map((entry) {
        final i = entry.key;
        final display = entry.value;
        final size = display.size ?? const Size(0, 0);
        final pos = display.visiblePosition ?? Offset.zero;

        return DisplayInfo(
          handle: i,
          name: display.name ?? "Display $i",
          left: pos.dx.toInt(),
          top: pos.dy.toInt(),
          width: size.width.toInt(),
          height: size.height.toInt(),
          isPrimary: i == 0, // Fallback assumption
        );
      }).toList();
    } catch (e) {
      debugPrint("MacosCaptureService: Error getting displays: $e");
      return [
        DisplayInfo(
          handle: 0,
          name: "Main Display",
          left: 0,
          top: 0,
          width: 1920,
          height: 1080,
          isPrimary: true,
        ),
      ];
    }
  }

  @override
  Future<Uint8List?> captureDisplay(
    int displayIndex, {
    int thumbnailWidth = 320,
    int thumbnailHeight = 180,
  }) async {
    // REAL implementation using screen_capturer
    try {
      final captured = await ScreenCapturer.instance.capture(
        mode: CaptureMode.screen,
        imagePath: null, // Return bytes
        silent: true,
      );
      return captured?.imageBytes;
    } catch (e) {
      print("Mac Capture Error: $e");
      return null;
    }
  }

  @override
  Future<Uint8List?> captureScreen({
    int thumbnailWidth = 320,
    int thumbnailHeight = 180,
  }) async {
    // REAL implementation
    try {
      final captured = await ScreenCapturer.instance.capture(
        mode: CaptureMode.screen,
        silent: true,
      );
      return captured?.imageBytes;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<Uint8List?> captureWindow(
    int hwnd, {
    int thumbnailWidth = 320,
    int thumbnailHeight = 180,
  }) async {
    // Window capture is not supported on macOS due to security restrictions
    return null;
  }
}
