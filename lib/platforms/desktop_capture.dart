import 'dart:io';

import 'interface/capture_platform_interface.dart';

import 'windows/windows_capture_service.dart'
    if (dart.library.io) 'windows/windows_capture_service.dart';
import 'macos/macos_capture_service.dart'
    if (dart.library.io) 'macos/macos_capture_service.dart';

/// Facade for Desktop Capture
/// Returns the platform-specific implementation
class DesktopCapture {
  DesktopCapture._();

  static CapturePlatform get instance {
    if (Platform.isWindows) {
      return WindowsCaptureService();
    } else if (Platform.isMacOS) {
      return MacosCaptureService();
    }
    // Fallback stub for other platforms
    return MacosCaptureService();
  }
}
