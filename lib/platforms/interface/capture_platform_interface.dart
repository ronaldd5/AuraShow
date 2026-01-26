import 'dart:async';

/// Defines the mode of audio capture.
enum AudioCaptureMode {
  loopback,   // System audio (what you hear)
  microphone, // Input audio (what you say)
}

/// Data packet containing frequency info.
class AudioCaptureData {
  final List<double> frequencies;
  AudioCaptureData(this.frequencies);
}

/// The contract that both Mac and Windows implementations must follow.
abstract class CapturePlatform {
  /// The stream of audio frequency data.
  Stream<AudioCaptureData> get audioDataStream;

  /// Starts capturing audio in the specified mode.
  /// Returns true if started successfully.
  Future<bool> startCapture({
    required AudioCaptureMode mode,
    String? deviceId,
  });

  /// Stops the current capture session.
  Future<void> stopCapture();
}