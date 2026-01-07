import 'package:flutter/material.dart';

/// A widget that catches errors in its child widget tree and displays a
/// fallback UI instead of crashing the entire application.
class ErrorBoundary extends StatefulWidget {
  const ErrorBoundary({
    super.key,
    required this.child,
    this.fallback,
    this.onError,
  });

  final Widget child;
  final Widget? fallback;
  final void Function(Object error, StackTrace? stack)? onError;

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;
  StackTrace? _stack;

  @override
  void initState() {
    super.initState();
    // Reset error when widget is rebuilt
    _error = null;
    _stack = null;
  }

  void _handleError(Object error, StackTrace? stack) {
    setState(() {
      _error = error;
      _stack = stack;
    });
    widget.onError?.call(error, stack);
    debugPrint('ErrorBoundary caught: $error');
    if (stack != null) debugPrint('$stack');
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return widget.fallback ?? _DefaultErrorWidget(error: _error!, onRetry: () {
        setState(() {
          _error = null;
          _stack = null;
        });
      });
    }

    return _ErrorBoundaryScope(
      onError: _handleError,
      child: widget.child,
    );
  }
}

class _ErrorBoundaryScope extends InheritedWidget {
  const _ErrorBoundaryScope({
    required this.onError,
    required super.child,
  });

  final void Function(Object error, StackTrace? stack) onError;

  static _ErrorBoundaryScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_ErrorBoundaryScope>();
  }

  @override
  bool updateShouldNotify(_ErrorBoundaryScope oldWidget) => false;
}

class _DefaultErrorWidget extends StatelessWidget {
  const _DefaultErrorWidget({
    required this.error,
    required this.onRetry,
  });

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Content could not be loaded',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString().length > 100 
                  ? '${error.toString().substring(0, 100)}...' 
                  : error.toString(),
              style: const TextStyle(color: Colors.white38, fontSize: 11),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A simpler error placeholder for media that fails to load
class MediaErrorPlaceholder extends StatelessWidget {
  const MediaErrorPlaceholder({
    super.key,
    this.message = 'Media could not load',
    this.icon = Icons.broken_image_outlined,
    this.backgroundColor = Colors.black54,
  });

  final String message;
  final IconData icon;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white38, size: 32),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
