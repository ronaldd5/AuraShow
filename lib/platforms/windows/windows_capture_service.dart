import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:win32/win32.dart';

import '../interface/capture_platform_interface.dart';
import 'win32_audio_capture_service.dart' as audio;

/// Native Win32 Screen Capture Service Implementation
class WindowsCaptureService implements CapturePlatform {
  WindowsCaptureService();

  final List<WindowInfo> _cachedWindows = [];
  final List<DisplayInfo> _cachedDisplays = [];
  DateTime? _lastWindowScan;
  DateTime? _lastDisplayScan;

  @override
  Stream<AudioCaptureData> get audioDataStream => audio
      .Win32AudioCaptureService
      .instance
      .audioDataStream
      .map((data) => AudioCaptureData(data.frequencies));

  @override
  Future<bool> startCapture({
    required AudioCaptureMode mode,
    String? deviceId,
  }) async {
    audio.AudioCaptureMode winMode;
    if (mode == AudioCaptureMode.loopback) {
      winMode = audio.AudioCaptureMode.loopback;
    } else {
      winMode = audio.AudioCaptureMode.microphone;
    }
    return audio.Win32AudioCaptureService.instance.startCapture(
      mode: winMode,
      deviceId: deviceId,
    );
  }

  @override
  Future<void> stopCapture() async {
    await audio.Win32AudioCaptureService.instance.stopCapture();
  }

  @override
  Future<List<WindowInfo>> getWindows({bool refresh = false}) async {
    final now = DateTime.now();
    if (!refresh &&
        _lastWindowScan != null &&
        now.difference(_lastWindowScan!).inSeconds < 5) {
      return List.unmodifiable(_cachedWindows);
    }

    _cachedWindows.clear();
    _enumerateWindows();
    _lastWindowScan = now;
    return List.unmodifiable(_cachedWindows);
  }

  @override
  Future<List<DisplayInfo>> getDisplays({bool refresh = false}) async {
    final now = DateTime.now();
    if (!refresh &&
        _lastDisplayScan != null &&
        now.difference(_lastDisplayScan!).inSeconds < 10) {
      return List.unmodifiable(_cachedDisplays);
    }

    _cachedDisplays.clear();
    _enumerateDisplaysSimple();
    _lastDisplayScan = now;
    return List.unmodifiable(_cachedDisplays);
  }

  // Temporary static collection for the callback
  static final List<WindowInfo> _collectedWindows = [];

  void _enumerateWindows() {
    try {
      _collectedWindows.clear();
      final callback = Pointer.fromFunction<EnumWindowsProc>(
        _enumWindowsCallback,
        0,
      );
      EnumWindows(callback, 0);
      _cachedWindows.addAll(_collectedWindows);
      _collectedWindows.clear();
    } catch (e) {
      debugPrint('WindowsCaptureService: Error enumerating windows: $e');
    }
  }

  static int _enumWindowsCallback(int hwnd, int lParam) {
    try {
      if (IsWindowVisible(hwnd) == 0) return TRUE;

      final titleLength = GetWindowTextLength(hwnd);
      if (titleLength == 0) return TRUE;

      final titleBuffer = wsalloc(titleLength + 1);
      GetWindowText(hwnd, titleBuffer, titleLength + 1);
      final title = titleBuffer.toDartString();
      free(titleBuffer);

      if (title.isEmpty) return TRUE;

      final classBuffer = wsalloc(256);
      GetClassName(hwnd, classBuffer, 256);
      final className = classBuffer.toDartString();
      free(classBuffer);

      if (_shouldSkipWindow(className, title)) return TRUE;

      String processName = '';
      final processIdPtr = calloc<DWORD>();
      GetWindowThreadProcessId(hwnd, processIdPtr);
      final processId = processIdPtr.value;
      free(processIdPtr);

      final hProcess = OpenProcess(
        PROCESS_QUERY_LIMITED_INFORMATION,
        FALSE,
        processId,
      );
      if (hProcess != 0) {
        final pathBuffer = wsalloc(MAX_PATH);
        final sizePtr = calloc<DWORD>()..value = MAX_PATH;
        if (QueryFullProcessImageName(hProcess, 0, pathBuffer, sizePtr) != 0) {
          final fullPath = pathBuffer.toDartString();
          processName = fullPath.split('\\').last;
        }
        free(pathBuffer);
        free(sizePtr);
        CloseHandle(hProcess);
      }

      _collectedWindows.add(
        WindowInfo(
          hwnd: hwnd,
          title: title,
          processName: processName,
          className: className,
        ),
      );
    } catch (e) {
      debugPrint('WindowsCaptureService: Error in enum callback: $e');
    }

    return TRUE;
  }

