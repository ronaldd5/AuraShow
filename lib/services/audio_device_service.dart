import 'dart:io';
import '../platforms/interface/audio_service_interface.dart';
import '../platforms/windows/wasapi_audio_service.dart' deferred as win;
import '../platforms/macos/core_audio_service.dart' deferred as mac;

export '../platforms/interface/audio_service_interface.dart';

class AudioDeviceService {
  AudioDeviceService._();

  static AudioService? _instance;

  static AudioService get instance {
    if (_instance == null) {
      throw StateError(
        'AudioDeviceService must be initialized before use. Call await AudioDeviceService.initialize()',
      );
    }
    return _instance!;
  }

  static Future<void> initialize() async {
    if (_instance != null) return;

    if (Platform.isWindows) {
      await win.loadLibrary();
      _instance = win.WindowsAudioService();
    } else if (Platform.isMacOS) {
      await mac.loadLibrary();
      _instance = mac.MacosAudioService();
    } else {
      // Fallback stub for other platforms
      await mac.loadLibrary();
      _instance = mac.MacosAudioService();
    }

    await _instance!.initialize();
  }
}
