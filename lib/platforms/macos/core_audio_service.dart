import 'dart:async';
import '../interface/audio_service_interface.dart';

class MacosAudioService implements AudioService {
  final _devicesController = StreamController<List<AudioDevice>>.broadcast();
  @override
  Stream<List<AudioDevice>> get devicesStream => _devicesController.stream;

  final List<AudioDevice> _devices = [];
  @override
  List<AudioDevice> get devices => List.unmodifiable(_devices);

  @override
  Future<void> initialize() async {
    await refreshDevices();
  }

  @override
  void dispose() {
    _devicesController.close();
  }

  @override
  Future<void> refreshDevices() async {
    final newDevices = <AudioDevice>[
      AudioDevice(
        id: 'system_loopback',
        name: 'System Audio (Default Output)',
        type: AudioDeviceType.loopback,
        isDefault: true,
      ),
      AudioDevice(
        id: 'app_audio',
        name: 'App Audio (Music Player)',
        type: AudioDeviceType.loopback,
      ),
    ];

    _devices
      ..clear()
      ..addAll(newDevices);

    if (!_devicesController.isClosed) {
      _devicesController.add(_devices);
    }
  }

  @override
  AudioDevice? getDevice(String id) {
    for (final d in _devices) {
      if (d.id == id) return d;
    }
    return null;
  }

  @override
  AudioDevice? getDefaultDevice(AudioDeviceType type) {
    for (final d in _devices) {
      if (d.type == type && d.isDefault) return d;
    }
    for (final d in _devices) {
      if (d.type == type) return d;
    }
    return null;
  }
}