  static bool _shouldSkipWindow(String className, String title) {
    const skipClasses = [
      'Progman',
      'WorkerW',
      'Shell_TrayWnd',
      'Shell_SecondaryTrayWnd',
      'Xaml_WindowedPopupClass',
      'Windows.UI.Core.CoreWindow',
      'ApplicationFrameWindow',
    ];

    const skipTitles = [
      'Program Manager',
      'Windows Input Experience',
      'Microsoft Text Input Application',
      'Settings',
    ];

    if (skipClasses.contains(className)) return true;
    if (skipTitles.contains(title)) return true;

    return false;
  }

  void _enumerateDisplaysSimple() {
    try {
      final width = GetSystemMetrics(SM_CXSCREEN);
      final height = GetSystemMetrics(SM_CYSCREEN);

      _cachedDisplays.add(
        DisplayInfo(
          handle: 0,
          name: 'Primary Display',
          left: 0,
          top: 0,
          width: width,
          height: height,
          isPrimary: true,
        ),
      );

      final vWidth = GetSystemMetrics(SM_CXVIRTUALSCREEN);
      final vHeight = GetSystemMetrics(SM_CYVIRTUALSCREEN);
      final vLeft = GetSystemMetrics(SM_XVIRTUALSCREEN);
      final vTop = GetSystemMetrics(SM_YVIRTUALSCREEN);

      if (vWidth > width || vHeight > height) {
        _cachedDisplays.insert(
          0,
          DisplayInfo(
            handle: -1,
            name: 'All Displays',
            left: vLeft,
            top: vTop,
            width: vWidth,
            height: vHeight,
            isPrimary: false,
          ),
        );
      }
    } catch (e) {
      debugPrint('WindowsCaptureService: Error enumerating displays: $e');
    }
  }

  @override
  Future<Uint8List?> captureWindow(
    int hwnd, {
    int thumbnailWidth = 320,
    int thumbnailHeight = 180,
  }) async {
    try {
      final rect = calloc<RECT>();
      if (GetWindowRect(hwnd, rect) == 0) {
        free(rect);
        return null;
      }
      final width = rect.ref.right - rect.ref.left;
      final height = rect.ref.bottom - rect.ref.top;
      free(rect);

      if (width <= 0 || height <= 0) return null;

      return _captureRegion(
        hwnd,
        0,
        0,
        width,
        height,
        thumbnailWidth,
        thumbnailHeight,
      );
    } catch (e) {
      debugPrint('WindowsCaptureService: Error capturing window: $e');
      return null;
    }
  }

  @override
  Future<Uint8List?> captureScreen({
    int thumbnailWidth = 320,
    int thumbnailHeight = 180,
  }) async {
    try {
      final width = GetSystemMetrics(SM_CXSCREEN);
      final height = GetSystemMetrics(SM_CYSCREEN);

      return _captureRegion(
        NULL,
        0,
        0,
        width,
        height,
        thumbnailWidth,
        thumbnailHeight,
      );
    } catch (e) {
      debugPrint('WindowsCaptureService: Error capturing screen: $e');
      return null;
    }
  }

