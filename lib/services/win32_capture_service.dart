/// Native Win32 Screen Capture Service for AuraShow
/// Uses Win32 APIs (BitBlt) for silent screen/window capture
/// without triggering the Windows Snipping Tool
library;

import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:win32/win32.dart';

/// Window info for enumeration
class WindowInfo {
  WindowInfo({
    required this.hwnd,
    required this.title,
    required this.processName,
    required this.className,
    this.isVisible = true,
  });

  final int hwnd;
  final String title;
  final String processName;
  final String className;
  final bool isVisible;

  @override
  String toString() => 'WindowInfo(hwnd: $hwnd, title: $title)';
}

/// Screen/Display info
class DisplayInfo {
  DisplayInfo({
    required this.handle,
    required this.name,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.isPrimary,
  });

  final int handle;
  final String name;
  final int left;
  final int top;
  final int width;
  final int height;
  final bool isPrimary;
}

/// Win32 Screen Capture Service
class Win32CaptureService {
  Win32CaptureService._();
  static final Win32CaptureService instance = Win32CaptureService._();

  final List<WindowInfo> _cachedWindows = [];
  final List<DisplayInfo> _cachedDisplays = [];
  DateTime? _lastWindowScan;
  DateTime? _lastDisplayScan;

  /// Get list of capturable windows
  List<WindowInfo> getWindows({bool refresh = false}) {
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

  /// Get list of displays/monitors
  List<DisplayInfo> getDisplays({bool refresh = false}) {
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

  /// Enumerate all visible windows
  void _enumerateWindows() {
    try {
      final callback = Pointer.fromFunction<EnumWindowsProc>(
        _enumWindowsCallback,
        0,
      );
      EnumWindows(callback, 0);
    } catch (e) {
      debugPrint('Win32CaptureService: Error enumerating windows: $e');
    }
  }

  /// Callback for EnumWindows
  static int _enumWindowsCallback(int hwnd, int lParam) {
    try {
      // Check if window is visible
      if (IsWindowVisible(hwnd) == 0) return TRUE;

      // Get window title
      final titleLength = GetWindowTextLength(hwnd);
      if (titleLength == 0) return TRUE;

      final titleBuffer = wsalloc(titleLength + 1);
      GetWindowText(hwnd, titleBuffer, titleLength + 1);
      final title = titleBuffer.toDartString();
      free(titleBuffer);

      // Skip empty titles
      if (title.isEmpty) return TRUE;

      // Get class name
      final classBuffer = wsalloc(256);
      GetClassName(hwnd, classBuffer, 256);
      final className = classBuffer.toDartString();
      free(classBuffer);

      // Skip certain system windows
      if (_shouldSkipWindow(className, title)) return TRUE;

      // Get process name
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

      instance._cachedWindows.add(WindowInfo(
        hwnd: hwnd,
        title: title,
        processName: processName,
        className: className,
      ));
    } catch (e) {
      debugPrint('Win32CaptureService: Error in enum callback: $e');
    }

    return TRUE;
  }

  /// Check if window should be skipped
  static bool _shouldSkipWindow(String className, String title) {
    // Skip Windows shell/system windows
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

  /// Simple display enumeration using primary monitor only
  void _enumerateDisplaysSimple() {
    try {
      // Get primary display size
      final width = GetSystemMetrics(SM_CXSCREEN);
      final height = GetSystemMetrics(SM_CYSCREEN);
      
      _cachedDisplays.add(DisplayInfo(
        handle: 0,
        name: 'Primary Display',
        left: 0,
        top: 0,
        width: width,
        height: height,
        isPrimary: true,
      ));
      
      // Try to get virtual screen (all monitors combined)
      final vWidth = GetSystemMetrics(SM_CXVIRTUALSCREEN);
      final vHeight = GetSystemMetrics(SM_CYVIRTUALSCREEN);
      final vLeft = GetSystemMetrics(SM_XVIRTUALSCREEN);
      final vTop = GetSystemMetrics(SM_YVIRTUALSCREEN);
      
      // If virtual screen is larger, there are multiple monitors
      if (vWidth > width || vHeight > height) {
        // Add a "All Displays" option
        _cachedDisplays.insert(0, DisplayInfo(
          handle: -1,
          name: 'All Displays',
          left: vLeft,
          top: vTop,
          width: vWidth,
          height: vHeight,
          isPrimary: false,
        ));
      }
    } catch (e) {
      debugPrint('Win32CaptureService: Error enumerating displays: $e');
    }
  }

  /// Capture a window to BMP bytes (synchronous)
  Uint8List? captureWindow(
    int hwnd, {
    int thumbnailWidth = 320,
    int thumbnailHeight = 180,
  }) {
    try {
      // Get window dimensions
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
      debugPrint('Win32CaptureService: Error capturing window: $e');
      return null;
    }
  }

  /// Capture entire primary screen to BMP bytes
  Uint8List? captureScreen({
    int thumbnailWidth = 320,
    int thumbnailHeight = 180,
  }) {
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
      debugPrint('Win32CaptureService: Error capturing screen: $e');
      return null;
    }
  }

  /// Capture a specific display by index
  Uint8List? captureDisplay(
    int displayIndex, {
    int thumbnailWidth = 320,
    int thumbnailHeight = 180,
  }) {
    try {
      final displays = getDisplays();
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
      debugPrint('Win32CaptureService: Error capturing display: $e');
      return null;
    }
  }

  /// Internal method to capture a screen region
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

      // Get device context
      final hdcSource = hwnd == NULL ? GetDC(NULL) : GetWindowDC(hwnd);
      if (hdcSource == 0) return null;

      // Create compatible DC and bitmap
      final hdcMem = CreateCompatibleDC(hdcSource);
      final hBitmap = CreateCompatibleBitmap(hdcSource, destWidth, destHeight);
      final hOld = SelectObject(hdcMem, hBitmap);

      // Set stretch mode for better quality
      SetStretchBltMode(hdcMem, HALFTONE);

      // Copy with scaling
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

      // Get bitmap bits
      final bmi = calloc<BITMAPINFO>();
      bmi.ref.bmiHeader.biSize = sizeOf<BITMAPINFOHEADER>();
      bmi.ref.bmiHeader.biWidth = destWidth;
      bmi.ref.bmiHeader.biHeight = -destHeight; // Top-down
      bmi.ref.bmiHeader.biPlanes = 1;
      bmi.ref.bmiHeader.biBitCount = 32;
      bmi.ref.bmiHeader.biCompression = BI_RGB;

      final bufferSize = destWidth * destHeight * 4;
      final buffer = calloc<Uint8>(bufferSize);

      GetDIBits(hdcMem, hBitmap, 0, destHeight, buffer, bmi, DIB_RGB_COLORS);

      // Convert BGRA to BMP format
      final bytes = Uint8List(bufferSize);
      for (int i = 0; i < bufferSize; i += 4) {
        bytes[i] = buffer[i + 2]; // R
        bytes[i + 1] = buffer[i + 1]; // G
        bytes[i + 2] = buffer[i]; // B
        bytes[i + 3] = 255; // A
      }

      // Cleanup
      free(buffer);
      free(bmi);
      SelectObject(hdcMem, hOld);
      DeleteObject(hBitmap);
      DeleteDC(hdcMem);
      ReleaseDC(hwnd, hdcSource);

      // Return as BMP for Image.memory
      return _createBmpBytes(bytes, destWidth, destHeight);
    } catch (e) {
      debugPrint('Win32CaptureService: Error in _captureRegion: $e');
      return null;
    }
  }

