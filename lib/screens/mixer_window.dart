import 'dart:ffi';
import 'package:win32/win32.dart';
import 'package:flutter/material.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import '../services/xair_service.dart';
import 'dashboard/widgets/mixer_console.dart';
import '../core/theme/palette.dart';

class MixerWindow extends StatefulWidget {
  final int windowId;
  final Map<String, dynamic> args;

  const MixerWindow({super.key, required this.windowId, required this.args});

  @override
  State<MixerWindow> createState() => _MixerWindowState();
}

class _MixerWindowState extends State<MixerWindow> {
  @override
  void initState() {
    super.initState();
    // Auto-connect if IP was passed
    if (widget.args['ip'] != null) {
      // Small delay to ensure UI is ready
      Future.delayed(const Duration(milliseconds: 500), () {
        XAirService.instance.connectToIp(widget.args['ip']);
      });
    }

    // --- SETUP SYNC ---
    // 1. Listen for updates FROM Main Window
    DesktopMultiWindow.setMethodHandler((call, fromWindowId) async {
      if (call.method == 'xair_sync') {
        Future.microtask(() {
          try {
            final data = call.arguments as Map;
            final type = data['type'] as String;
            final ch = data['ch'] as int;
            final val = data['val'];

            if (type == 'fader') {
              final dVal = (val is num) ? val.toDouble() : 0.0;
              XAirService.instance.updateLocalFader(ch, dVal);
            } else if (type == 'mute') {
              final bVal = (val is bool) ? val : false;
              XAirService.instance.updateLocalMute(ch, bVal);
            }
          } catch (e) {
            // Sync error
          }
        });
      }
      return null;
    });

    // 2. Broadcast updates TO Main Window (ID 0)
    XAirService.instance.onSyncAction = (type, ch, val) {
      debugPrint('MixerWindow: Sending sync to Main (0) - $type $ch $val');
      DesktopMultiWindow.invokeMethod(0, 'xair_sync', {
        'type': type,
        'ch': ch,
        'val': val,
      });
    };
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppPalette.carbonBlack,
        colorScheme: const ColorScheme.dark(primary: AppPalette.accent),
      ),
      home: Scaffold(
        body: Stack(
          children: [
            Column(
              children: [
                // Custom Window Title Bar
                Listener(
                  onPointerDown: (_) {
                    final hwnd = GetForegroundWindow();
                    if (IsWindow(hwnd) != 0) {
                      ReleaseCapture();
                      SendMessage(hwnd, WM_SYSCOMMAND, 0xF012, 0);
                    }
                  },
                  behavior: HitTestBehavior.translucent,
                  child: Container(
                    height: kToolbarHeight,
                    color: const Color(0xFF222222),
                    child: Stack(
                      children: [
                        // Controls overlay
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () async {
                                await WindowController.fromWindowId(
                                  widget.windowId,
                                ).close();
                              },
                              tooltip: 'Close Window',
                            ),
                            Expanded(
                              child: IgnorePointer(
                                child: Center(
                                  child: Text(
                                    'Audio Mixer',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.cast_connected),
                              onPressed: () {},
                            ),
                            AnimatedBuilder(
                              animation: XAirService.instance,
                              builder: (context, _) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 16),
                                  child: Center(
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: XAirService.instance.isConnected
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const Expanded(child: MixerConsole()),
              ],
            ),
            // Resize Handle (Bottom Right)
            Positioned(
              right: 0,
              bottom: 0,
              child: Listener(
                onPointerDown: (_) {
                  final hwnd = GetForegroundWindow();
                  if (IsWindow(hwnd) != 0) {
                    ReleaseCapture();
                    // WM_NCLBUTTONDOWN = 0xA1, HTBOTTOMRIGHT = 17
                    SendMessage(hwnd, 0x00A1, 17, 0);
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeUpLeftDownRight,
                  child: Container(
                    width: 30, // Larger touch target
                    height: 30,
                    decoration: const BoxDecoration(
                      color: Color(0xFF333333), // Visible corner background
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(8),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.south_east,
                      size: 20, // Larger icon
                      color: Colors.white, // High contrast
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
