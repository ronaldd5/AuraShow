import 'dart:async';

/// Constants for the projection window module.

/// Toggle projection-window video playback using video_player (not media_kit).
const bool kEnableProjectionVideo = bool.fromEnvironment(
  'AURASHOW_ENABLE_PROJECTION_VIDEO',
  defaultValue: true,
);

/// Toggle foreground layer video playback in projection windows.
const bool kEnableProjectionForegroundVideo = bool.fromEnvironment(
  'AURASHOW_ENABLE_PROJECTION_FOREGROUND_VIDEO',
  defaultValue: true,
);

/// Queue for serializing video player initialization.
/// video_player_win crashes when multiple players initialize concurrently.
class VideoInitQueue {
  static final VideoInitQueue _instance = VideoInitQueue._();
  static VideoInitQueue get instance => _instance;
  VideoInitQueue._();

  final List<Future<void> Function()> _queue = [];
  bool _processing = false;

  /// Add an initialization task to the queue.
  /// Returns a Future that completes when this task finishes.
  Future<void> enqueue(Future<void> Function() task) async {
    final completer = Completer<void>();
    _queue.add(() async {
      try {
        await task();
        completer.complete();
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    _processQueue();
    return completer.future;
  }

  Future<void> _processQueue() async {
    if (_processing) return;
    _processing = true;
    while (_queue.isNotEmpty) {
      final task = _queue.removeAt(0);
      try {
        await task();
      } catch (_) {
        // Errors handled by completer
      }
      // Delay between video initializations to let native resources settle
      await Future.delayed(const Duration(milliseconds: 300));
    }
    _processing = false;
  }
}

/// Default stage dimensions for projection
const double kStageWidth = 1920;
const double kStageHeight = 1080;
