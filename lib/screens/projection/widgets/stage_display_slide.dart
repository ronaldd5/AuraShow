import 'dart:async';
import 'package:flutter/material.dart';
import '../../dashboard/models/stage_models.dart';
import '../../dashboard/widgets/stage_clock_widget.dart';
import '../models/projection_slide.dart';
import 'styled_slide.dart';

class StageDisplaySlide extends StatefulWidget {
  const StageDisplaySlide({
    super.key,
    required this.layout,
    required this.currentSlide,
    this.nextSlide,
    this.timerTarget,
    this.timerDuration = Duration.zero,
    this.stageWidth = 1920,
    this.stageHeight = 1080,
  });

  final StageLayout layout;
  final ProjectionSlide? currentSlide;
  final ProjectionSlide? nextSlide;
  final DateTime? timerTarget;
  final Duration timerDuration;
  final double stageWidth;
  final double stageHeight;

  @override
  State<StageDisplaySlide> createState() => _StageDisplaySlideState();
}

class _StageDisplaySlideState extends State<StageDisplaySlide> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        children: widget.layout.elements.map((e) {
          return Positioned(
            left: e.rect.left * widget.stageWidth,
            top: e.rect.top * widget.stageHeight,
            width: e.rect.width * widget.stageWidth,
            height: e.rect.height * widget.stageHeight,
            child: _buildElement(e),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildElement(StageElement element) {
    switch (element.type) {
      case StageElementType.clock:
        return _buildClock(element);
      case StageElementType.timer:
        return _buildTimer(element); // Placeholder for now
      case StageElementType.currentSlide:
        return _buildSlidePreview(widget.currentSlide, 'Current Slide');
      case StageElementType.nextSlide:
        return _buildSlidePreview(widget.nextSlide, 'Next Slide');
      case StageElementType.message:
        return _buildMessage(element);
      case StageElementType.customText:
        return _buildCustomText(element);
    }
  }

  Widget _buildClock(StageElement element) {
    return StageClockWidget(
      element: element,
      scale: widget.stageHeight / 1080.0,
    );
  }

  Widget _buildTimer(StageElement element) {
    if (widget.timerTarget != null) {
      // Countdown
      final remaining = widget.timerTarget!.difference(_now);
      final isNegative = remaining.isNegative;
      final absDuration = remaining.abs();
      final h = absDuration.inHours;
      final m = absDuration.inMinutes % 60;
      final s = absDuration.inSeconds % 60;
      final timeStr =
          '${isNegative ? '-' : ''}${h > 0 ? '$h:' : ''}${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: Text(
          timeStr,
          style: TextStyle(
            color: isNegative ? Colors.red : (element.color ?? Colors.white),
            fontSize: (element.fontSize ?? 48) * (widget.stageHeight / 1080),
            fontWeight: FontWeight.bold,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      );
    } else {
      // Show duration setting
      final h = widget.timerDuration.inHours;
      final m = widget.timerDuration.inMinutes % 60;
      final s = widget.timerDuration.inSeconds % 60;
      final timeStr =
          '${h > 0 ? '$h:' : ''}${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: Text(
          timeStr,
          style: TextStyle(
            color: element.color ?? Colors.white,
            fontSize: (element.fontSize ?? 48) * (widget.stageHeight / 1080),
            fontWeight: FontWeight.bold,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      );
    }
  }

  Widget _buildSlidePreview(ProjectionSlide? slide, String label) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white24),
        color: Colors.black,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: Colors.white10,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: slide != null
                ? StyledSlide(
                    stageWidth: 1920,
                    stageHeight: 1080,
                    slide: slide,
                    // Strip down styling for stage view readability if desired
                    // For now, render full slide but maybe disable background video for performance?
                    backgroundActive: false, // Cleaner for stage view
                    foregroundMediaActive: true,
                    slideActive: true,
                    overlayActive: false,
                    isPlaying: false,
                  )
                : const Center(
                    child: Text(
                      'End of presentation',
                      style: TextStyle(color: Colors.white30),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(StageElement element) {
    // Placeholder for system messages
    return Container(
      alignment: Alignment.center,
      child: Text(
        element.text ?? '',
        style: TextStyle(
          color: element.color ?? Colors.yellow,
          fontSize: (element.fontSize ?? 32) * (widget.stageHeight / 1080),
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildCustomText(StageElement element) {
    return Container(
      alignment: Alignment.center,
      child: Text(
        element.text ?? 'Custom Text',
        style: TextStyle(
          color: element.color ?? Colors.white,
          fontSize: (element.fontSize ?? 24) * (widget.stageHeight / 1080),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
