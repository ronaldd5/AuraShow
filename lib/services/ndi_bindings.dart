// NDI FFI Bindings for Dart
// These bindings map to the NewTek NDI SDK C API
//
// Based on NDI SDK 5.x headers (Processing.NDI.Lib.h)
// Download SDK from: https://ndi.video/download-ndi-sdk/

import 'dart:ffi' as ffi;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

// Ignore naming convention warnings - we're mirroring C API names from NDI SDK
// ignore_for_file: constant_identifier_names, non_constant_identifier_names, camel_case_types

// ─────────────────────────────────────────────────────────────────────────────
// NDI Type Definitions
// ─────────────────────────────────────────────────────────────────────────────

/// NDI video frame formats
class NDIlib_FourCC_video_type {
  static const int UYVY = 0x59565955; // 'UYVY'
  static const int BGRA = 0x41524742; // 'BGRA' - supports alpha
  static const int BGRX = 0x58524742; // 'BGRX' - no alpha
  static const int RGBA = 0x41424752; // 'RGBA' - supports alpha
  static const int RGBX = 0x58424752; // 'RGBX' - no alpha
}

/// NDI frame format type (progressive, interlaced, etc)
class NDIlib_frame_format_type {
  static const int progressive = 1;
  static const int interleaved = 0;
  static const int field0 = 2;
  static const int field1 = 3;
}

// ─────────────────────────────────────────────────────────────────────────────
// NDI Struct Definitions (as FFI Structs)
// ─────────────────────────────────────────────────────────────────────────────

/// NDIlib_send_create_t - Configuration for creating an NDI sender
final class NDIlib_send_create_t extends ffi.Struct {
  external ffi.Pointer<Utf8> p_ndi_name; // The name of the NDI source
  external ffi.Pointer<Utf8>
  p_groups; // Groups to publish to (null for default)

  @ffi.Bool()
  external bool clock_video; // Clock video frames (recommended: true)

  @ffi.Bool()
  external bool clock_audio; // Clock audio frames (recommended: true)
}

/// NDIlib_video_frame_v2_t - A video frame to send
final class NDIlib_video_frame_v2_t extends ffi.Struct {
  @ffi.Int32()
  external int xres; // Width in pixels

  @ffi.Int32()
  external int yres; // Height in pixels

  @ffi.Int32()
  external int FourCC; // Pixel format (use NDIlib_FourCC_video_type)

  @ffi.Int32()
  external int frame_rate_N; // Frame rate numerator

  @ffi.Int32()
  external int frame_rate_D; // Frame rate denominator

  @ffi.Float()
  external double picture_aspect_ratio; // Aspect ratio (0 = auto from resolution)

  @ffi.Int32()
  external int frame_format_type; // Progressive, interlaced, etc

  @ffi.Int64()
  external int timecode; // Timecode (NDIlib_send_timecode_synthesize = auto)

  external ffi.Pointer<ffi.Uint8> p_data; // Pointer to frame data

  @ffi.Int32()
  external int line_stride_in_bytes; // Bytes per line (0 = auto)

  external ffi.Pointer<Utf8> p_metadata; // Optional XML metadata

  @ffi.Int64()
  external int timestamp; // Timestamp in 100ns units
}

// ─────────────────────────────────────────────────────────────────────────────
// NDI Function Typedefs (C function signatures)
// ─────────────────────────────────────────────────────────────────────────────

// NDIlib_initialize: bool NDIlib_initialize(void)
typedef NDIlib_initialize_native = ffi.Bool Function();
typedef NDIlib_initialize_dart = bool Function();

// NDIlib_destroy: void NDIlib_destroy(void)
typedef NDIlib_destroy_native = ffi.Void Function();
typedef NDIlib_destroy_dart = void Function();

// NDIlib_send_create: NDIlib_send_instance_t NDIlib_send_create(const NDIlib_send_create_t* p_create_settings)
typedef NDIlib_send_create_native =
    ffi.Pointer<ffi.Void> Function(
      ffi.Pointer<NDIlib_send_create_t> p_create_settings,
    );
typedef NDIlib_send_create_dart =
    ffi.Pointer<ffi.Void> Function(
      ffi.Pointer<NDIlib_send_create_t> p_create_settings,
    );

// NDIlib_send_destroy: void NDIlib_send_destroy(NDIlib_send_instance_t p_instance)
typedef NDIlib_send_destroy_native =
    ffi.Void Function(ffi.Pointer<ffi.Void> p_instance);
typedef NDIlib_send_destroy_dart =
    void Function(ffi.Pointer<ffi.Void> p_instance);

// NDIlib_send_send_video_v2: void NDIlib_send_send_video_v2(NDIlib_send_instance_t p_instance, const NDIlib_video_frame_v2_t* p_video_data)
typedef NDIlib_send_send_video_v2_native =
    ffi.Void Function(
      ffi.Pointer<ffi.Void> p_instance,
      ffi.Pointer<NDIlib_video_frame_v2_t> p_video_data,
    );
typedef NDIlib_send_send_video_v2_dart =
    void Function(
      ffi.Pointer<ffi.Void> p_instance,
      ffi.Pointer<NDIlib_video_frame_v2_t> p_video_data,
    );

