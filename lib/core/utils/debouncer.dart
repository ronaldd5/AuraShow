import 'dart:async';

/// A debouncer that delays execution of a callback until a specified duration
/// has passed since the last call. Useful for rate-limiting expensive operations
/// like multi-window communication.
class Debouncer {
  Debouncer({required this.duration});

  final Duration duration;
  Timer? _timer;
  
  /// Calls [callback] after [duration] has passed since the last [call] invocation.
  /// Any pending callback is cancelled when a new call is made.
  void call(void Function() callback) {
    _timer?.cancel();
    _timer = Timer(duration, callback);
  }
  
  /// Immediately executes any pending callback and cancels the timer.
  void flush(void Function() callback) {
    _timer?.cancel();
    _timer = null;
    callback();
  }
  
  /// Cancels any pending callback.
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
  
  /// Returns true if there's a pending callback.
  bool get isPending => _timer?.isActive ?? false;
  
  /// Disposes the debouncer and cancels any pending callback.
  void dispose() {
    cancel();
  }
}

/// A throttler that ensures a callback is executed at most once per [duration].
/// Unlike [Debouncer], it executes immediately on first call then blocks subsequent
/// calls until the duration passes.
class Throttler {
  Throttler({required this.duration});

  final Duration duration;
  DateTime? _lastExecuted;
  Timer? _pendingTimer;
  void Function()? _pendingCallback;
  
  /// Executes [callback] immediately if [duration] has passed since last execution,
  /// otherwise schedules it to run after the remaining time.
  void call(void Function() callback) {
    final now = DateTime.now();
    
    if (_lastExecuted == null || now.difference(_lastExecuted!) >= duration) {
      // Execute immediately
      _lastExecuted = now;
      _pendingTimer?.cancel();
      _pendingCallback = null;
      callback();
    } else {
      // Schedule for later
      _pendingCallback = callback;
      _pendingTimer?.cancel();
      final remaining = duration - now.difference(_lastExecuted!);
      _pendingTimer = Timer(remaining, () {
        _lastExecuted = DateTime.now();
        _pendingCallback?.call();
        _pendingCallback = null;
      });
    }
  }
  
  /// Cancels any pending callback.
  void cancel() {
    _pendingTimer?.cancel();
    _pendingTimer = null;
    _pendingCallback = null;
  }
  
  /// Disposes the throttler and cancels any pending callback.
  void dispose() {
    cancel();
  }
}
