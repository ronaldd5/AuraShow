import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/slide_model.dart';

class ClockLayerWidget extends StatefulWidget {
  final SlideLayer layer;
  final bool force24h;
  final double scale;

  const ClockLayerWidget({
    Key? key,
    required this.layer,
    this.force24h = false,
    this.scale = 1.0,
  }) : super(key: key);

  @override
  State<ClockLayerWidget> createState() => _ClockLayerWidgetState();
}

class _ClockLayerWidgetState extends State<ClockLayerWidget> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  void _syncTimer() {
    _now = DateTime.now();
    final ms = _now.millisecond;
    final delay = Duration(milliseconds: 1000 - ms);

    _timer = Timer(delay, () {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
        // Start periodic timer aligned to the second
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) {
            setState(() {
              _now = DateTime.now();
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.layer.clockType == 'analog') {
      return _buildAnalog();
    }
    return _buildDigital();
  }

  Widget _buildDigital() {
    final showSeconds = widget.layer.clockShowSeconds ?? true;
    final use24h = widget.layer.clock24Hour ?? widget.force24h;
    final padding = (widget.layer.boxPadding ?? 0.0) * widget.scale;

    // Base font size for the unscaled text inside FittedBox.
    // This value should be high enough to ensure good quality when scaled up,
    // but FittedBox will scale it down to fit the container.
    const double kBaseFontSize = 250.0;

    String pattern = use24h ? 'HH:mm' : 'h:mm';
    if (showSeconds) {
      pattern += ':ss';
    }
    if (!use24h) {
      pattern += ' a';
    }

    final timeString = DateFormat(pattern).format(_now);

    return Container(
      padding: EdgeInsets.all(padding),
      alignment: _mapAlign(widget.layer.align),
      child: FittedBox(
        fit: BoxFit.contain,
        alignment: _mapAlign(widget.layer.align),
        child: Text(
          timeString,
          style: TextStyle(
            fontFamily: widget.layer.fontFamily,
            fontSize: kBaseFontSize,
            color: widget.layer.textColor ?? Colors.white,
            fontWeight: (widget.layer.isBold == true)
                ? FontWeight.bold
                : FontWeight.normal,
            fontStyle: (widget.layer.isItalic == true)
                ? FontStyle.italic
                : FontStyle.normal,
            decoration: (widget.layer.isUnderline == true)
                ? TextDecoration.underline
                : TextDecoration.none,
            shadows: const [
              Shadow(
                offset: Offset(4, 4),
                blurRadius: 8,
                color: Colors.black45,
              ),
            ],
          ),
          textAlign: widget.layer.align ?? TextAlign.center,
        ),
      ),
    );
  }

  Alignment _mapAlign(TextAlign? align) {
    switch (align) {
      case TextAlign.left:
        return Alignment.centerLeft;
      case TextAlign.right:
        return Alignment.centerRight;
      case TextAlign.justify:
        return Alignment.center; // fallback
      case TextAlign.start:
        return Alignment.centerLeft;
      case TextAlign.end:
        return Alignment.centerRight;
      case TextAlign.center:
      default:
        return Alignment.center;
    }
  }

  Widget _buildAnalog() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: AnalogClockPainter(
            time: _now,
            showSeconds: widget.layer.clockShowSeconds ?? true,
            primaryColor: widget.layer.textColor ?? Colors.white,
            faceColor: widget.layer.boxColor ?? Colors.black26,
            scale: widget.scale,
          ),
        );
      },
    );
  }
}

class AnalogClockPainter extends CustomPainter {
  final DateTime time;
  final bool showSeconds;
  final Color primaryColor;
  final Color faceColor;
  final double scale;

  AnalogClockPainter({
    required this.time,
    required this.showSeconds,
    required this.primaryColor,
    required this.faceColor,
    this.scale = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    // Draw Face
    final facePaint = Paint()
      ..color = faceColor
      ..style = PaintingStyle.fill;
    if (faceColor != Colors.transparent) {
      canvas.drawCircle(center, radius, facePaint);
    }

    // Rim/Marks
    final borderPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * scale;
    canvas.drawCircle(center, radius, borderPaint);

    // Hour Marks
    for (int i = 0; i < 12; i++) {
      final angle = i * 30.0;
      _drawMark(canvas, center, radius, angle, primaryColor);
    }

    // Hands
    final hAngle = (time.hour % 12 + time.minute / 60) * 30;
    _drawHand(canvas, center, radius * 0.5, hAngle, 4 * scale, primaryColor);

    final mAngle = (time.minute + time.second / 60) * 6;
    _drawHand(canvas, center, radius * 0.75, mAngle, 2 * scale, primaryColor);

    if (showSeconds) {
      final sAngle = time.second * 6.0;
      _drawHand(
        canvas,
        center,
        radius * 0.85,
        sAngle,
        1 * scale,
        Colors.redAccent,
      );
    }

    canvas.drawCircle(center, 4 * scale, Paint()..color = primaryColor);
  }

  void _drawMark(
    Canvas canvas,
    Offset center,
    double radius,
    double angleDeg,
    Color color,
  ) {
    final angleRad = (angleDeg - 90) * math.pi / 180;
    final outer =
        center +
        Offset(math.cos(angleRad) * radius, math.sin(angleRad) * radius);
    final inner =
        center +
        Offset(
          math.cos(angleRad) * (radius - 8 * scale),
          math.sin(angleRad) * (radius - 8 * scale),
        );
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2 * scale
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(inner, outer, paint);
  }

  void _drawHand(
    Canvas canvas,
    Offset center,
    double length,
    double angleDeg,
    double width,
    Color color,
  ) {
    final angleRad = (angleDeg - 90) * math.pi / 180;
    final end =
        center +
        Offset(math.cos(angleRad) * length, math.sin(angleRad) * length);
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, end, paint);
  }

  @override
  bool shouldRepaint(covariant AnalogClockPainter oldDelegate) =>
      oldDelegate.time.second != time.second ||
      oldDelegate.showSeconds != showSeconds ||
      oldDelegate.primaryColor != primaryColor;
}
