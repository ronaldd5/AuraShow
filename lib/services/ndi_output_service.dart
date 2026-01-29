// NDI Output Service for AuraShow
// Provides NDI streaming capability using FFI bindings to NewTek NDI SDK
//
// Requirements:
// 1. Download NDI SDK from https://ndi.video/download-ndi-sdk/
// 2. Place Processing.NDI.Lib.x64.dll in windows/runner/
// 3. Place libndi.dylib in macos/Runner.app/Contents/Frameworks/

import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'ndi_bindings.dart';

/// NDI frame format
enum NdiFrameFormat {
  uyvy, // Standard NDI format
  bgra, // BGRA with alpha (for transparency)
  rgba, // RGBA with alpha
}

/// NDI Output Service
///
/// Streams Flutter UI content over NDI network protocol.
/// Supports alpha channel for transparent overlays.
class NdiOutputService {
  static NdiOutputService? _instance;
  static NdiOutputService get instance => _instance ??= NdiOutputService._();

  NdiOutputService._();

  bool _isInitialized = false;
  bool _isStreaming = false;
  String _sourceName = 'AuraShow';
  int _frameWidth = 1920;
  int _frameHeight = 1080;
  int _frameRateNumerator = 30000;
  int _frameRateDenominator = 1001; // 29.97fps NTSC

  // FFI handles (will be initialized when SDK is loaded)
  ffi.DynamicLibrary? _ndiLib;
  ffi.Pointer<ffi.Void>? _ndiSendInstance;

  // Frame timing
  Timer? _frameTimer;
  int _frameCount = 0;

  /// Whether NDI is currently streaming
  bool get isStreaming => _isStreaming;

  /// Current source name visible to NDI receivers
  String get sourceName => _sourceName;

  /// Whether NDI SDK is loaded and ready
  bool get isInitialized => _isInitialized;

  /// Initialize the NDI SDK
  ///
  /// Must be called before starting a stream.
  /// Returns false if SDK files are not found.
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Platform-specific library loading
      if (Platform.isWindows) {
        final dllPath = _findNdiLibrary('Processing.NDI.Lib.x64.dll');
        if (dllPath == null) {
          debugPrint('[NDI] Error: Processing.NDI.Lib.x64.dll not found');
          debugPrint(
            '[NDI] Download NDI SDK from https://ndi.video/download-ndi-sdk/',
          );
          return false;
        }
        _ndiLib = ffi.DynamicLibrary.open(dllPath);
      } else if (Platform.isMacOS) {
        final dylibPath = _findNdiLibrary('libndi.dylib');
        if (dylibPath == null) {
          debugPrint('[NDI] Error: libndi.dylib not found');
          debugPrint(
            '[NDI] Download NDI SDK from https://ndi.video/download-ndi-sdk/',
          );
          return false;
        }
        _ndiLib = ffi.DynamicLibrary.open(dylibPath);
      } else {
        debugPrint('[NDI] Platform not supported: ${Platform.operatingSystem}');
        return false;
      }

      // Initialize NDI runtime
      final initResult = _callNdiInitialize();
      if (!initResult) {
        debugPrint('[NDI] Failed to initialize NDI runtime');
        return false;
      }

