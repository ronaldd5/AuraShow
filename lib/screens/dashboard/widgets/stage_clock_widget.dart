import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/palette.dart';
import '../models/stage_models.dart';

class StageClockWidget extends StatefulWidget {
  final StageElement element;
  final double scale; // Scaling factor relative to 1080p height

  const StageClockWidget({super.key, required this.element, this.scale = 1.0});

  @override
  State<StageClockWidget> createState() => _StageClockWidgetState();
}

class _StageClockWidgetState extends State<StageClockWidget> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
  }

  void _updateTime() {
    if (mounted) {
      setState(() => _now = DateTime.now());
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.element.data['isAnalog'] == true) {
      return _buildAnalogClock();
    }
    return _buildDigitalClock();
  }

  Widget _buildDigitalClock() {
    final use24Hour = widget.element.data['use24Hour'] == true;
    final showSeconds = widget.element.data['showSeconds'] ?? true;
    final showAmPm = widget.element.data['showAmPm'] ?? (!use24Hour);
    final showDate = widget.element.data['showDate'] ?? false;

    // Format time
    String pattern = use24Hour ? 'HH:mm' : 'h:mm';
    if (showSeconds) {
      pattern += ':ss';
    }

    final timeStr = DateFormat(pattern).format(_now);
    String amPmStr = '';
    if (showAmPm && !use24Hour) {
      amPmStr = DateFormat(' a').format(_now);
    }

    String? dateStr;
    if (showDate) {
      dateStr = DateFormat('EEE, MMM d').format(_now);
    }

    final fontSize = (widget.element.fontSize ?? 48) * widget.scale;
    final color = widget.element.color ?? Colors.white;

    return Container(
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                timeStr,
                style: TextStyle(
                  color: color,
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  height: 1.0,
                ),
              ),
              if (amPmStr.isNotEmpty)
                Text(
                  amPmStr,
                  style: TextStyle(
                    color: color.withOpacity(0.8),
                    fontSize: fontSize * 0.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          if (dateStr != null)
            Text(
              dateStr,
              style: TextStyle(
                color: color.withOpacity(0.7),
                fontSize: fontSize * 0.35,
                fontWeight: FontWeight.normal,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAnalogClock() {
    final color = widget.element.color ?? Colors.white;
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: CustomPaint(
        painter: _AnalogClockPainter(
          time: _now,
          color: color,
          showSeconds: widget.element.data['showSeconds'] ?? true,
        ),
        child: Container(),
      ),
    );
  }
}

class _AnalogClockPainter extends CustomPainter {
  final DateTime time;
  final Color color;
  final bool showSeconds;

  _AnalogClockPainter({
    required this.time,
    required this.color,
    this.showSeconds = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Draw Face
    canvas.drawCircle(center, radius, paint);

    // Draw Ticks
    for (int i = 0; i < 12; i++) {
      final angle = i * 30 * math.pi / 180;
      final tickLength = i % 3 == 0 ? 0.15 * radius : 0.05 * radius;
      final p1 = Offset(
        center.dx + (radius - tickLength) * math.cos(angle),
        center.dy + (radius - tickLength) * math.sin(angle),
      );
      final p2 = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      paint.strokeWidth = i % 3 == 0 ? 3.0 : 1.0;
      canvas.drawLine(p1, p2, paint);
    }

    // Hour Hand
    final hourAngle =
        (time.hour % 12 + time.minute / 60) * 30 * math.pi / 180 - math.pi / 2;
    final hourHandLen = radius * 0.5;
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;
    canvas.drawLine(
      center,
      Offset(
        center.dx + hourHandLen * math.cos(hourAngle),
        center.dy + hourHandLen * math.sin(hourAngle),
      ),
      paint,
    );

    // Minute Hand
    final minAngle =
        (time.minute + time.second / 60) * 6 * math.pi / 180 - math.pi / 2;
    final minHandLen = radius * 0.7;
    paint.strokeWidth = 3.0;
    canvas.drawLine(
      center,
      Offset(
        center.dx + minHandLen * math.cos(minAngle),
        center.dy + minHandLen * math.sin(minAngle),
      ),
      paint,
    );

    // Second Hand
    if (showSeconds) {
      final secAngle = time.second * 6 * math.pi / 180 - math.pi / 2;
      final secHandLen = radius * 0.8;
      paint
        ..color = Colors.redAccent
        ..strokeWidth = 1.5;
      canvas.drawLine(
        center,
        Offset(
          center.dx + secHandLen * math.cos(secAngle),
          center.dy + secHandLen * math.sin(secAngle),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_AnalogClockPainter oldDelegate) {
    return oldDelegate.time.second != time.second || oldDelegate.color != color;
  }
}

class ClockSettingsDialog extends StatefulWidget {
  final Map<String, dynamic> currentData;

  const ClockSettingsDialog({super.key, required this.currentData});

  @override
  State<ClockSettingsDialog> createState() => _ClockSettingsDialogState();
}

class _ClockSettingsDialogState extends State<ClockSettingsDialog> {
  late Map<String, dynamic> _data;

  @override
  void initState() {
    super.initState();
    _data = Map.from(widget.currentData);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppPalette.surface,
      title: const Text('Clock Settings'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: const Text('Analog Clock'),
              value: _data['isAnalog'] == true,
              onChanged: (v) => setState(() => _data['isAnalog'] = v),
              activeTrackColor: AppPalette.primary,
            ),
            if (_data['isAnalog'] != true) ...[
              SwitchListTile(
                title: const Text('24 Hour Format'),
                value: _data['use24Hour'] == true,
                onChanged: (v) => setState(() => _data['use24Hour'] = v),
                activeTrackColor: AppPalette.primary,
              ),
              SwitchListTile(
                title: const Text('Show AM/PM'),
                subtitle: const Text('Only applies to 12h format'),
                value: _data['showAmPm'] ?? true,
                onChanged: (_data['use24Hour'] == true)
                    ? null
                    : (v) => setState(() => _data['showAmPm'] = v),
                activeTrackColor: AppPalette.primary,
              ),
              SwitchListTile(
                title: const Text('Show Date'),
                value: _data['showDate'] == true,
                onChanged: (v) => setState(() => _data['showDate'] = v),
                activeTrackColor: AppPalette.primary,
              ),
            ],
            SwitchListTile(
              title: const Text('Show Seconds'),
              value: _data['showSeconds'] ?? true,
              onChanged: (v) => setState(() => _data['showSeconds'] = v),
              activeTrackColor: AppPalette.primary,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_data),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
