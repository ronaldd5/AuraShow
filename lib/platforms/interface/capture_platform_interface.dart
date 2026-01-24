import 'dart:typed_data';

/// Common Window Info
class WindowInfo {
  WindowInfo({
    required this.hwnd,
    required this.title,
    required this.processName,
    required this.className,
    this.isVisible = true,
  });

  final int hwnd;
  final String title;
  final String processName;
  final String className;
  final bool isVisible;

  @override
  String toString() => 'WindowInfo(hwnd: $hwnd, title: $title)';
}

/// Common Display Info
class DisplayInfo {
  DisplayInfo({
    required this.handle,
    required this.name,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.isPrimary,
  });

  final int handle;
  final String name;
  final int left;
  final int top;
  final int width;
  final int height;
  final bool isPrimary;
}

/// Abstract Interface for Desktop Capture
abstract class CapturePlatform {
  List<WindowInfo> getWindows({bool refresh = false});
  List<DisplayInfo> getDisplays({bool refresh = false});

  Uint8List? captureWindow(
    int hwnd, {
    int thumbnailWidth = 320,
    int thumbnailHeight = 180,
  });

  Uint8List? captureDisplay(
    int displayIndex, {
    int thumbnailWidth = 320,
    int thumbnailHeight = 180,
  });

  Uint8List? captureScreen({
    int thumbnailWidth = 320,
    int thumbnailHeight = 180,
  });
}
