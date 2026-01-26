/// Device Service for AuraShow
/// Manages cameras, screens, and NDI sources with live thumbnail support
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Offset, Size;

import 'package:flutter/foundation.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:screen_retriever/screen_retriever.dart';

import '../platforms/desktop_capture.dart';
import '../platforms/interface/capture_platform_interface.dart';

/// Device type enumeration
enum DeviceType { camera, screen, ndi }

/// Represents a live device (camera, screen, or NDI source)
class LiveDevice {
  LiveDevice({
    required this.id,
    required this.name,
    required this.detail,
    required this.type,
    this.thumbnail,
    this.isActive = true,
    this.resolution,
    this.refreshRate,
    this.ndiUrl,
  });

  final String id;
  final String name;
  final String detail;
  final DeviceType type;
  Uint8List? thumbnail;
  final bool isActive;
  final String? resolution;
  final int? refreshRate;
  final String? ndiUrl;

  /// Create a copy with updated thumbnail
  LiveDevice copyWithThumbnail(Uint8List? newThumbnail) {
    return LiveDevice(
      id: id,
      name: name,
      detail: detail,
      type: type,
      thumbnail: newThumbnail,
      isActive: isActive,
      resolution: resolution,
      refreshRate: refreshRate,
      ndiUrl: ndiUrl,
    );
  }

