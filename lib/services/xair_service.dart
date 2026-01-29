import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';

// Basic XAir / OSC Service implementation
class XAirService extends ChangeNotifier {
  static final XAirService instance = XAirService._();
  XAirService._();

  RawDatagramSocket? _socket;
  String? _mixerIp;
  final int _mixerPort = 10024;
  bool _isConnected = false;
  Timer? _keepAliveTimer;

  // Channel Fader State (0.0 to 1.0)
  // Map channel index (1-18) to value
  final Map<int, double> _faders = {};

  // Channel Mute State (true = muted)
  final Map<int, bool> _mutes = {};

  bool get isConnected => _isConnected;
  String? get mixerIp => _mixerIp;

  double getFader(int channel) => _faders[channel] ?? 0.0;
  bool getMute(int channel) => _mutes[channel] ?? false;

  Future<void> connect({String? ip}) async {
    _socket?.close();

    // Bind to any local port
    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _socket!.broadcastEnabled = true; // Enable broadcast for auto-discovery
      _socket!.listen(_onData);

      if (ip != null) {
        connectToIp(ip);
      } else {
        _discoverMixer();
      }
    } catch (e) {
      debugPrint('XAir: Bind error $e');
    }
  }

  void _discoverMixer() {
    debugPrint('XAir: Discovering...');
    // Send /xinfo to broadcast address
    // This allows the mixer to reply with its IP details
    _sendOsc('/xinfo', [], '255.255.255.255');
  }

  // Callback for multi-window sync (user actions triggered here)
  Function(String type, int channel, dynamic value)? onSyncAction;

  void connectToIp(String ip) {
    _mixerIp = ip;
    _isConnected = true;
    _startKeepAlive();
    notifyListeners();
    refreshAll();
  }

  // Push local state to mixer (Sync)
  void pushAll() {
    if (!_isConnected || _mixerIp == null) return;

    // Push faders
    _faders.forEach((channel, value) {
      final ch = channel.toString().padLeft(2, '0');
      _sendOsc('/ch/$ch/mix/fader', [value]);
    });

    // Push mutes
    _mutes.forEach((channel, isMuted) {
      final ch = channel.toString().padLeft(2, '0');
      _sendOsc('/ch/$ch/mix/on', [isMuted ? 0 : 1]);
    });
  }

  void disconnect() {
    _keepAliveTimer?.cancel();
    _socket?.close();
    _socket = null;
    _isConnected = false;
    _mixerIp = null; // Clear IP on explicit disconnect
    notifyListeners();
  }

  void _startKeepAlive() {
    _keepAliveTimer?.cancel();
    // XAir requires /xremote sent every <10s to send updates to us
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (_mixerIp != null) {
        _sendOsc('/xremote', []);
      }
    });
    // Send immediately
    _sendOsc('/xremote', []);
  }

  Future<void> refreshAll() async {
    // Request full status (simplified)
    for (int i = 1; i <= 16; i++) {
      _sendOsc('/ch/${i.toString().padLeft(2, '0')}/mix/fader', []);
      _sendOsc('/ch/${i.toString().padLeft(2, '0')}/mix/on', []);
    }
  }

  // Called by UI: Updates local, sends OSC, triggers Sync
  void setFader(int channel, double value) {
    if (_faders[channel] == value) return; // Debounce
    _faders[channel] = value;
    notifyListeners();

    // Send OSC
    if (_isConnected) {
      final ch = channel.toString().padLeft(2, '0');
      _sendOsc('/ch/$ch/mix/fader', [value]);
    }

    // Trigger Sync
    onSyncAction?.call('fader', channel, value);
  }

  // Called by Sync Listener: Updates local ONLY (No OSC, No Sync Loop)
  void updateLocalFader(int channel, double value) {
    if (_faders[channel] == value) return;
    _faders[channel] = value;
    notifyListeners();
  }

  void setMute(int channel, bool muted) {
    if (_mutes[channel] == muted) return;
    _mutes[channel] = muted;
    notifyListeners();

    if (_isConnected) {
      final ch = channel.toString().padLeft(2, '0');
      _sendOsc('/ch/$ch/mix/on', [muted ? 0 : 1]);
    }

    onSyncAction?.call('mute', channel, muted);
  }

  void updateLocalMute(int channel, bool muted) {
    if (_mutes[channel] == muted) return;
    _mutes[channel] = muted;
    notifyListeners();
  }

  void _onData(RawSocketEvent event) {
    if (event == RawSocketEvent.read) {
      final datagram = _socket?.receive();
      if (datagram != null) {
        if (!_isConnected && _mixerIp == null) {
          // Auto-detect IP from response?
          _mixerIp = datagram.address.address;
          _isConnected = true;
          _startKeepAlive();
          notifyListeners();
          refreshAll();
        }
        _parseOsc(datagram.data);
      }
    }
  }

  // --- OSC Minimal Implementation ---

  void _sendOsc(String address, List<dynamic> args, [String? destinationIp]) {
    final ip = destinationIp ?? _mixerIp;
    if (ip == null || _socket == null) return;

    final packet = BytesBuilder();

    // Address
    packet.add(_writeString(address));

    // Type Tag String
    String typeTag = ',';
    for (var arg in args) {
      if (arg is int)
        typeTag += 'i';
      else if (arg is double)
        typeTag += 'f';
      else if (arg is String)
        typeTag += 's';
    }
    packet.add(_writeString(typeTag));

    // Arguments
    for (var arg in args) {
      if (arg is int) {
        final b = ByteData(4)..setInt32(0, arg, Endian.big);
        packet.add(b.buffer.asUint8List());
      } else if (arg is double) {
        final b = ByteData(4)..setFloat32(0, arg, Endian.big);
        packet.add(b.buffer.asUint8List());
      } else if (arg is String) {
        packet.add(_writeString(arg));
      }
    }

    try {
      _socket!.send(packet.toBytes(), InternetAddress(ip), _mixerPort);
    } catch (e) {
      debugPrint('XAir: Send error $e');
    }
  }

  List<int> _writeString(String s) {
    final bytes = utf8.encode(s).toList();
    bytes.add(0); // Null terminator
    // Pad to 4 bytes
    while (bytes.length % 4 != 0) {
      bytes.add(0);
    }
    return bytes;
  }

  void _parseOsc(Uint8List data) {
    // Very basic parsing
    try {
      int offset = 0;

      // Read Address
      final addressEnd = data.indexOf(0, offset);
      if (addressEnd == -1) return; // Invalid
      // Round up to next 4 bytes
      int addressPadding = (addressEnd + 1 + 3) & ~3;
      final address = utf8.decode(data.sublist(offset, addressEnd));
      offset = addressPadding;

      if (offset >= data.length) return;

      // Read Type Tag
      final typeEnd = data.indexOf(0, offset);
      int typePadding = (typeEnd + 1 + 3) & ~3;
      final types = utf8.decode(data.sublist(offset, typeEnd));
      offset = typePadding;

      // Read Args
      for (int i = 1; i < types.length; i++) {
        // Skip ','
        final type = types[i];
        if (type == 'f') {
          if (offset + 4 > data.length) break;
          final val = ByteData.sublistView(
            data,
            offset,
            offset + 4,
          ).getFloat32(0, Endian.big);
          offset += 4;

          _handleUpdate(address, val);
        } else if (type == 'i') {
          if (offset + 4 > data.length) break;
          final val = ByteData.sublistView(
            data,
            offset,
            offset + 4,
          ).getInt32(0, Endian.big);
          offset += 4;

          _handleUpdate(address, val); // Int maps to bool/mute usually
        }
      }
    } catch (e) {
      // Ignored parsing error
    }
  }

  void _handleUpdate(String address, dynamic value) {
    // Address e.g. /ch/01/mix/fader
    final parts = address.split('/');
    if (parts.length >= 4 && parts[1] == 'ch' && parts[3] == 'mix') {
      final channel = int.tryParse(parts[2]);
      if (channel != null) {
        if (parts[4] == 'fader' && value is double) {
          _faders[channel] = value;
          notifyListeners(); // Debounce this in real app
        } else if (parts[4] == 'on' && value is int) {
          _mutes[channel] = (value == 0); // 0=off(muted), 1=on(unmuted)
          notifyListeners();
        }
      }
    }
  }
}
