/// WASAPI Capture implementation using Win32 FFI
library;

import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

const int AUDCLNT_STREAMFLAGS_LOOPBACK = 0x00020000;

class WasapiCapture {
  Pointer<COMObject>? _audioClient;
  Pointer<COMObject>? _captureClient;
  bool _isInitialized = false;
  bool _isCapturing = false;
  int _frameSize = 0;

  /// Initialize WASAPI capture
  Future<bool> initialize({String? deviceId, bool isLoopback = false}) async {
    // 1. Initialize COM (MTA is preferred for audio threads)
    // Note: If calling from an Isolate that already initialized COM,
    // this might return RPC_E_CHANGED_MODE, which is fine to ignore.
    var hr = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
    if (FAILED(hr) && hr != RPC_E_CHANGED_MODE) {
      return false;
    }

    try {
      // 2. Create Device Enumerator
      final enumeratorPtr = calloc<COMObject>();
      hr = CoCreateInstance(
        GUIDFromString(CLSID_MMDeviceEnumerator),
        nullptr,
        CLSCTX_ALL,
        GUIDFromString(IID_IMMDeviceEnumerator),
        enumeratorPtr.cast(),
      );

      if (FAILED(hr)) {
        free(enumeratorPtr);
        return false;
      }

      final enumerator = MMDeviceEnumerator(enumeratorPtr);
      final devicePtr = calloc<COMObject>();

      // 3. Get Device
      if (deviceId != null &&
          deviceId != 'system_loopback' &&
          deviceId != 'app_audio') {
        // Get specific device
        final deviceIdPtr = deviceId.toNativeUtf16();
        hr = enumerator.getDevice(deviceIdPtr, devicePtr.cast());
        free(deviceIdPtr);
      } else {
        // Get default device
        // If loopback, we want the *Render* device (speakers) to capture from.
        // If mic, we want the *Capture* device.
        final dataFlow = isLoopback ? EDataFlow.eRender : EDataFlow.eCapture;
        hr = enumerator.getDefaultAudioEndpoint(
          dataFlow,
          ERole.eConsole,
          devicePtr.cast(),
        );
      }

      enumerator.release();
      free(enumeratorPtr);

      if (FAILED(hr)) {
        free(devicePtr);
        return false;
      }

      final device = IMMDevice(devicePtr);

      // 4. Activate Audio Client
      final audioClientPtr = calloc<COMObject>();
      hr = device.activate(
        GUIDFromString(IID_IAudioClient),
        CLSCTX_ALL,
        nullptr,
        audioClientPtr.cast(),
      );

      device.release(); // Done with device
      free(devicePtr);

      if (FAILED(hr)) {
        free(audioClientPtr);
        return false;
      }

      _audioClient = audioClientPtr;
      final audioClient = IAudioClient(audioClientPtr);

      // 5. Get Mix Format
      final mixFormatPtr = calloc<Pointer<WAVEFORMATEX>>();
      hr = audioClient.getMixFormat(mixFormatPtr);
      if (FAILED(hr)) {
        free(mixFormatPtr);
        return false;
      }

      final mixFormat = mixFormatPtr.value;
      _frameSize = mixFormat.ref.nBlockAlign;

      // 6. Initialize Audio Client
      // AUDCLNT_STREAMFLAGS_LOOPBACK = 0x00020000
      var streamFlags = 0;
      if (isLoopback) {
        streamFlags |= AUDCLNT_STREAMFLAGS_LOOPBACK;
      }

      // Initialize shared mode
      hr = audioClient.initialize(
        AUDCLNT_SHAREMODE.AUDCLNT_SHAREMODE_SHARED,
        streamFlags,
        10000000, // buffer duration (1 sec in 100ns units)
        0, // periodicity
        mixFormat,
        nullptr,
      );

      CoTaskMemFree(mixFormatPtr.value);
      free(mixFormatPtr);

      if (FAILED(hr)) {
        return false;
      }

      // 7. Get Capture Client
      final captureClientPtr = calloc<COMObject>();
      hr = audioClient.getService(
        GUIDFromString(IID_IAudioCaptureClient),
        captureClientPtr.cast(),
      );

      if (FAILED(hr)) {
        free(captureClientPtr);
        return false;
      }

      _captureClient = captureClientPtr;
      _isInitialized = true;
      return true;
    } catch (e) {
      // Clean up if exception
      dispose();
      return false;
    }
  }

  /// Start capture
  bool start() {
    if (!_isInitialized || _audioClient == null) return false;

    final audioClient = IAudioClient(_audioClient!);
    final hr = audioClient.start();
    if (SUCCEEDED(hr)) {
      _isCapturing = true;
      return true;
    }
    return false;
  }

  /// Stop capture
  void stop() {
    if (_isCapturing && _audioClient != null) {
      final audioClient = IAudioClient(_audioClient!);
      audioClient.stop();
      _isCapturing = false;
    }
  }

  /// Read available frames
  /// Returns List<double> (normalized -1.0 to 1.0)
  List<double>? readFrames() {
    if (!_isCapturing || _captureClient == null) return null;

    final captureClient = IAudioCaptureClient(_captureClient!);
    final packetLengthPtr = calloc<UINT32>();
    var hr = captureClient.getNextPacketSize(packetLengthPtr);

    if (FAILED(hr)) {
      free(packetLengthPtr);
      return null;
    }

    final packetLength = packetLengthPtr.value;
    free(packetLengthPtr);

    if (packetLength == 0) return []; // No data

    final bufferPtr = calloc<Pointer<BYTE>>();
    final numFramesAvailablePtr = calloc<UINT32>();
    final flagsPtr = calloc<DWORD>();

    hr = captureClient.getBuffer(
      bufferPtr,
      numFramesAvailablePtr,
      flagsPtr,
      nullptr, // posPtr
      nullptr, // qpcPtr
    );

    if (FAILED(hr)) {
      free(bufferPtr);
      free(numFramesAvailablePtr);
      free(flagsPtr);
      return null;
    }

    final numFrames = numFramesAvailablePtr.value;
    final flags = flagsPtr.value;
    final buffer = bufferPtr.value;

    List<double> result;

    if ((flags & AUDCLNT_BUFFERFLAGS.AUDCLNT_BUFFERFLAGS_SILENT) != 0) {
      // Silence
      result = List.filled(numFrames, 0.0);
    } else {
      // Parse as Float32 (Standard for WASAPI Shared Mode)
      // Each frame contains _frameSize bytes (e.g. 4 bytes * channels)
      // We only read the first channel for simplicity if stereo, or mix?
      // Or return all samples flat?
      // Win32AudioCaptureService expects flat list of samples.

      // Assume Float32 (IEEE Float)
      // Check _frameSize. If stereo (2 channels * 4 bytes = 8 bytes).
      // If we just return all float samples:
      final floatCount = numFrames * (_frameSize ~/ 4);
      final floats = buffer.cast<Float>().asTypedList(floatCount);
      result = floats.toList();
    }

    // Release buffer
    captureClient.releaseBuffer(numFrames);

    free(bufferPtr);
    free(numFramesAvailablePtr);
    free(flagsPtr);

    return result;
  }

  /// Dispose resources
  Future<void> dispose() async {
    stop();

    if (_captureClient != null) {
      final client = IAudioCaptureClient(_captureClient!);
      client.release();
      free(_captureClient!);
      _captureClient = null;
    }

    if (_audioClient != null) {
      final client = IAudioClient(_audioClient!);
      client.release();
      free(_audioClient!);
      _audioClient = null;
    }

    _isInitialized = false;
  }
}
