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
import 'package:webview_win_floating/webview_win_floating.dart';

///import 'package:webview_flutter_web/webview_flutter_web.dart';

import 'app.dart';
import 'screens/projection/projection.dart';

Future<void> main(List<String> args) async {
  await runZonedGuarded(
    () async {
      debugPrint('boot: main start args=$args');

      WidgetsFlutterBinding.ensureInitialized();

      // Fix for WebView/YouTube implementation on desktop and web
      // Fix for WebView/YouTube implementation on desktop and web
      if (kIsWeb) {
        // WebViewPlatform.instance = WebWebViewPlatform();
      } else if (Platform.isWindows) {
        WebViewPlatform.instance = WindowsWebViewPlatform();
      } else if (Platform.isMacOS) {
        // macOS uses standard webview_flutter_wkwebview via default instance
      }

      // Optimize image cache to reduce memory usage (was 500MB)
      PaintingBinding.instance.imageCache.maximumSizeBytes =
          100 * 1024 * 1024; // 100MB
      PaintingBinding.instance.imageCache.maximumSize =
          50; // Limit cached images

      // Surface uncaught errors so native runner doesn't tear down unexpectedly.
      FlutterError.onError = (details) {
        FlutterError.dumpErrorToConsole(details);
        Zone.current.handleUncaughtError(
          details.exception,
          details.stack ?? StackTrace.empty,
        );
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        debugPrint('boot: unhandled error (dispatcher) $error');
        debugPrint('$stack');
        return true;
      };

      // Secondary windows branch early; skip env loading and MediaKit init.
      if (args.firstOrNull == 'multi_window') {
        await _launchProjectionWindow(args);
        return;
      }

      // Primary window: load env and init MediaKit
      await _loadEnvFromCommonLocations();
      if (kEnableProjectionVideo) {
        MediaKit.ensureInitialized();
      }

      runApp(const AuraShowApp());
      debugPrint('boot: launched primary app');
    },
    (error, stackTrace) {
      debugPrint('boot: unhandled zone error=$error');
      debugPrint('$stackTrace');
    },
  );
}

/// Launch a secondary projection window for external display output.
Future<void> _launchProjectionWindow(List<String> args) async {
  try {
    debugPrint(
      'boot: launching projection window for id=${args.elementAtOrNull(1)}',
    );
    final int windowId = int.parse(args[1]);
    final Map data = args.length > 2
        ? (json.decode(args[2]) as Map? ?? const {})
        : const {};
    DartPluginRegistrant.ensureInitialized();

    // Show a minimal shell first to let the secondary engine stabilize.
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Builder(
          builder: (context) {
            // Schedule actual projection widget for next frame.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              try {
                runApp(ProjectionWindow(windowId: windowId, initialData: data));
              } catch (e, st) {
                debugPrint('boot: projection runApp inner failed error=$e');
                debugPrint('$st');
              }
            });
            return const Scaffold(backgroundColor: Colors.black);
          },
        ),
      ),
    );
  } catch (e, st) {
    debugPrint(
      'boot: projection launch failed, showing blank window. error=$e',
    );
    debugPrint('$st');
    runApp(const MaterialApp(home: Scaffold(backgroundColor: Colors.black)));
  }
}

/// Load environment variables from common locations.
Future<void> _loadEnvFromCommonLocations() async {
  const envFileName = '.env';
  // 1) Try loading from bundled asset (requires .env declared in pubspec.yaml).
  await _tryAssetEnv(envFileName);

  // 2) Try merging from filesystem locations for development/packaged builds.
  final paths = <String>{
    envFileName,
    '${Directory.current.path}${Platform.pathSeparator}$envFileName',
    '${File(Platform.resolvedExecutable).parent.path}${Platform.pathSeparator}$envFileName',
  };
  for (final path in paths) {
    await _tryFileMerge(path);
  }
}

Future<void> _tryAssetEnv(String name) async {
  try {
    await dotenv.load(
      fileName: name,
      mergeWith: dotenv.isInitialized ? dotenv.env : <String, String>{},
    );
  } catch (_) {
    // Asset not found or load failed; continue to file-based fallbacks.
  }
}

Future<void> _tryFileMerge(String path) async {
  final file = File(path);
  if (!await file.exists()) return;
  try {
    final contents = await file.readAsString();
    dotenv.testLoad(
      fileInput: contents,
      mergeWith: dotenv.isInitialized ? dotenv.env : <String, String>{},
    );
  } catch (_) {
    // Ignore unreadable files; loader remains best-effort.
  }
}
