import 'package:flutter/material.dart';

class SlideTransitionEngine extends StatefulWidget {
  final Widget child;
  final String transitionType;
  final Duration duration;

  const SlideTransitionEngine({
    super.key,
    required this.child,
    this.transitionType = 'fade',
    this.duration = const Duration(milliseconds: 600),
  });

  @override
  State<SlideTransitionEngine> createState() => _SlideTransitionEngineState();
}

class _SlideTransitionEngineState extends State<SlideTransitionEngine>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // We keep a stack of widgets.
  // Normally it has 1 item (current).
  // During transition it has 2 items (old at 0, new at 1).
  List<Widget> _stack = [];
  Widget? _currentChild;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _controller.addStatusListener(_onAnimationStatusChanged);

    _currentChild = widget.child;
    _stack.add(widget.child);
  }

  @override
  void didUpdateWidget(SlideTransitionEngine oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If key changed, we need to transition
    if (widget.child.key != oldWidget.child.key) {
      if (_controller.isAnimating) {
        // If already animating, we jump to end (finish previous transition)
        // and start new one. Or we could chain them.
        // For simplicity, let's complete the previous one instantly.
        _controller.value = 1.0;
      }

      setState(() {
        _currentChild = widget.child;
        _stack.add(widget.child);
        _controller.duration = widget.duration;
        _controller.forward(from: 0.0);
      });
    }
  }

  void _onAnimationStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      // Transition finished. Remove the old slide (index 0)
      setState(() {
        if (_stack.length > 1) {
          _stack.removeAt(0);
        }
        _controller.value = 0.0;
      });
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onAnimationStatusChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If not animating, just show the single child (or the stack which should have 1 item)
    // But for consistency let's always render the stack.

    // Attempt optimization: if only 1 item, just return it?
    // Using Stack always ensures layout consistency.

    return Stack(fit: StackFit.expand, children: _buildStackChildren());
  }

  List<Widget> _buildStackChildren() {
    // If stack has 1 item, just return it
    if (_stack.length == 1) {
      return [_stack.single];
    }

    // If stack has 2 items: 0 is OLD, 1 is NEW.
    // We only animate the NEW one (or both depending on effect).

    final oldSlide = _stack[0];
    final newSlide = _stack[1];

    return [
      oldSlide,
      // Animate new slide entering
      AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return _applyTransition(
            child: child!,
            progress: _controller.value,
            type: widget.transitionType,
          );
        },
        child: newSlide,
      ),
    ];
  }

  Widget _applyTransition({
    required Widget child,
    required double progress,
    required String type,
  }) {
    // Use Curves
    final curvedProgress = Curves.easeInOut.transform(progress);

    switch (type) {
      case 'push':
        // Push Left: Old slide stays (covered), New slide comes from Right to Left?
        // Standard "Push" usually implies both move.
        // Let's implement "Cover Left" for now (New slide moves in from right)
        // as requested in prompt "Push Left: Transform.translate(offset: Offset(screen_width * (1 - value), 0))"
        final width = MediaQuery.of(context).size.width;
        final offset = width * (1.0 - curvedProgress);
        return Transform.translate(offset: Offset(offset, 0), child: child);

      case 'wipe':
        return ClipRect(
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: curvedProgress,
            child: child,
          ),
        );

      case 'iris':
        return ClipPath(clipper: IrisClipper(curvedProgress), child: child);

      case 'fade':
      default:
        return Opacity(opacity: curvedProgress, child: child);
    }
  }
}

class IrisClipper extends CustomClipper<Path> {
  final double progress;

  IrisClipper(this.progress);

  @override
  Path getClip(Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // Radius must cover the corners. Distance from center to corner is sqrt((w/2)^2 + (h/2)^2)
    // Simplified: max dimension is sufficient usually, but let's be precise.
    // actually just diagonal / 2.
    final maxRadius =
        (Offset.zero - Offset(size.width, size.height)).distance / 2;
    // But we are centering, so distance from center to corner.
    // center (w/2, h/2) to (0,0) distance.
    final radius = center.distance * 1.5; // 1.5 safety factor

    return Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius * progress));
  }

  @override
  bool shouldReclip(IrisClipper oldClipper) => oldClipper.progress != progress;
}
