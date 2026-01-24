/// Stub for WASAPI Capture (non-Windows)
library;

class WasapiCapture {
  Future<bool> initialize({String? deviceId, bool isLoopback = false}) async =>
      false;
  bool start() => false;
  void stop() {}
  List<double>? readFrames() => null;
  Future<void> dispose() async {}
}
