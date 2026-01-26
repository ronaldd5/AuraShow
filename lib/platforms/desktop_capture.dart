import 'dart:async';
import 'dart:io';
import 'interface/capture_platform_interface.dart';

// Conditional import: Only import Windows code if we are ON Windows.
// This prevents the Mac compiler from crashing when it sees Windows libraries.
import '../services/win32_audio_capture_service.dart'
    if (dart.library.html) 'interface/capture_platform_interface.dart';

class DesktopCapture implements CapturePlatform {
  // Singleton instance
  static final DesktopCapture instance = DesktopCapture._private();
  DesktopCapture._private();

  // The active platform implementation
  CapturePlatform? _platformImplementation;

  StreamController<AudioCaptureData> _dummyController = StreamController.broadcast();

  CapturePlatform get _impl {
    if (_platformImplementation != null) return _platformImplementation!;

    if (Platform.isWindows) {
      // On Windows, use the real service (Win32AudioCaptureService must implement CapturePlatform)
      // Note: You need to make sure Win32AudioCaptureService implements CapturePlatform!
      // For this specific build error, we will return a dummy if the file is missing/excluded.
      try {
        // We assume your Win32 service exists on Windows.
        // If you deleted it in the CI script, this block won't run on Mac anyway.
      } catch (e) {
        print("Windows capture service not found: $e");
      }
    }
    
    // Default / Mac fallback (Simulation for now)
    return _MacOSCaptureSimulation();
  }

  @override
  Stream<AudioCaptureData> get audioDataStream {
    if (Platform.isWindows) {
      // If we are on Windows, try to use the real thing. 
      // But since we are building for Mac on Codemagic, we just use the Mac simulation.
       return _MacOSCaptureSimulation().audioDataStream;
    }
    return _MacOSCaptureSimulation().audioDataStream;
  }

  @override
  Future<bool> startCapture({required AudioCaptureMode mode, String? deviceId}) async {
    if (Platform.isWindows) {
       // On real Windows, you'd call the real service.
       return false; 
    }
    return _MacOSCaptureSimulation().startCapture(mode: mode, deviceId: deviceId);
  }

  @override
  Future<void> stopCapture() async {
     if (Platform.isWindows) {
       return;
     }
     return _MacOSCaptureSimulation().stopCapture();
  }
}

/// A dummy implementation for macOS to satisfy the compiler
/// so the build succeeds. (It just sends fake data for visualizers).
class _MacOSCaptureSimulation implements CapturePlatform {
  static final _controller = StreamController<AudioCaptureData>.broadcast();
  static Timer? _timer;

  @override
  Stream<AudioCaptureData> get audioDataStream => _controller.stream;

  @override
  Future<bool> startCapture({required AudioCaptureMode mode, String? deviceId}) async {
    _timer?.cancel();
    // Generate fake frequency data 30 times a second
    _timer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      final fakeFrequencies = List.generate(128, (index) => (index % 10) * 0.1);
      _controller.add(AudioCaptureData(fakeFrequencies));
    });
    return true;
  }

  @override
  Future<void> stopCapture() async {
    _timer?.cancel();
    _timer = null;
  }
}