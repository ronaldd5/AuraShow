import 'dart:typed_data';

import '../interface/capture_platform_interface.dart';

/// macOS Capture Service Stub
/// TODO: Implement using native macOS APIs (ScreenCaptureKit or similar)
class MacosCaptureService implements CapturePlatform {
  @override
  List<WindowInfo> getWindows({bool refresh = false}) {
    // Return empty list or mocks for now
    return [];
  }

  @override
  List<DisplayInfo> getDisplays({bool refresh = false}) {
    // Return empty list or mocks
    // DeviceService might fallback to screen_retriever which works on Mac
    return [];
  }

  @override
  Uint8List? captureWindow(
    int hwnd, {
    int thumbnailWidth = 320,
    int thumbnailHeight = 180,
  }) {
    return null;
  }

  @override
  Uint8List? captureDisplay(
    int displayIndex, {
    int thumbnailWidth = 320,
    int thumbnailHeight = 180,
  }) {
    // On Mac, we rely on alternative methods or return null
    return null;
  }

  @override
  Uint8List? captureScreen({
    int thumbnailWidth = 320,
    int thumbnailHeight = 180,
  }) {
    return null;
  }
}