  /// Create a copy with updated properties
  LiveDevice copyWith({
    String? id,
    String? name,
    String? detail,
    DeviceType? type,
    Uint8List? thumbnail,
    bool? isActive,
    String? resolution,
    int? refreshRate,
    String? ndiUrl,
  }) {
    return LiveDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      detail: detail ?? this.detail,
      type: type ?? this.type,
      thumbnail: thumbnail ?? this.thumbnail,
      isActive: isActive ?? this.isActive,
      resolution: resolution ?? this.resolution,
      refreshRate: refreshRate ?? this.refreshRate,
      ndiUrl: ndiUrl ?? this.ndiUrl,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LiveDevice && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// NDI Source representation
class NdiSource {
  NdiSource({
    required this.id,
    required this.name,
    required this.url,
    this.ipAddress,
    this.port,
    this.isOnline = true,
  });

  final String id;
  final String name;
  final String url;
  final String? ipAddress;
  final int? port;
  final bool isOnline;
}

/// Service for managing device discovery and live thumbnails
class DeviceService {
  DeviceService._();
  static final DeviceService instance = DeviceService._();

  final _devicesController = StreamController<List<LiveDevice>>.broadcast();
  Stream<List<LiveDevice>> get devicesStream => _devicesController.stream;

  final List<LiveDevice> _cameras = [];
  final List<LiveDevice> _screens = [];
  final List<LiveDevice> _ndiSources = [];

  List<LiveDevice> get cameras => List.unmodifiable(_cameras);
  List<LiveDevice> get screens => List.unmodifiable(_screens);
  List<LiveDevice> get ndiSources => List.unmodifiable(_ndiSources);
  List<LiveDevice> get allDevices => [..._cameras, ..._screens, ..._ndiSources];

  Timer? _thumbnailUpdateTimer;
  Timer? _deviceScanTimer;
  bool _isInitialized = false;
  bool _isUpdatingThumbnails = false;
  bool _isCapturingCamera = false;

  /// Initialize the device service
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // Initial device scan
    await refreshDevices();

    // Start periodic device scanning (every 10 seconds)
    _deviceScanTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => refreshDevices(),
    );

    // Start thumbnail updates (every 5 seconds for cameras only)
    // NOTE: Screen capture is disabled because screen_capturer triggers
    // the Windows Snipping Tool UI. Screens show info only.
    _thumbnailUpdateTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _updateThumbnails(),
    );
  }

  /// Dispose resources
  void dispose() {
    _thumbnailUpdateTimer?.cancel();
    _deviceScanTimer?.cancel();
    _devicesController.close();
    _isInitialized = false;
  }

  /// Refresh all devices
  Future<void> refreshDevices() async {
    await Future.wait([_scanScreens(), _scanCameras(), _scanNdiSources()]);
    _notifyListeners();
  }

  /// Scan for connected screens/displays using Win32 APIs
  Future<void> _scanScreens() async {
    try {
      // Use Win32 capture service for reliable display detection (Windows only)
      if (Platform.isWindows) {
        final displays = DesktopCapture.instance.getDisplays();
        final newScreens = <LiveDevice>[];

        for (int i = 0; i < displays.length; i++) {
          final display = displays[i];
          final resolution = '${display.width}x${display.height}';

          // Check if we already have this screen to preserve thumbnail
          final existing = _screens.firstWhereOrNull(
            (s) => s.id == 'screen-$i',
          );

          newScreens.add(
            LiveDevice(
              id: 'screen-$i',
              name: display.name,
              detail: '$resolution @(${display.left},${display.top})',
              type: DeviceType.screen,
              thumbnail: existing?.thumbnail,
              resolution: resolution,
              isActive: true,
            ),
          );
        }

        _screens
          ..clear()
          ..addAll(newScreens);
        return;
      } else if (Platform.isMacOS) {
        // macOS uses screen_retriever fallback below
      }

      // Non-Windows Fallback below
      if (!Platform.isMacOS)
        throw UnsupportedError('Not running on Windows or macOS');
    } catch (e) {
      if (Platform.isWindows) {
        debugPrint('DeviceService: Error scanning screens (Win32): $e');
      } else if (Platform.isMacOS) {
        debugPrint('DeviceService: Info scanning screens (macOS): $e');
      }
      // Fallback to screen_retriever on Mac or if Win32 fails
      try {
        final displays = await ScreenRetriever.instance.getAllDisplays();
        final newScreens = <LiveDevice>[];

        for (int i = 0; i < displays.length; i++) {
          final display = displays[i];
          final pos = display.visiblePosition ?? Offset.zero;
          final size = display.visibleSize ?? display.size ?? const Size(0, 0);
          final name = display.name ?? 'Display $i';
          final resolution = '${size.width.toInt()}x${size.height.toInt()}';

          final existing = _screens.firstWhereOrNull(
            (s) => s.id == 'screen-$i',
          );

          newScreens.add(
            LiveDevice(
              id: 'screen-$i',
              name: name,
              detail: '$resolution @(${pos.dx.toInt()},${pos.dy.toInt()})',
              type: DeviceType.screen,
              thumbnail: existing?.thumbnail,
              resolution: resolution,
              isActive: true,
            ),
          );
        }

        _screens
          ..clear()
          ..addAll(newScreens);
      } catch (e2) {
        debugPrint('DeviceService: Fallback screen scan also failed: $e2');
        // Add demo screen if all detection fails
        if (_screens.isEmpty) {
          _screens.add(
            LiveDevice(
              id: 'screen-0',
              name: 'Main Display',
              detail: '1920x1080 @(0,0)',
              type: DeviceType.screen,
              resolution: '1920x1080',
            ),
          );
        }
      }
    }
  }

  /// Scan for connected cameras
  Future<void> _scanCameras() async {
    try {
      // Use media_kit or platform-specific camera detection
      // For now, we'll enumerate cameras using a simpler approach
      final cameras = await _enumerateCameras();

      final newCameras = <LiveDevice>[];
      for (int i = 0; i < cameras.length; i++) {
        final cam = cameras[i];
        final existing = _cameras.firstWhereOrNull((c) => c.id == cam.id);

        newCameras.add(
          LiveDevice(
            id: cam.id,
            name: cam.name,
            detail: cam.detail,
            type: DeviceType.camera,
            thumbnail: existing?.thumbnail,
            isActive: true,
          ),
        );
      }

      _cameras
        ..clear()
        ..addAll(newCameras);
    } catch (e) {
      debugPrint('DeviceService: Error scanning cameras: $e');
      // Add demo camera if detection fails
      if (_cameras.isEmpty) {
        _cameras.add(
          LiveDevice(
            id: 'camera-demo-1',
            name: 'USB Camera',
            detail: 'Front stage camera',
            type: DeviceType.camera,
          ),
        );
      }
    }
  }

  /// Enumerate available cameras using platform APIs
  Future<List<_CameraInfo>> _enumerateCameras() async {
    final cameras = <_CameraInfo>[];

    try {
      // Use the camera platform interface to get available cameras
      final List<CameraDescription> availableCameras = await CameraPlatform
          .instance
          .availableCameras();

      for (int i = 0; i < availableCameras.length; i++) {
        final camera = availableCameras[i];
        cameras.add(
          _CameraInfo(
            id: 'camera-$i',
            name: camera.name.isNotEmpty ? camera.name : 'Camera ${i + 1}',
            detail: _getLensFacingLabel(camera.lensDirection),
          ),
        );
      }
    } catch (e) {
      debugPrint('DeviceService: Camera enumeration error: $e');
      // Fallback: try to detect via other means or show placeholder
    }

    return cameras;
  }

  /// Get human-readable label for camera lens direction
  String _getLensFacingLabel(CameraLensDirection direction) {
    switch (direction) {
      case CameraLensDirection.front:
        return 'Front-facing camera';
      case CameraLensDirection.back:
        return 'Rear-facing camera';
      case CameraLensDirection.external:
        return 'External camera';
    }
  }

  /// Scan for NDI sources on the network
  Future<void> _scanNdiSources() async {
    try {
      // NDI SDK is not available as a Flutter package
      // This would require native integration via FFI or platform channels
      // For now, we'll provide manual NDI source entry support

      // Check if we have any manually added NDI sources
      // In a full implementation, this would scan the network

      // Demo NDI sources for UI development
      if (_ndiSources.isEmpty) {
        // Add placeholder to show NDI category is available
        // Real NDI sources would be discovered via NDI SDK
      }
    } catch (e) {
      debugPrint('DeviceService: Error scanning NDI sources: $e');
    }
  }

  /// Add a manual NDI source
  void addNdiSource({
    required String name,
    required String url,
    String? ipAddress,
    int? port,
  }) {
    final id = 'ndi-${DateTime.now().millisecondsSinceEpoch}';
    _ndiSources.add(
      LiveDevice(
        id: id,
        name: name,
        detail: url,
        type: DeviceType.ndi,
        ndiUrl: url,
        isActive: true,
      ),
    );
    _notifyListeners();
  }

  /// Remove an NDI source
  void removeNdiSource(String id) {
    _ndiSources.removeWhere((s) => s.id == id);
    _notifyListeners();
  }

  /// Update thumbnails for all devices
  Future<void> _updateThumbnails() async {
    // Prevent concurrent updates
    if (_isUpdatingThumbnails) return;
    _isUpdatingThumbnails = true;

    try {
      bool hasUpdates = false;

      // Update screen thumbnails using native Win32 capture
      for (int i = 0; i < _screens.length; i++) {
        final screen = _screens[i];
        final updated = await _captureScreenThumbnail(screen);
        if (updated) hasUpdates = true;
      }

      // Skip camera thumbnails - camera layers use live CameraPreview widget
      // The camera plugin doesn't handle multiple createCamera calls well

      if (hasUpdates) {
        _notifyListeners();
      }
    } finally {
      _isUpdatingThumbnails = false;
    }
  }

  /// Capture a thumbnail from a camera
  /// NOTE: This method is currently disabled in periodic updates because
  /// camera layers use live CameraPreview widget for real-time display.
  /// Only call this once on initial scan if needed.
  Future<bool> _captureCameraThumbnail(LiveDevice camera) async {
    // Prevent concurrent camera capture - the camera plugin doesn't handle it well
    if (_isCapturingCamera) {
      debugPrint(
        'DeviceService: Skipping camera capture - already in progress',
      );
      return false;
    }
    _isCapturingCamera = true;

    try {
      // Extract camera index from id
      final cameraIdStr = camera.id.replaceFirst('camera-', '');
      final cameraIndex = int.tryParse(cameraIdStr) ?? 0;

      // Get available cameras
      final availableCameras = await CameraPlatform.instance.availableCameras();
      if (cameraIndex >= availableCameras.length) return false;

      final cameraDescription = availableCameras[cameraIndex];

      // Create camera and capture a single frame
      final cameraId = await CameraPlatform.instance.createCameraWithSettings(
        cameraDescription,
        const MediaSettings(
          resolutionPreset: ResolutionPreset.low, // Low res for thumbnail
          fps: 15,
          videoBitrate: 200000,
          enableAudio: false,
        ),
      );

      try {
        // Initialize camera
        await CameraPlatform.instance.initializeCamera(cameraId);

        // Wait briefly for camera to warm up
        await Future.delayed(const Duration(milliseconds: 200));

        // Capture image
        final XFile imageFile = await CameraPlatform.instance.takePicture(
          cameraId,
        );
        final imageBytes = await imageFile.readAsBytes();

        if (imageBytes.isNotEmpty) {
          final idx = _cameras.indexWhere((c) => c.id == camera.id);
          if (idx >= 0) {
            _cameras[idx] = camera.copyWithThumbnail(imageBytes);
            return true;
          }
        }
      } finally {
        // Always dispose the camera
        try {
          await CameraPlatform.instance.dispose(cameraId);
        } catch (disposeError) {
          debugPrint('DeviceService: Error disposing camera: $disposeError');
        }
      }
    } catch (e) {
      // Only log first occurrence to avoid spam
      debugPrint(
        'DeviceService: Camera thumbnail capture skipped: ${e.runtimeType}',
      );
    } finally {
      _isCapturingCamera = false;
    }
    return false;
  }

  /// Capture a thumbnail for a screen using native Win32 APIs
  Future<bool> _captureScreenThumbnail(LiveDevice screen) async {
    if (Platform.isMacOS) return false; // macOS uses standard capture
    if (!Platform.isWindows) return false;

    try {
      // Extract display ID from screen.id
      final displayIdStr = screen.id.replaceFirst('screen-', '');
      final displayIndex = int.tryParse(displayIdStr);

      if (displayIndex == null) return false;

      // Get displays from Win32 capture service
      final displays = DesktopCapture.instance.getDisplays();
      if (displayIndex >= displays.length) return false;

      // Capture the display using Win32 BitBlt (silent, no Snipping Tool!)
      final imageBytes = DesktopCapture.instance.captureDisplay(
        displayIndex,
        thumbnailWidth: 320,
        thumbnailHeight: 180,
      );

      if (imageBytes != null && imageBytes.isNotEmpty) {
        final idx = _screens.indexWhere((s) => s.id == screen.id);
        if (idx >= 0) {
          _screens[idx] = screen.copyWithThumbnail(imageBytes);
          return true;
        }
      }
    } catch (e) {
      debugPrint('DeviceService: Error capturing screen thumbnail: $e');
    }
    return false;
  }

  /// Get thumbnail for a specific device
  Uint8List? getThumbnail(String deviceId) {
    final device = allDevices.firstWhereOrNull((d) => d.id == deviceId);
    return device?.thumbnail;
  }

  /// Force refresh thumbnail for a specific device
  Future<void> refreshThumbnail(String deviceId) async {
    final device = allDevices.firstWhereOrNull((d) => d.id == deviceId);
    if (device == null) return;

    switch (device.type) {
      case DeviceType.screen:
        await _captureScreenThumbnail(device);
        break;
      case DeviceType.camera:
        // Would capture from active camera stream
        break;
      case DeviceType.ndi:
        // Would capture from NDI stream
        break;
    }
    _notifyListeners();
  }

  /// Get list of available windows for capture
  List<WindowInfo> getWindows() {
    if (Platform.isMacOS) return [];
    if (!Platform.isWindows) return [];
    return DesktopCapture.instance.getWindows();
  }

  /// Get list of available displays for capture
  List<DisplayInfo> getDisplays() {
    if (Platform.isMacOS) return [];
    if (!Platform.isWindows) return [];
    return DesktopCapture.instance.getDisplays();
  }

  /// Capture a window thumbnail
  Uint8List? captureWindowThumbnail(int hwnd, {int? width, int? height}) {
    if (Platform.isMacOS) return null;
    if (!Platform.isWindows) return null;
    return DesktopCapture.instance.captureWindow(
      hwnd,
      thumbnailWidth: width ?? 320,
      thumbnailHeight: height ?? 180,
    );
  }

  /// Capture a display thumbnail
  Uint8List? captureDisplayThumbnail(
    int displayIndex, {
    int? width,
    int? height,
  }) {
    if (Platform.isMacOS) return null;
    if (!Platform.isWindows) return null;
    return DesktopCapture.instance.captureDisplay(
      displayIndex,
      thumbnailWidth: width ?? 320,
      thumbnailHeight: height ?? 180,
    );
  }

  /// Capture entire screen (primary monitor)
  Uint8List? captureScreenThumbnail({int? width, int? height}) {
    if (Platform.isMacOS) return null;
    if (!Platform.isWindows) return null;
    return DesktopCapture.instance.captureScreen(
      thumbnailWidth: width ?? 320,
      thumbnailHeight: height ?? 180,
    );
  }

  void _notifyListeners() {
    if (!_devicesController.isClosed) {
      _devicesController.add(allDevices);
    }
  }
}

/// Helper extension for null-safe first-where
extension _ListExtension<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

/// Internal camera info class
class _CameraInfo {
  _CameraInfo({required this.id, required this.name, required this.detail});

  final String id;
  final String name;
  final String detail;
}
