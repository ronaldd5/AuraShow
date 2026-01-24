/// Audio Device Service for AuraShow
/// Enumerates audio input and output devices on Windows using WASAPI
library;

import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:win32/win32.dart';

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

/// Service for managing audio device discovery using Windows WASAPI
class AudioDeviceService {
  AudioDeviceService._();
  static final AudioDeviceService instance = AudioDeviceService._();

  final _devicesController = StreamController<List<AudioDevice>>.broadcast();
  Stream<List<AudioDevice>> get devicesStream => _devicesController.stream;

  final List<AudioDevice> _devices = [];
  List<AudioDevice> get devices => List.unmodifiable(_devices);

  List<AudioDevice> get outputs =>
      _devices.where((d) => d.type == AudioDeviceType.output).toList();
  List<AudioDevice> get inputs =>
      _devices.where((d) => d.type == AudioDeviceType.input).toList();
  List<AudioDevice> get loopbacks =>
      _devices.where((d) => d.type == AudioDeviceType.loopback).toList();

  Timer? _scanTimer;
  bool _isInitialized = false;

  /// Initialize the audio device service
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      stdout.writeln('AudioDeviceService: initialize() start');
      // Initial device scan
      await refreshDevices();

      // Start periodic scanning (every 10 seconds)
      _scanTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => refreshDevices(),
      );
      stdout.writeln('AudioDeviceService: initialize() success');
    } catch (e) {
      stdout.writeln('AudioDeviceService: Initialization failed: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _scanTimer?.cancel();
    _devicesController.close();
    _isInitialized = false;
  }

  /// Refresh the list of audio devices using WASAPI
  Future<void> refreshDevices() async {
    try {
      final newDevices = <AudioDevice>[];

      // Enumerate actual Windows audio devices via WASAPI
      final systemDevices = await _enumerateWasapiDevices();
      newDevices.addAll(systemDevices);

      // Add System Audio (default loopback) pseudo-device
      newDevices.insert(
        0,
        AudioDevice(
          id: 'system_loopback',
          name: 'System Audio (Default Output)',
          type: AudioDeviceType.loopback,
          isDefault: true,
        ),
      );

      // Add app audio option
      newDevices.add(
        AudioDevice(
          id: 'app_audio',
          name: 'App Audio (Music Player)',
          type: AudioDeviceType.loopback,
        ),
      );

      _devices
        ..clear()
        ..addAll(newDevices);

      _notifyListeners();
    } catch (e) {
      stdout.writeln('AudioDeviceService: Error refreshing devices: $e');
    }
  }

  /// Enumerate audio devices using WASAPI in a separate Isolate
  Future<List<AudioDevice>> _enumerateWasapiDevices() async {
    try {
      return await Isolate.run(() {
        final devices = <AudioDevice>[];
        // Initialize COM as MTA in the background Isolate
        var hr = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
        if (FAILED(hr) && hr != RPC_E_CHANGED_MODE) {
          return devices;
        }

        try {
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
            return devices;
          }

          final enumerator = MMDeviceEnumerator(enumeratorPtr);

          // Enumerate Output devices (eRender)
          devices.addAll(
            _getDevicesForFlowSync(
              enumerator,
              EDataFlow.eRender,
              AudioDeviceType.output,
            ),
          );

          // Enumerate Input devices (eCapture)
          devices.addAll(
            _getDevicesForFlowSync(
              enumerator,
              EDataFlow.eCapture,
              AudioDeviceType.input,
            ),
          );

          enumerator.release();
          free(enumeratorPtr);
        } catch (e) {
          debugPrint(
            'AudioDeviceService Isolate: Error during enumeration: $e',
          );
        } finally {
          CoUninitialize();
        }

        return devices;
      });
    } catch (e, stack) {
      debugPrint(
        'AudioDeviceService: CRITICAL Error enumerating WASAPI devices: $e',
      );
      debugPrint('$stack');
      return [];
    }
  }

  static List<AudioDevice> _getDevicesForFlowSync(
    MMDeviceEnumerator enumerator,
    int dataFlow,
    AudioDeviceType type,
  ) {
    final result = <AudioDevice>[];

    final collectionPtr = calloc<COMObject>();
    var hr = enumerator.enumAudioEndpoints(
      dataFlow,
      DEVICE_STATE_ACTIVE,
      collectionPtr.cast(),
    );
    if (FAILED(hr)) {
      free(collectionPtr);
      return result;
    }

    final collection = IMMDeviceCollection(collectionPtr);
    final countPtr = calloc<UINT>();
    hr = collection.getCount(countPtr);
    if (FAILED(hr)) {
      free(countPtr);
      collection.release();
      free(collectionPtr);
      return result;
    }

    final count = countPtr.value;
    free(countPtr);

    // Get default device ID to mark it
    String? defaultId;
    final defaultDevicePtr = calloc<COMObject>();
    hr = enumerator.getDefaultAudioEndpoint(
      dataFlow,
      ERole.eConsole,
      defaultDevicePtr.cast(),
    );
    if (SUCCEEDED(hr)) {
      final defaultDevice = IMMDevice(defaultDevicePtr);
      final idPtr = calloc<Pointer<Utf16>>();
      if (SUCCEEDED(defaultDevice.getId(idPtr))) {
        if (idPtr.value != nullptr) {
          defaultId = idPtr.value.toDartString();
          CoTaskMemFree(idPtr.value);
        }
      }
      free(idPtr);
      defaultDevice.release();
      free(defaultDevicePtr);
    } else {
      free(defaultDevicePtr);
    }

    for (var i = 0; i < count; i++) {
      final devicePtr = calloc<COMObject>();
      hr = collection.item(i, devicePtr.cast());
      if (SUCCEEDED(hr)) {
        final device = IMMDevice(devicePtr);

        // Get ID
        final idPtr = calloc<Pointer<Utf16>>();
        String? id;
        if (SUCCEEDED(device.getId(idPtr))) {
          if (idPtr.value != nullptr) {
            id = idPtr.value.toDartString();
            CoTaskMemFree(idPtr.value);
          }
        }
        free(idPtr);

        // Get Name
        String name = 'Unknown Device';
        final storePtr = calloc<COMObject>();
        if (SUCCEEDED(
          device.openPropertyStore(STGM.STGM_READ, storePtr.cast()),
        )) {
          final store = IPropertyStore(storePtr);
          final pv = calloc<PROPVARIANT>();
          final pkey = calloc<PROPERTYKEY>();
          pkey.ref.fmtid.setGUID('{a45c2502-df1c-4efd-8020-67d146a850e0}');
          pkey.ref.pid = 14;

          if (SUCCEEDED(store.getValue(pkey, pv))) {
            if (pv.ref.vt == VARENUM.VT_LPWSTR) {
              name = pv.ref.pwszVal.toDartString();
            }
            PropVariantClear(pv);
          }
          free(pkey);
          free(pv);
          store.release();
          free(storePtr);
        } else {
          free(storePtr);
        }

        if (id != null) {
          result.add(
            AudioDevice(
              id: id,
              name: name,
              type: type,
              isDefault: id == defaultId,
            ),
          );
        }
        device.release();
        free(devicePtr);
      } else {
        free(devicePtr);
      }
    }
    collection.release();
    free(collectionPtr);

    return result;
  }

  void _notifyListeners() {
    if (!_devicesController.isClosed) {
      _devicesController.add(_devices);
    }
  }

  /// Get device by ID
  AudioDevice? getDevice(String id) {
    return _devices.firstWhereOrNull((d) => d.id == id);
  }

  /// Get default device for a type
  AudioDevice? getDefaultDevice(AudioDeviceType type) {
    return _devices.firstWhereOrNull((d) => d.type == type && d.isDefault) ??
        _devices.firstWhereOrNull((d) => d.type == type);
  }
}

extension _AudioListExtension<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