// NDIlib_send_get_no_connections: int NDIlib_send_get_no_connections(NDIlib_send_instance_t p_instance, uint32_t timeout_in_ms)
typedef NDIlib_send_get_no_connections_native =
    ffi.Int32 Function(
      ffi.Pointer<ffi.Void> p_instance,
      ffi.Uint32 timeout_in_ms,
    );
typedef NDIlib_send_get_no_connections_dart =
    int Function(ffi.Pointer<ffi.Void> p_instance, int timeout_in_ms);

// ─────────────────────────────────────────────────────────────────────────────
// NDI Bindings Class
// ─────────────────────────────────────────────────────────────────────────────

/// Manages FFI bindings to the NDI SDK
class NdiBindings {
  final ffi.DynamicLibrary _lib;

  // Cached function pointers
  late final NDIlib_initialize_dart initialize;
  late final NDIlib_destroy_dart destroy;
  late final NDIlib_send_create_dart sendCreate;
  late final NDIlib_send_destroy_dart sendDestroy;
  late final NDIlib_send_send_video_v2_dart sendVideoV2;
  late final NDIlib_send_get_no_connections_dart getNoConnections;

  NdiBindings(this._lib) {
    // Look up and bind all functions
    initialize = _lib
        .lookupFunction<NDIlib_initialize_native, NDIlib_initialize_dart>(
          'NDIlib_initialize',
        );

    destroy = _lib.lookupFunction<NDIlib_destroy_native, NDIlib_destroy_dart>(
      'NDIlib_destroy',
    );

    sendCreate = _lib
        .lookupFunction<NDIlib_send_create_native, NDIlib_send_create_dart>(
          'NDIlib_send_create',
        );

    sendDestroy = _lib
        .lookupFunction<NDIlib_send_destroy_native, NDIlib_send_destroy_dart>(
          'NDIlib_send_destroy',
        );

    sendVideoV2 = _lib
        .lookupFunction<
          NDIlib_send_send_video_v2_native,
          NDIlib_send_send_video_v2_dart
        >('NDIlib_send_send_video_v2');

    getNoConnections = _lib
        .lookupFunction<
          NDIlib_send_get_no_connections_native,
          NDIlib_send_get_no_connections_dart
        >('NDIlib_send_get_no_connections');
  }

  /// Create an NDI sender with the given name
  ffi.Pointer<ffi.Void> createSender(String name, {String? groups}) {
    final createSettings = calloc<NDIlib_send_create_t>();
    createSettings.ref.p_ndi_name = name.toNativeUtf8();
    createSettings.ref.p_groups = groups?.toNativeUtf8() ?? ffi.nullptr;
    createSettings.ref.clock_video = true;
    createSettings.ref.clock_audio = true;

    final sender = sendCreate(createSettings);

    // Free the strings
    calloc.free(createSettings.ref.p_ndi_name);
    if (createSettings.ref.p_groups != ffi.nullptr) {
      calloc.free(createSettings.ref.p_groups);
    }
    calloc.free(createSettings);

    return sender;
  }

  /// Send a video frame (BGRA format with alpha support)
  void sendFrame({
    required ffi.Pointer<ffi.Void> sender,
    required Uint8List pixels,
    required int width,
    required int height,
    required int frameRateN,
    required int frameRateD,
    bool useBgra = true,
  }) {
    // Allocate native memory for the frame
    final framePtr = calloc<NDIlib_video_frame_v2_t>();
    final dataPtr = calloc<ffi.Uint8>(pixels.length);

    // Copy pixel data to native memory
    final nativeData = dataPtr.asTypedList(pixels.length);
    nativeData.setAll(0, pixels);

    // Fill in the frame structure
    framePtr.ref.xres = width;
    framePtr.ref.yres = height;
    framePtr.ref.FourCC = useBgra
        ? NDIlib_FourCC_video_type.BGRA
        : NDIlib_FourCC_video_type.UYVY;
    framePtr.ref.frame_rate_N = frameRateN;
    framePtr.ref.frame_rate_D = frameRateD;
    framePtr.ref.picture_aspect_ratio = 0; // Auto from resolution
    framePtr.ref.frame_format_type = NDIlib_frame_format_type.progressive;
    framePtr.ref.timecode = -1; // NDIlib_send_timecode_synthesize
    framePtr.ref.p_data = dataPtr;
    framePtr.ref.line_stride_in_bytes = useBgra
        ? width *
              4 // BGRA = 4 bytes per pixel
        : width * 2; // UYVY = 2 bytes per pixel
    framePtr.ref.p_metadata = ffi.nullptr;
    framePtr.ref.timestamp = 0;

    // Send the frame
    sendVideoV2(sender, framePtr);

    // Free native memory
    calloc.free(dataPtr);
    calloc.free(framePtr);
  }

  /// Get the number of current connections to this sender
  int getConnectionCount(ffi.Pointer<ffi.Void> sender, {int timeoutMs = 0}) {
    return getNoConnections(sender, timeoutMs);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

/// Special timecode value that tells NDI to synthesize the timecode
const int NDIlib_send_timecode_synthesize = -1;
