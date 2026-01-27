import 'dart:io';
import 'dart:typed_data';
import 'interface/capture_platform_interface.dart';

// Import implementations deferred to isolate platform-specific dependencies
import 'windows/windows_capture_service.dart' deferred as win;
import 'macos/macos_capture_service.dart' deferred as mac;

export 'interface/capture_platform_interface.dart';

class DesktopCapture implements CapturePlatform {
  static final DesktopCapture instance = DesktopCapture._private();
  DesktopCapture._private();

  CapturePlatform? _platformImpl;

  /// Private helper to get implementation.
  /// Note: The service methods below will need to handle the case where it's not loaded.
  CapturePlatform get _impl {
    if (_platformImpl == null) {
      // For synchronous access we need it pre-loaded or use a fallback.
      // In this app, we should call initialize() at startup.
      throw StateError(
        'DesktopCapture must be initialized before use. Call await DesktopCapture.instance.initialize()',
      );
    }
    return _platformImpl!;
  }

  /// Initialize the correct platform implementation.
  /// This must be called at app startup to use deferred loading.
  Future<void> initialize() async {
    if (_platformImpl != null) return;

    if (Platform.isWindows) {
      await win.loadLibrary();
      _platformImpl = win.WindowsCaptureService();
    } else if (Platform.isMacOS) {
      await mac.loadLibrary();
      _platformImpl = mac.MacosCaptureService();
    } else {
      await mac.loadLibrary();
      _platformImpl = mac.MacosCaptureService(); // Fallback
    }
  }

  @override
  Stream<AudioCaptureData> get audioDataStream => _impl.audioDataStream;

  @override
  Future<bool> startCapture({
    required AudioCaptureMode mode,
    String? deviceId,
  }) {
    return _impl.startCapture(mode: mode, deviceId: deviceId);
  }

  @override
  Future<void> stopCapture() => _impl.stopCapture();

  @override
  Future<List<WindowInfo>> getWindows({bool refresh = false}) =>
      _impl.getWindows(refresh: refresh);

  @override
  Future<List<DisplayInfo>> getDisplays({bool refresh = false}) =>
      _impl.getDisplays(refresh: refresh);

  @override
  Future<Uint8List?> captureWindow(
    int hwnd, {
    int thumbnailWidth = 320,
    int thumbnailHeight = 180,
  }) {
    return _impl.captureWindow(
      hwnd,
      thumbnailWidth: thumbnailWidth,
      thumbnailHeight: thumbnailHeight,
    );
  }

  @override
  Future<Uint8List?> captureDisplay(
    int displayIndex, {
    int thumbnailWidth = 320,
    int thumbnailHeight = 180,
  }) {
    return _impl.captureDisplay(
      displayIndex,
      thumbnailWidth: thumbnailWidth,
      thumbnailHeight: thumbnailHeight,
    );
  }

  @override
  Future<Uint8List?> captureScreen({
    int thumbnailWidth = 320,
    int thumbnailHeight = 180,
  }) {
    return _impl.captureScreen(
      thumbnailWidth: thumbnailWidth,
      thumbnailHeight: thumbnailHeight,
    );
  }
}