  /// Create BMP file bytes from raw RGBA data
  Uint8List _createBmpBytes(Uint8List rgbaData, int width, int height) {
    // BMP file format
    final rowSize = ((width * 3 + 3) ~/ 4) * 4; // Row must be multiple of 4
    final imageSize = rowSize * height;
    final fileSize = 54 + imageSize; // Header + image

    final bmp = Uint8List(fileSize);
    final data = ByteData.view(bmp.buffer);

    // BMP Header
    bmp[0] = 0x42; // 'B'
    bmp[1] = 0x4D; // 'M'
    data.setUint32(2, fileSize, Endian.little); // File size
    data.setUint32(10, 54, Endian.little); // Offset to pixel data

    // DIB Header (BITMAPINFOHEADER)
    data.setUint32(14, 40, Endian.little); // Header size
    data.setInt32(18, width, Endian.little); // Width
    data.setInt32(22, -height, Endian.little); // Height (negative = top-down)
    data.setUint16(26, 1, Endian.little); // Planes
    data.setUint16(28, 24, Endian.little); // Bits per pixel
    data.setUint32(30, 0, Endian.little); // Compression (BI_RGB)
    data.setUint32(34, imageSize, Endian.little); // Image size

    // Pixel data (convert RGBA to BGR)
    int offset = 54;
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final srcIdx = (y * width + x) * 4;
        bmp[offset++] = rgbaData[srcIdx + 2]; // B
        bmp[offset++] = rgbaData[srcIdx + 1]; // G
        bmp[offset++] = rgbaData[srcIdx]; // R
      }
      // Padding
      final padding = rowSize - width * 3;
      for (int p = 0; p < padding; p++) {
        bmp[offset++] = 0;
      }
    }

    return bmp;
  }
}