  @override
  Future<Uint8List?> captureDisplay(
    int displayIndex, {
    int thumbnailWidth = 320,
    int thumbnailHeight = 180,
  }) async {
    try {
      final displays = await getDisplays();
      if (displayIndex < 0 || displayIndex >= displays.length) {
        return captureScreen(
          thumbnailWidth: thumbnailWidth,
          thumbnailHeight: thumbnailHeight,
        );
      }

      final display = displays[displayIndex];
      return _captureRegion(
        NULL,
        display.left,
        display.top,
        display.width,
        display.height,
        thumbnailWidth,
        thumbnailHeight,
      );
    } catch (e) {
      debugPrint('WindowsCaptureService: Error capturing display: $e');
      return null;
    }
  }

  Uint8List? _captureRegion(
    int hwnd,
    int srcX,
    int srcY,
    int srcWidth,
    int srcHeight,
    int destWidth,
    int destHeight,
  ) {
    try {
      if (srcWidth <= 0 || srcHeight <= 0) return null;

      final hdcSource = hwnd == NULL ? GetDC(NULL) : GetWindowDC(hwnd);
      if (hdcSource == 0) return null;

      final hdcMem = CreateCompatibleDC(hdcSource);
      final hBitmap = CreateCompatibleBitmap(hdcSource, destWidth, destHeight);
      final hOld = SelectObject(hdcMem, hBitmap);

      SetStretchBltMode(hdcMem, HALFTONE);

      StretchBlt(
        hdcMem,
        0,
        0,
        destWidth,
        destHeight,
        hdcSource,
        srcX,
        srcY,
        srcWidth,
        srcHeight,
        SRCCOPY,
      );

      final bmi = calloc<BITMAPINFO>();
      bmi.ref.bmiHeader.biSize = sizeOf<BITMAPINFOHEADER>();
      bmi.ref.bmiHeader.biWidth = destWidth;
      bmi.ref.bmiHeader.biHeight = -destHeight;
      bmi.ref.bmiHeader.biPlanes = 1;
      bmi.ref.bmiHeader.biBitCount = 32;
      bmi.ref.bmiHeader.biCompression = BI_RGB;

      final bufferSize = destWidth * destHeight * 4;
      final buffer = calloc<Uint8>(bufferSize);

      GetDIBits(hdcMem, hBitmap, 0, destHeight, buffer, bmi, DIB_RGB_COLORS);

      final bytes = Uint8List(bufferSize);
      for (int i = 0; i < bufferSize; i += 4) {
        bytes[i] = buffer[i + 2];
        bytes[i + 1] = buffer[i + 1];
        bytes[i + 2] = buffer[i];
        bytes[i + 3] = 255;
      }

      free(buffer);
      free(bmi);
      SelectObject(hdcMem, hOld);
      DeleteObject(hBitmap);
      DeleteDC(hdcMem);
      ReleaseDC(hwnd, hdcSource);

      return _createBmpBytes(bytes, destWidth, destHeight);
    } catch (e) {
      debugPrint('WindowsCaptureService: Error in _captureRegion: $e');
      return null;
    }
  }

  Uint8List _createBmpBytes(Uint8List rgbaData, int width, int height) {
    final rowSize = ((width * 3 + 3) ~/ 4) * 4;
    final imageSize = rowSize * height;
    final fileSize = 54 + imageSize;

    final bmp = Uint8List(fileSize);
    final data = ByteData.view(bmp.buffer);

    bmp[0] = 0x42;
    bmp[1] = 0x4D;
    data.setUint32(2, fileSize, Endian.little);
    data.setUint32(10, 54, Endian.little);

    data.setUint32(14, 40, Endian.little);
    data.setInt32(18, width, Endian.little);
    data.setInt32(22, -height, Endian.little);
    data.setUint16(26, 1, Endian.little);
    data.setUint16(28, 24, Endian.little);
    data.setUint32(30, 0, Endian.little);
    data.setUint32(34, imageSize, Endian.little);

    int offset = 54;
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final srcIdx = (y * width + x) * 4;
        bmp[offset++] = rgbaData[srcIdx + 2];
        bmp[offset++] = rgbaData[srcIdx + 1];
        bmp[offset++] = rgbaData[srcIdx];
      }
      final padding = rowSize - width * 3;
      for (int p = 0; p < padding; p++) {
        bmp[offset++] = 0;
      }
    }

    return bmp;
  }
}
