part of dashboard_screen;

/// Extension with slide editor widget methods.
extension SlideEditorWidgets on DashboardScreenState {
  /// Rotate a point around a center by [angleDegrees].
  Offset _rotatePoint(Offset center, Offset point, double angleDegrees) {
    if (angleDegrees == 0) return point;
    final double angle = angleDegrees * (3.1415926535 / 180);
    final double cosA = math.cos(angle);
    final double sinA = math.sin(angle);
    final double dx = point.dx - center.dx;
    final double dy = point.dy - center.dy;
    return Offset(
      center.dx + dx * cosA - dy * sinA,
      center.dy + dx * sinA + dy * cosA,
    );
  }

  /// Build resize handles for a draggable/resizable element.
  List<Widget> buildResizeHandles({
    required Rect rect,
    required double rotation,
    required Offset Function(Offset rawDelta) scaleDelta,
    required void Function(HandlePosition pos, Offset deltaPx) onResize,
    required void Function(HandlePosition pos) onStart,
    required VoidCallback onEnd,
  }) {
    Offset centerFor(HandlePosition pos) {
      final left = rect.left;
      final top = rect.top;
      final right = rect.left + rect.width;
      final bottom = rect.top + rect.height;
      final midX = rect.left + rect.width / 2;
      final midY = rect.top + rect.height / 2;

      Offset rawPos;
      switch (pos) {
        case HandlePosition.topLeft:
          rawPos = Offset(left, top);
          break;
        case HandlePosition.midTop:
          rawPos = Offset(midX, top);
          break;
        case HandlePosition.topRight:
          rawPos = Offset(right, top);
          break;
        case HandlePosition.midLeft:
          rawPos = Offset(left, midY);
          break;
        case HandlePosition.midRight:
          rawPos = Offset(right, midY);
          break;
        case HandlePosition.bottomLeft:
          rawPos = Offset(left, bottom);
          break;
        case HandlePosition.midBottom:
          rawPos = Offset(midX, bottom);
          break;
        case HandlePosition.bottomRight:
          rawPos = Offset(right, bottom);
          break;
      }
      return _rotatePoint(rect.center, rawPos, rotation);
    }

    Widget handleFor(HandlePosition pos) {
      final center = centerFor(pos);
      // visualPad logic might need detailed rotation too if valid,
      // but for now simple offsets are okay or just remove visualPad for precision.
      // Let's keep it simple and just center the handle on the point.

      return Positioned(
        left: center.dx - DashboardScreenState._resizeHandleSize / 2,
        top: center.dy - DashboardScreenState._resizeHandleSize / 2,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (_) {
            onStart(pos);
          },
          onPanUpdate: (details) {
            // We need to rotate the delta back to axis-aligned space for the resize logic
            // which likely expects axis-aligned deltas.
            final delta = scaleDelta(details.delta);
            final rad =
                -rotation * (3.1415926535 / 180); // Negative to rotate back
            final cosA = math.cos(rad);
            final sinA = math.sin(rad);
            final rotatedDelta = Offset(
              delta.dx * cosA - delta.dy * sinA,
              delta.dx * sinA + delta.dy * cosA,
            );

            // Pass incremental delta
            onResize(pos, rotatedDelta * DashboardScreenState._resizeDampening);
          },
          onPanEnd: (_) {
            onEnd();
          },
          onPanCancel: () {
            onEnd();
          },
          child: MouseRegion(
            cursor: cursorForHandle(pos, rotation),
            child: Transform.rotate(
              angle: rotation * (3.1415926535 / 180),
              child: Container(
                width: DashboardScreenState._resizeHandleSize,
                height: DashboardScreenState._resizeHandleSize,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: Colors.transparent),
                child: Container(
                  width: DashboardScreenState._resizeHandleSize * 0.6,
                  height: DashboardScreenState._resizeHandleSize * 0.6,
                  decoration: BoxDecoration(
                    color: accentPink,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(color: Colors.black54, blurRadius: 6),
                    ],
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return HandlePosition.values.map(handleFor).toList();
  }

  /// Get the appropriate cursor for a resize handle position.
  SystemMouseCursor cursorForHandle(HandlePosition pos, double rotation) {
    // Rotation aware cursors would be nice, but SystemMouseCursors are limited.
    // For now we just return standard cursors. A more complex implementation would
    // pick the cursor based on the visual angle.
    switch (pos) {
      case HandlePosition.topLeft:
      case HandlePosition.bottomRight:
        return SystemMouseCursors.resizeUpLeftDownRight;
      case HandlePosition.topRight:
      case HandlePosition.bottomLeft:
        return SystemMouseCursors.resizeUpRightDownLeft;
      case HandlePosition.midLeft:
      case HandlePosition.midRight:
        return SystemMouseCursors.resizeLeftRight;
      case HandlePosition.midTop:
      case HandlePosition.midBottom:
        return SystemMouseCursors.resizeUpDown;
    }
  }

  Widget buildRadiusHandle({
    required Rect rect,
    required double radius,
    required double rotation,
    required Offset Function(Offset rawDelta) scaleDelta,
    required ValueChanged<double> onRadiusChanged,
  }) {
    // Handle follows the radius along the top edge
    final double handleSize = 16.0;

    // Calculate position in unrotated space relative to top-left
    // Originally: left = rect.left + radius + 30, top = rect.top + 8
    // Now we need the specific point on the top edge
    final localX = radius + 30.0;
    final localY = 8.0;

    // The point relative to rect.left, rect.top would be (localX, localY)
    // IF localY was 0 (on line). But we added padding.
    // Let's stick to the visual placement.
    final rawPos = Offset(rect.left + localX, rect.top + localY);

    final center = _rotatePoint(rect.center, rawPos, rotation);

    return Positioned(
      left: center.dx,
      top: center.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          final delta = scaleDelta(details.delta);
          // We need projected movement along the top edge vector
          final rad = rotation * (3.1415926535 / 180);
          final cosA = math.cos(rad);
          final sinA = math.sin(rad);
          // Dot product of delta with the unit vector of the top edge (which is rotated 0 deg vector)
          // Top edge unit vector is (cosA, sinA)
          final projected = delta.dx * cosA + delta.dy * sinA;

          final newR = (radius + projected).clamp(0.0, 100.0);
          onRadiusChanged(newR);
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Transform.rotate(
            angle: rotation * (3.1415926535 / 180),
            child: Container(
              width: handleSize,
              height: handleSize,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: accentPink, width: 3),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: accentPink,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildRotateHandle({
    required Rect rect,
    required double rotation,
    required Offset Function(Offset rawDelta) scaleDelta,
    required ValueChanged<double> onRotationChanged,
    Alignment alignment = Alignment.topCenter,
  }) {
    final double handleSize = 16.0;
    final double distance = 40.0; // Distance from anchor point

    // Determine anchor point on the rect based on alignment
    Offset anchor;
    double angleOffset; // Angle of the handle stick relative to upright

    if (alignment == Alignment.topLeft) {
      anchor = rect.topLeft;
      angleOffset = -45;
    } else if (alignment == Alignment.topRight) {
      anchor = rect.topRight;
      angleOffset = 45;
    } else if (alignment == Alignment.bottomLeft) {
      anchor = rect.bottomLeft;
      angleOffset = -135;
    } else if (alignment == Alignment.bottomRight) {
      anchor = rect.bottomRight;
      angleOffset = 135;
    } else {
      // Default / TopCenter
      anchor = Offset(rect.left + rect.width / 2, rect.top);
      angleOffset = 0;
    }

    // Position in non-rotated space relative to rect center
    // We want to go 'distance' away from the anchor in the direction of 'angleOffset'
    // But verify: 0 degrees is UP?
    // In Flutter coords:
    // 0 deg usually Right. -90 is Up.
    // Let's use standard trig 0=Right.
    // TopCenter is "Up" -> -90 deg.
    // TopLeft is "Up-Left" -> -135 deg.
    // TopRight is "Up-Right" -> -45 deg.
    // BottomLeft is "Down-Left" -> 135 deg.
    // BottomRight is "Down-Right" -> 45 deg.

    // Let's re-map angleOffset to standard trig (0=Right, CW or CCW?)
    // Actually, let's just use manual offsets for simplicity and robustness.
    Offset rawPos;
    if (alignment == Alignment.topCenter) {
      rawPos = Offset(rect.center.dx, rect.top - distance);
    } else if (alignment == Alignment.topLeft) {
      rawPos = rect.topLeft - const Offset(20, 20); // Diagonal out
    } else if (alignment == Alignment.topRight) {
      rawPos = rect.topRight + const Offset(20, -20);
    } else if (alignment == Alignment.bottomLeft) {
      rawPos = rect.bottomLeft + const Offset(-20, 20);
    } else if (alignment == Alignment.bottomRight) {
      rawPos = rect.bottomRight + const Offset(20, 20);
    } else {
      rawPos = Offset(rect.center.dx, rect.top - distance);
    }

    final center = _rotatePoint(rect.center, rawPos, rotation);

    return Positioned(
      left: center.dx - handleSize / 2,
      top: center.dy - handleSize / 2,
      child: GestureDetector(
        onPanUpdate: (details) {
          final delta = scaleDelta(details.delta);
          // Simple horizontal drag logic for now
          final newRot = (rotation + delta.dx).remainder(360);
          onRotationChanged(newRot);
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Transform.rotate(
            angle: (rotation + angleOffset) * (3.1415926535 / 180),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: CustomPaint(
                    size: const Size(14, 14),
                    painter: _RotateHandlePainter(color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RotateHandlePainter extends CustomPainter {
  final Color color;

  _RotateHandlePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final double radius = size.width / 2;
    final Offset center = Offset(size.width / 2, size.height / 2);
    // Draw arc for double-arrow
    // Top-centered arc, e.g. -45 to -135?
    // Let's draw -135 to -45 (top quadrant)
    final Rect rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, -math.pi * 3 / 4, math.pi / 2, false, paint);

    // Arrow heads
    // Left end (-135 deg)
    _drawArrowHead(canvas, center, radius, -math.pi * 3 / 4, true, paint);
    // Right end (-45 deg)
    _drawArrowHead(canvas, center, radius, -math.pi / 4, false, paint);
  }

  void _drawArrowHead(
    Canvas canvas,
    Offset center,
    double radius,
    double angle,
    bool start,
    Paint paint,
  ) {
    final double arrowSize = 3.5;
    // Tangent: angle + pi/2
    double tangent = angle + (start ? -math.pi / 2 : math.pi / 2);
    // If start, we want to point "backwards" relative to sweep?
    // Arc is CW from -135 to -45.
    // Start (-135): tangent points towards -45 (CW).
    // We want arrow pointing CCW (away). So reversed.
    if (start) {
      tangent += math.pi;
    }

    final double x = center.dx + radius * math.cos(angle);
    final double y = center.dy + radius * math.sin(angle);

    final Path path = Path();
    path.moveTo(
      x + arrowSize * math.cos(tangent - math.pi / 6),
      y + arrowSize * math.sin(tangent - math.pi / 6),
    );
    path.lineTo(x, y);
    path.lineTo(
      x + arrowSize * math.cos(tangent + math.pi / 6),
      y + arrowSize * math.sin(tangent + math.pi / 6),
    );

    canvas.drawPath(path, paint..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant _RotateHandlePainter oldDelegate) => false;
}