      _isInitialized = true;
      debugPrint('[NDI] SDK initialized successfully');
      return true;
    } catch (e) {
      debugPrint('[NDI] Initialization error: $e');
      return false;
    }
  }

  /// Start streaming with the given source name
  Future<bool> startStream({
    String sourceName = 'AuraShow',
    int width = 1920,
    int height = 1080,
    double frameRate = 30.0,
  }) async {
    if (_isStreaming) {
      debugPrint('[NDI] Already streaming');
      return true;
    }

    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return false;
    }

    _sourceName = sourceName;
    _frameWidth = width;
    _frameHeight = height;

    // Convert frame rate to numerator/denominator
    if (frameRate == 29.97) {
      _frameRateNumerator = 30000;
      _frameRateDenominator = 1001;
    } else if (frameRate == 59.94) {
      _frameRateNumerator = 60000;
      _frameRateDenominator = 1001;
    } else {
      _frameRateNumerator = (frameRate * 1000).round();
      _frameRateDenominator = 1000;
    }

    try {
      _ndiSendInstance = _createNdiSender(_sourceName);
      if (_ndiSendInstance == null || _ndiSendInstance == ffi.nullptr) {
        debugPrint('[NDI] Failed to create sender');
        return false;
      }

      _isStreaming = true;
      _frameCount = 0;
      debugPrint(
        '[NDI] Started streaming as "$_sourceName" (${_frameWidth}x$_frameHeight @ ${frameRate}fps)',
      );
      return true;
    } catch (e) {
      debugPrint('[NDI] Start stream error: $e');
      return false;
    }
  }

  /// Send a frame to NDI receivers
  ///
  /// [pixels] - BGRA pixel data (with alpha for transparency)
  /// [width] - Frame width in pixels
  /// [height] - Frame height in pixels
  Future<void> sendFrame(Uint8List pixels, int width, int height) async {
    if (!_isStreaming || _ndiSendInstance == null) return;

    try {
      // Convert in isolate to avoid UI jank
      final frameData = await compute(
        _prepareNdiFrame,
        _FrameParams(
          pixels: pixels,
          width: width,
          height: height,
          format: NdiFrameFormat.bgra,
        ),
      );

      // Send via FFI
      _sendNdiVideoFrame(frameData, width, height);
      _frameCount++;
    } catch (e) {
      debugPrint('[NDI] Send frame error: $e');
    }
  }

  /// Capture a widget and send as NDI frame
  Future<void> captureAndSend(RenderRepaintBoundary boundary) async {
    if (!_isStreaming) return;

    try {
      // Capture to image
      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );

      if (byteData != null) {
        await sendFrame(
          byteData.buffer.asUint8List(),
          image.width,
          image.height,
        );
      }

      image.dispose();
    } catch (e) {
      debugPrint('[NDI] Capture error: $e');
    }
  }

  /// Stop streaming
  void stopStream() {
    if (!_isStreaming) return;

    _frameTimer?.cancel();
    _frameTimer = null;

    if (_ndiSendInstance != null) {
      _destroyNdiSender();
      _ndiSendInstance = null;
    }

    _isStreaming = false;
    debugPrint('[NDI] Stopped streaming (sent $_frameCount frames)');
  }

  /// Dispose of all resources
  void dispose() {
    stopStream();

    if (_isInitialized) {
      _callNdiDestroy();
      _ndiLib = null;
      _isInitialized = false;
    }

    _instance = null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Private FFI implementation
  // ─────────────────────────────────────────────────────────────────────────

  // NDI bindings instance
  NdiBindings? _bindings;

  String? _findNdiLibrary(String filename) {
    // Search common locations
    final searchPaths = <String>[
      // App directory
      './$filename',
      // Windows runner
      './windows/runner/$filename',
      // Build output
      './build/windows/runner/Release/$filename',
      './build/windows/runner/Debug/$filename',
      // System paths
      if (Platform.isWindows) 'C:/Program Files/NDI/NDI 5 Runtime/v5/$filename',
      if (Platform.isMacOS) '/Library/NDI SDK for Apple/lib/macOS/$filename',
    ];

    for (final path in searchPaths) {
      if (File(path).existsSync()) {
        return path;
      }
    }

    // Check environment variable
    final ndiRuntimeDir = Platform.environment['NDI_RUNTIME_DIR_V5'];
    if (ndiRuntimeDir != null) {
      final envPath = '$ndiRuntimeDir/$filename';
      if (File(envPath).existsSync()) {
        return envPath;
      }
    }

    return null;
  }

  bool _callNdiInitialize() {
    if (_ndiLib == null) return false;

    try {
      _bindings = NdiBindings(_ndiLib!);
      final result = _bindings!.initialize();
      debugPrint('[NDI] NDIlib_initialize() returned: $result');
      return result;
    } catch (e) {
      debugPrint('[NDI] Error calling NDIlib_initialize: $e');
      return false;
    }
  }

  void _callNdiDestroy() {
    if (_bindings == null) return;

    try {
      _bindings!.destroy();
      debugPrint('[NDI] NDIlib_destroy() called');
    } catch (e) {
      debugPrint('[NDI] Error calling NDIlib_destroy: $e');
    }
  }

  ffi.Pointer<ffi.Void>? _createNdiSender(String name) {
    if (_bindings == null) return null;

    try {
      final sender = _bindings!.createSender(name);
      if (sender == ffi.nullptr) {
        debugPrint('[NDI] NDIlib_send_create returned null');
        return null;
      }
      debugPrint('[NDI] NDIlib_send_create("$name") succeeded');
      return sender;
    } catch (e) {
      debugPrint('[NDI] Error calling NDIlib_send_create: $e');
      return null;
    }
  }

  void _destroyNdiSender() {
    if (_bindings == null || _ndiSendInstance == null) return;

    try {
      _bindings!.sendDestroy(_ndiSendInstance!);
      debugPrint('[NDI] NDIlib_send_destroy() called');
    } catch (e) {
      debugPrint('[NDI] Error calling NDIlib_send_destroy: $e');
    }
  }

  void _sendNdiVideoFrame(Uint8List frameData, int width, int height) {
    if (_bindings == null || _ndiSendInstance == null) return;

    try {
      _bindings!.sendFrame(
        sender: _ndiSendInstance!,
        pixels: frameData,
        width: width,
        height: height,
        frameRateN: _frameRateNumerator,
        frameRateD: _frameRateDenominator,
        useBgra: true, // Use BGRA for alpha channel support
      );
    } catch (e) {
      debugPrint('[NDI] Error sending frame: $e');
    }
  }

  /// Get the number of receivers currently connected to this NDI source
  int getConnectionCount() {
    if (_bindings == null || _ndiSendInstance == null) return 0;
    return _bindings!.getConnectionCount(_ndiSendInstance!);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Isolate helpers for format conversion
// ─────────────────────────────────────────────────────────────────────────────

class _FrameParams {
  final Uint8List pixels;
  final int width;
  final int height;
  final NdiFrameFormat format;

  _FrameParams({
    required this.pixels,
    required this.width,
    required this.height,
    required this.format,
  });
}

/// Prepare frame data in isolate (runs off main thread)
Uint8List _prepareNdiFrame(_FrameParams params) {
  // For BGRA format with alpha, we can pass through directly
  // NDI supports BGRA natively for alpha channel keying
  if (params.format == NdiFrameFormat.bgra) {
    // Flutter's rawRgba is actually RGBA, need to swap to BGRA
    final bgra = Uint8List(params.pixels.length);
    for (int i = 0; i < params.pixels.length; i += 4) {
      bgra[i] = params.pixels[i + 2]; // B <- R
      bgra[i + 1] = params.pixels[i + 1]; // G <- G
      bgra[i + 2] = params.pixels[i]; // R <- B
      bgra[i + 3] = params.pixels[i + 3]; // A <- A
    }
    return bgra;
  }

  // For UYVY format (no alpha, better compression)
  if (params.format == NdiFrameFormat.uyvy) {
    return _convertRgbaToUyvy(params.pixels, params.width, params.height);
  }

  return params.pixels;
}

/// Convert RGBA to UYVY format
/// UYVY packs 2 pixels into 4 bytes: U0 Y0 V0 Y1
Uint8List _convertRgbaToUyvy(Uint8List rgba, int width, int height) {
  // UYVY is half the size (2 bytes per pixel vs 4)
  final uyvy = Uint8List(width * height * 2);
  int uyvyIdx = 0;

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x += 2) {
      final idx0 = (y * width + x) * 4;
      final idx1 = (y * width + x + 1) * 4;

      // Pixel 0
      final r0 = rgba[idx0];
      final g0 = rgba[idx0 + 1];
      final b0 = rgba[idx0 + 2];

      // Pixel 1
      final r1 = rgba[idx1];
      final g1 = rgba[idx1 + 1];
      final b1 = rgba[idx1 + 2];

      // RGB to YUV conversion (BT.601)
      final y0 = ((66 * r0 + 129 * g0 + 25 * b0 + 128) >> 8) + 16;
      final y1 = ((66 * r1 + 129 * g1 + 25 * b1 + 128) >> 8) + 16;

      // Average U and V for the two pixels
      final avgR = (r0 + r1) >> 1;
      final avgG = (g0 + g1) >> 1;
      final avgB = (b0 + b1) >> 1;

      final u = ((-38 * avgR - 74 * avgG + 112 * avgB + 128) >> 8) + 128;
      final v = ((112 * avgR - 94 * avgG - 18 * avgB + 128) >> 8) + 128;

      // Pack UYVY
      uyvy[uyvyIdx++] = u.clamp(0, 255);
      uyvy[uyvyIdx++] = y0.clamp(0, 255);
      uyvy[uyvyIdx++] = v.clamp(0, 255);
      uyvy[uyvyIdx++] = y1.clamp(0, 255);
    }
  }

  return uyvy;
}
