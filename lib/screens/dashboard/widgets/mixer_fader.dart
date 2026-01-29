import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../dashboard_screen.dart'; // For AppPalette/accentBlue if needed, or I'll just use constants

class MixerFader extends StatefulWidget {
  final int channelNumber;
  final double value; // 0.0 to 1.0
  final bool isMuted;
  final ValueChanged<double> onChanged;
  final ValueChanged<bool> onMuteChanged;
  final String label;

  const MixerFader({
    super.key,
    required this.channelNumber,
    required this.value,
    required this.isMuted,
    required this.onChanged,
    required this.onMuteChanged,
    required this.label,
  });

  @override
  State<MixerFader> createState() => _MixerFaderState();
}

class _MixerFaderState extends State<MixerFader> {
  // Convert 0.0-1.0 linear to approximate dB
  String _toDb(double val) {
    if (val <= 0.0) return '-oo dB';
    // Interactive faders usually have a non-linear taper, but XAir protocol
    // often treats 0.75 as 0dB. Let's do a simple log approximation for display.
    // Real formula depends on the exact XAir curve.
    // Assuming 0.75 = 0dB.
    // val > 0.75 -> +dB
    // val < 0.75 -> -dB

    // Simple Log mapping for "look and feel"
    // 0.75 -> 0
    // 1.0 -> +10
    // 0.0 -> -oo

    double db;
    if (val >= 0.75) {
      db = (val - 0.75) * 40; // 0.25 range maps to 10db
    } else {
      // 0.001 to 0.75 map to -90 to 0
      db = 20 * math.log(val / 0.75) / math.ln10;
    }

    if (db < -90) return '-oo dB';
    return '${db.toStringAsFixed(1)} dB';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        // Digital Display
        Container(
          width: 50,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.black,
            border: Border.all(color: Colors.white24),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            _toDb(widget.value),
            style: const TextStyle(
              color: Colors.cyanAccent,
              fontSize: 10,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Buttons (Mute / Solo)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _faderButton(
              label: 'MUTE',
              isActive: widget.isMuted,
              activeColor: Colors.red,
              onTap: () => widget.onMuteChanged(!widget.isMuted),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _faderButton(
              label: 'SOLO',
              isActive: false, // Solo logic not yet implemented in service
              activeColor: Colors.yellow,
              onTap: () {}, // Future imp logic
            ),
          ],
        ),

        const SizedBox(height: 12),

        // The Fader Track
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                onVerticalDragUpdate: (details) {
                  // Calculate new value based on drag
                  // Top is 1.0, Bottom is 0.0
                  // Delta dy is positive downwards
                  final height = constraints.maxHeight;
                  final dy = details.primaryDelta ?? 0;
                  // Moving down (positive dy) reduces value
                  final deltaVal = -(dy / height);
                  final newVal = (widget.value + deltaVal).clamp(0.0, 1.0);
                  widget.onChanged(newVal);
                },
                onTapUp: (details) {
                  // Jump to position
                  final height = constraints.maxHeight;
                  // Local Y position from top
                  final dy = details.localPosition.dy;
                  // 0 at top = 1.0
                  // height at bottom = 0.0
                  final newVal = 1.0 - (dy / height).clamp(0.0, 1.0);
                  widget.onChanged(newVal);
                },
                child: Container(
                  width: 40,
                  color: Colors.transparent, // Hit test area
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Track Background (Slot)
                      Container(
                        width: 4,
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),

                      // Tick Marks (Visual Only)
                      // We can draw lines at 0dB (75%), -10, etc.
                      Positioned.fill(
                        child: CustomPaint(painter: _FaderTickPainter()),
                      ),

                      // Thumb (Knob)
                      Positioned(
                        bottom: (constraints.maxHeight - 30) * widget.value,
                        child: _FaderKnob(),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 8),

        // Label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            widget.label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
        ),
      ],
    );
  }

  Widget _faderButton({
    required String label,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 20,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? activeColor : const Color(0xFF333333),
          borderRadius: BorderRadius.circular(2),
          border: Border.all(
            color: isActive ? Colors.white54 : Colors.black,
            width: 1,
          ),
          boxShadow: isActive
              ? [BoxShadow(color: activeColor.withOpacity(0.5), blurRadius: 4)]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: isActive ? Colors.black : Colors.white70,
          ),
        ),
      ),
    );
  }
}

class _FaderKnob extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 45,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFEEEEEE),
            Color(0xFFAAAAAA),
            Color(0xFF888888),
            Color(0xFFAAAAAA),
            Color(0xFFEEEEEE),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Center(
        child: Container(width: 28, height: 1, color: Colors.black87),
      ),
    );
  }
}

class _FaderTickPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;

    // Draw ticks relative to standard db points
    // 0dB approx 0.75
    // +10dB at 1.0
    // -10, -20, -30...

    final dbPoints = [1.0, 0.75, 0.6, 0.45, 0.3, 0.15];

    for (var val in dbPoints) {
      final y = size.height - (size.height * val);
      canvas.drawLine(
        Offset(size.width / 2 - 8, y),
        Offset(size.width / 2 + 8, y),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
