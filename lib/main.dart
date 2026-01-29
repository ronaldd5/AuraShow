import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

// Deferred imports to prevent platform crashes
import 'platforms/windows/windows_init.dart' deferred as win_init;
import 'platforms/macos/macos_init.dart' deferred as mac_init;

// NATIVE WIN32
import 'package:win32/win32.dart' as win32;

import 'app.dart';
import 'screens/projection/projection.dart';

Future<void> main(List<String> args) async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      MediaKit.ensureInitialized();

      // --- Multi-Window Projection Check ---
      if (args.isNotEmpty && args.first == 'multi_window') {
        final windowId = int.parse(args[1]);
        final argument = args[2].isEmpty
            ? const {}
            : jsonDecode(args[2]) as Map<String, dynamic>;

        if (Platform.isWindows) {
          await win_init.loadLibrary();
          win_init.registerPlatformWebview();
        } else if (Platform.isMacOS) {
          await mac_init.loadLibrary();
          mac_init.registerPlatformWebview();
        }

        // Initialize WindowManager for the secondary window
        // REMOVED (Caused crash)
        // await windowManager.ensureInitialized(); ...

        // Fix: Use 'initialData' instead of 'args'
        runApp(ProjectionWindow(windowId: windowId, initialData: argument));
        return;
      }

      // --- Main App Initialization ---
      if (!kIsWeb &&
          (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        await windowManager.ensureInitialized();

        // NATIVE FEEL CONFIGURATION
        WindowOptions windowOptions = const WindowOptions(
          size: Size(1280, 720),
          center: true,
          backgroundColor: Colors.transparent,
          skipTaskbar: false,
          // Hide standard title bar to use macOS "Traffic Lights" or Windows Custom Bar
          titleBarStyle: TitleBarStyle.hidden,
        );

        await windowManager.waitUntilReadyToShow(windowOptions, () async {
          await windowManager.show();
          await windowManager.focus();
        });
      }

      if (!kIsWeb) {
        if (Platform.isWindows) {
          try {
            await win_init.loadLibrary();
            win_init.registerPlatformWebview();
          } catch (e) {
            debugPrint('Error initializing Windows components: $e');
          }
        } else if (Platform.isMacOS) {
          try {
            await mac_init.loadLibrary();
            mac_init.registerPlatformWebview();
          } catch (e) {
            debugPrint('Error initializing macOS components: $e');
          }
        }
      }

      runApp(const AuraShowApp());
    },
    (error, stack) {
      debugPrint('boot: Uncaught error: $error');
      debugPrint('$stack');
    },
  );
}
