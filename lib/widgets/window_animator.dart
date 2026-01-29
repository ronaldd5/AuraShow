import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class WindowAnimator extends StatefulWidget {
  final Widget child;
  const WindowAnimator({super.key, required this.child});

  static WindowAnimatorState? of(BuildContext context) {
    return context.findAncestorStateOfType<WindowAnimatorState>();
  }

  @override
  State<WindowAnimator> createState() => WindowAnimatorState();
}

class WindowAnimatorState extends State<WindowAnimator>
    with WindowListener, SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150), // Very fast
    );

    // Curve: Accelerate smoothly (no overshoot/backup)
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInCubic,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.1).animate(curve);
    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(curve);

    // Default to "Open"
    _controller.value = 0.0;
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _controller.dispose();
    super.dispose();
  }

  /// Call this instead of windowManager.minimize()
  Future<void> animateAndMinimize() async {
    // 1. Play the "Shrink" animation
    await _controller.forward();

    // 2. Actually minimize the window
    await windowManager.minimize();

    // 3. Reset animation instantly so it's ready for restore
    // (We do this while hidden so the user doesn't see it snap back)
    _controller.reset();
  }

  @override
  void onWindowRestore() {
    // Optional: You can try to animate "Up" here, but Windows
    // often shows the window fully painted before Flutter can catch it.
    // For best results on Windows, we usually just snap to full size on restore.
    _controller.reset();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      // OPTIMIZATION: Build the child ONCE, wrap in RepaintBoundary
      child: RepaintBoundary(child: widget.child),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          alignment: Alignment.bottomCenter,
          child: Opacity(
            opacity: _opacityAnimation.value.clamp(0.0, 1.0),
            child: child, // Reuse the cached child
          ),
        );
      },
    );
  }
}
