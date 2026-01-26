import 'dart:io';
import '../platforms/interface/audio_service_interface.dart';
import '../platforms/windows/wasapi_audio_service.dart';
import '../platforms/macos/core_audio_service.dart';

export '../platforms/interface/audio_service_interface.dart';

class AudioDeviceService {
  AudioDeviceService._();

  static AudioService? _instance;

  static AudioService get instance {
    if (_instance != null) return _instance!;

    if (Platform.isWindows) {
      _instance = WindowsAudioService();
    } else if (Platform.isMacOS) {
      _instance = MacosAudioService();
    } else {
      // Fallback stub for other platforms
      _instance = MacosAudioService();
    }

    return _instance!;
  }
}
