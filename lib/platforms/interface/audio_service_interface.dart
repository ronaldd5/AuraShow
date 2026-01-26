import 'dart:async';

enum AudioDeviceType { output, input, loopback }

class AudioDevice {
  final String id;
  final String name;
  final AudioDeviceType type;
  final bool isDefault;

  AudioDevice({
    required this.id,
    required this.name,
    required this.type,
    this.isDefault = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioDevice &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

abstract class AudioService {
  Stream<List<AudioDevice>> get devicesStream;
  List<AudioDevice> get devices;

  Future<void> initialize();
  Future<void> refreshDevices();
  void dispose();

  AudioDevice? getDevice(String id);
  AudioDevice? getDefaultDevice(AudioDeviceType type);
}
