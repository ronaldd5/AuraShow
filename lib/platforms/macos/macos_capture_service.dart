import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'; // Required for EventChannel
import 'package:screen_capturer/screen_capturer.dart';
import 'package:screen_retriever/screen_retriever.dart';
import '../interface/capture_platform_interface.dart';

class MacosCaptureService implements CapturePlatform {
  final _audioController = StreamController<AudioCaptureData>.broadcast();

  // 1. Define the Native Bridge Channel
  static const EventChannel _audioChannel = EventChannel(
    'com.aurashow.audio/capture',
  );
  StreamSubscription? _audioSubscription;

  @override
  Stream<AudioCaptureData> get audioDataStream => _audioController.stream;

  @override
  Future<bool> startCapture({
    required AudioCaptureMode mode,
    String? deviceId,
  }) async {
    try {
      // Cleanup previous subscription if exists
      await _audioSubscription?.cancel();

      // 2. Listen to the Swift Native Stream
      _audioSubscription = _audioChannel.receiveBroadcastStream().listen(
        (event) {
          if (event is List) {
            // Convert dynamic list from Swift to Float32List for Dart
            final List<double> samples = event
                .map((e) => (e as num).toDouble())
                .toList();

            // FIX IS HERE: Removed "samples:" label.
            // We pass the data directly as a positional argument.
            _audioController.add(
              AudioCaptureData(Float32List.fromList(samples)),
            );
          }
        },
        onError: (error) {
          debugPrint("Mac Audio Capture Error: $error");
        },
      );

      return true; // Return true because we are now successfully listening!
    } catch (e) {
      debugPrint("Failed to start Mac audio capture: $e");
      return false;
    }
  }

  @override
  Future<void> stopCapture() async {
    // 3. Stop listening when requested
    await _audioSubscription?.cancel();
    _audioSubscription = null;
  }

  // --- Real Screen Capture Implementation ---

  @override
  Future<List<WindowInfo>> getWindows({bool refresh = false}) async {
    // macOS sandbox restricts listing other apps' windows.
    return [];
  }

  @override
  Future<List<DisplayInfo>> getDisplays({bool refresh = false}) async {
    try {
      final displays = await ScreenRetriever.instance.getAllDisplays().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          debugPrint("MacosCaptureService: getAllDisplays timed out");
          throw TimeoutException("getAllDisplays timed out");
        },
      );
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
    try {
      final captured = await ScreenCapturer.instance
          .capture(
            mode: CaptureMode.screen,
            imagePath: null, // Return bytes
            silent: true,
          )
          .timeout(const Duration(seconds: 5));
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
    try {
      final captured = await ScreenCapturer.instance
          .capture(mode: CaptureMode.screen, silent: true)
          .timeout(const Duration(seconds: 5));
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
    return null;
  }
}
