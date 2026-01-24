/// Stub for Audio Device Service (non-Windows)
library;

import 'dart:async';

/// Represents an audio device (input or output)
class AudioDevice {
  AudioDevice({
    required this.id,
    required this.name,
    required this.type,
    this.isDefault = false,
  });

  final String id;
  final String name;
  final AudioDeviceType type;
  final bool isDefault;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioDevice &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Type of audio device
enum AudioDeviceType {
  output, // Speakers, headphones, etc.
  input, // Microphones, line-in, etc.
  loopback, // System audio capture (pseudo-device)
}

/// Service Stub
class AudioDeviceService {
  AudioDeviceService._();
  static final AudioDeviceService instance = AudioDeviceService._();

  final _devicesController = StreamController<List<AudioDevice>>.broadcast();
  Stream<List<AudioDevice>> get devicesStream => _devicesController.stream;

  final List<AudioDevice> _devices = [];
  List<AudioDevice> get devices => List.unmodifiable(_devices);

  List<AudioDevice> get outputs => [];
  List<AudioDevice> get inputs => [];
  List<AudioDevice> get loopbacks => [];

  Future<void> initialize() async {}
  void dispose() {
    _devicesController.close();
  }

  Future<void> refreshDevices() async {}

  AudioDevice? getDevice(String id) => null;
  AudioDevice? getDefaultDevice(AudioDeviceType type) => null;
}
