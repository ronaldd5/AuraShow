/// AuraShow - Professional Presentation Software
///
/// Entry point for the application. Handles both primary window initialization
/// and secondary projection window spawning.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show DartPluginRegistrant, PlatformDispatcher;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:media_kit/media_kit.dart';
import 'package:webview_flutter/webview_flutter.dart';
// NEW: Import window_manager
import 'package:window_manager/window_manager.dart';

import 'platforms/windows/windows_init.dart' deferred as win_init;
import 'platforms/macos/macos_init.dart' deferred as mac_init;

import 'app.dart';
import 'screens/projection/projection.dart';
import 'platforms/desktop_capture.dart';
import 'services/audio_device_service.dart';

Future<void> main(List<String> args) async {
  await runZonedGuarded(
    () async {
      debugPrint('boot: main start args=$args');

      WidgetsFlutterBinding.ensureInitialized();

      // 1. Initialize MediaKit (Video Player)
      try {
        debugPrint('boot: initializing MediaKit');
        MediaKit.ensureInitialized();
      } catch (e) {
        debugPrint('boot: MediaKit init error: $e');
      }

      // 2. Load Environment Variables
      try {
        await _loadEnvFromCommonLocations().timeout(
          const Duration(seconds: 2),
          onTimeout: () => debugPrint('boot: env load timed out'),
        );
      } catch (e) {
        debugPrint('boot: env load error: $e');
      }

      // 3. Handle Projection Window (Multi-Window)
      if (args.isNotEmpty && args.first == 'multi_window') {
        final windowId = int.parse(args[1]);
        final argument = args[2].isEmpty
            ? const {}
            : jsonDecode(args[2]) as Map<String, dynamic>;

        // Initialize Platform Services for Projection
        if (Platform.isWindows) {
          await win_init.loadLibrary();
          win_init.registerPlatformWebview();
        } else if (Platform.isMacOS) {
          await mac_init.loadLibrary();
          mac_init.registerPlatformWebview();
        }

        runApp(ProjectionWindow(windowId: windowId, initialData: argument));
        return;
      }

      // 4. MAIN WINDOW SETUP (The Fix for Blank Screen)
      if (!kIsWeb &&
          (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        await windowManager.ensureInitialized();

        WindowOptions windowOptions = const WindowOptions(
          size: Size(1280, 720),
          center: true,
          backgroundColor: Colors.transparent,
          skipTaskbar: false,
          titleBarStyle: TitleBarStyle.normal,
        );

        await windowManager.waitUntilReadyToShow(windowOptions, () async {
          await windowManager.show();
          await windowManager.focus();
        });
      }

      // 5. Platform Specific Init
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

      // 6. Platform Services (Capture, Audio)
      try {
        debugPrint('boot: initializing DesktopCapture');
        await DesktopCapture.instance.initialize().timeout(
          const Duration(seconds: 5),
          onTimeout: () => debugPrint('boot: DesktopCapture init timed out'),
        );
      } catch (e) {
        debugPrint('boot: DesktopCapture init error: $e');
      }

      try {
        debugPrint('boot: initializing AudioDeviceService');
        await AudioDeviceService.initialize().timeout(
          const Duration(seconds: 5),
          onTimeout: () =>
              debugPrint('boot: AudioDeviceService init timed out'),
        );
      } catch (e) {
        debugPrint('boot: AudioDeviceService init error: $e');
      }

      // 7. Run the App
      debugPrint('boot: launching primary app');
      runApp(const AuraShowApp());
    },
    (error, stack) {
      debugPrint('boot: Uncaught error: $error');
      debugPrint('$stack');
    },
  );
}

/// Load environment variables from common locations.
Future<void> _loadEnvFromCommonLocations() async {
  const envFileName = '.env';
  await _tryAssetEnv(envFileName);

  if (!kIsWeb) {
    final paths = <String>{
      envFileName,
      '${Directory.current.path}${Platform.pathSeparator}$envFileName',
      '${File(Platform.resolvedExecutable).parent.path}${Platform.pathSeparator}$envFileName',
    };
    for (final path in paths) {
      await _tryFileMerge(path);
    }
  }
}

Future<void> _tryAssetEnv(String name) async {
  try {
    await dotenv.load(
      fileName: name,
      mergeWith: dotenv.isInitialized ? dotenv.env : <String, String>{},
    );
  } catch (_) {
    // Ignore missing asset file
  }
}

Future<void> _tryFileMerge(String path) async {
  final file = File(path);
  if (!await file.exists()) return;
  try {
    final lines = await file.readAsLines();
    final Map<String, String> envVars = {};
    for (var line in lines) {
      final parts = line.split('=');
      if (parts.length >= 2 && !line.trim().startsWith('#')) {
        envVars[parts[0].trim()] = parts.sublist(1).join('=').trim();
      }
    }
    if (dotenv.isInitialized) {
      dotenv.env.addAll(envVars);
    } else {
      // Manually load if dotenv isn't initialized
      // Note: dotenv doesn't expose a clean "init with map" without loading a file first,
      // but the merge above handles it mostly.
    }
  } catch (e) {
    debugPrint('Error reading env file at $path: $e');
  }
}
