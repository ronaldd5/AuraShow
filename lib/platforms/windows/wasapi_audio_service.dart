import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:win32/win32.dart';
import '../interface/audio_service_interface.dart';

class WindowsAudioService implements AudioService {
  final _devicesController = StreamController<List<AudioDevice>>.broadcast();
  @override
  Stream<List<AudioDevice>> get devicesStream => _devicesController.stream;

  final List<AudioDevice> _devices = [];
  @override
  List<AudioDevice> get devices => List.unmodifiable(_devices);

  Timer? _scanTimer;
  bool _isInitialized = false;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      await refreshDevices();
      _scanTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => refreshDevices(),
      );
    } catch (e) {
      debugPrint('WindowsAudioService: Initialization failed: $e');
    }
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _devicesController.close();
    _isInitialized = false;
  }

  @override
  Future<void> refreshDevices() async {
    try {
      final newDevices = <AudioDevice>[];
      final systemDevices = await _enumerateWasapiDevices();
      newDevices.addAll(systemDevices);

      newDevices.insert(
        0,
        AudioDevice(
          id: 'system_loopback',
          name: 'System Audio (Default Output)',
          type: AudioDeviceType.loopback,
          isDefault: true,
        ),
      );

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

      if (!_devicesController.isClosed) {
        _devicesController.add(_devices);
      }
    } catch (e) {
      debugPrint('WindowsAudioService: Error refreshing devices: $e');
    }
  }

  @override
  AudioDevice? getDevice(String id) {
    for (final d in _devices) {
      if (d.id == id) return d;
    }
    return null;
  }

  @override
  AudioDevice? getDefaultDevice(AudioDeviceType type) {
    for (final d in _devices) {
      if (d.type == type && d.isDefault) return d;
    }
    for (final d in _devices) {
      if (d.type == type) return d;
    }
    return null;
  }

  Future<List<AudioDevice>> _enumerateWasapiDevices() async {
    try {
      return await Isolate.run(() {
        final devices = <AudioDevice>[];
        var hr = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
        if (FAILED(hr) && hr != RPC_E_CHANGED_MODE) return devices;

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
          devices.addAll(
            _getDevicesForFlowSync(
              enumerator,
              EDataFlow.eRender,
              AudioDeviceType.output,
            ),
          );
          devices.addAll(
            _getDevicesForFlowSync(
              enumerator,
              EDataFlow.eCapture,
              AudioDeviceType.input,
            ),
          );

          enumerator.release();
          free(enumeratorPtr);
        } finally {
          CoUninitialize();
        }
        return devices;
      });
    } catch (e) {
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
    collection.getCount(countPtr);
    final count = countPtr.value;
    free(countPtr);

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
        defaultId = idPtr.value.toDartString();
        CoTaskMemFree(idPtr.value);
      }
      free(idPtr);
      defaultDevice.release();
    }
    free(defaultDevicePtr);

    for (var i = 0; i < count; i++) {
      final devicePtr = calloc<COMObject>();
      if (SUCCEEDED(collection.item(i, devicePtr.cast()))) {
        final device = IMMDevice(devicePtr);
        final idPtr = calloc<Pointer<Utf16>>();
        String? id;
        if (SUCCEEDED(device.getId(idPtr))) {
          id = idPtr.value.toDartString();
          CoTaskMemFree(idPtr.value);
        }
        free(idPtr);

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
            if (pv.ref.vt == VARENUM.VT_LPWSTR)
              name = pv.ref.pwszVal.toDartString();
            PropVariantClear(pv);
          }
          free(pkey);
          free(pv);
          store.release();
        }
        free(storePtr);

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
      }
      free(devicePtr);
    }
    collection.release();
    free(collectionPtr);
    return result;
  }
}
