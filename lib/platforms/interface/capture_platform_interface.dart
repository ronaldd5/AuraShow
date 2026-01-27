import 'dart:async';
import 'dart:typed_data';

enum AudioCaptureMode { loopback, microphone }

class AudioCaptureData {
  final List<double> frequencies;
  AudioCaptureData(this.frequencies);
}

class WindowInfo {
  final int hwnd;
  final String title;
  final String processName;
  final String className;
  final bool isVisible;

  WindowInfo({
    required this.hwnd,
    required this.title,
    required this.processName,
    required this.className,
    this.isVisible = true,
  });
}

class DisplayInfo {
  final int handle;
  final String name;
  final int left;
  final int top;
  final int width;
  final int height;
  final bool isPrimary;

  DisplayInfo({
    required this.handle,
    required this.name,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.isPrimary,
  });
}

abstract class CapturePlatform {
  // Audio
  Stream<AudioCaptureData> get audioDataStream;
  Future<bool> startCapture({required AudioCaptureMode mode, String? deviceId});
  Future<void> stopCapture();

  // Video/Screen
  Future<List<WindowInfo>> getWindows({bool refresh = false});
  Future<List<DisplayInfo>> getDisplays({bool refresh = false});

  Future<Uint8List?> captureWindow(
    int hwnd, {
    int thumbnailWidth = 320,
    int thumbnailHeight = 180,
  });
  Future<Uint8List?> captureDisplay(
    int displayIndex, {
    int thumbnailWidth = 320,
    int thumbnailHeight = 180,
  });
  Future<Uint8List?> captureScreen({
    int thumbnailWidth = 320,
    int thumbnailHeight = 180,
  });
}
