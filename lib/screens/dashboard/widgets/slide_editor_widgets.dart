part of dashboard_screen;

/// Extension with slide editor widget methods.
extension SlideEditorWidgets on _DashboardScreenState {
  /// Build resize handles for a draggable/resizable element.
  List<Widget> buildResizeHandles({
    required Rect rect,
    required Offset Function(Offset rawDelta) scaleDelta,
    required void Function(_HandlePosition pos, Offset deltaPx) onResize,
    required void Function(_HandlePosition pos) onStart,
    required VoidCallback onEnd,
  }) {
    Offset centerFor(_HandlePosition pos) {
      final left = rect.left;
      final top = rect.top;
      final right = rect.left + rect.width;
      final bottom = rect.top + rect.height;
      final midX = rect.left + rect.width / 2;
      final midY = rect.top + rect.height / 2;

      switch (pos) {
        case _HandlePosition.topLeft:
          return Offset(left, top);
        case _HandlePosition.midTop:
          return Offset(midX, top);
        case _HandlePosition.topRight:
          return Offset(right, top);
        case _HandlePosition.midLeft:
          return Offset(left, midY);
        case _HandlePosition.midRight:
          return Offset(right, midY);
        case _HandlePosition.bottomLeft:
          return Offset(left, bottom);
        case _HandlePosition.midBottom:
          return Offset(midX, bottom);
        case _HandlePosition.bottomRight:
          return Offset(right, bottom);
      }
    }

    Widget handleFor(_HandlePosition pos) {
      Offset accumulated = Offset.zero;
      final center = centerFor(pos);
      const double visualPad = 3;
      final Offset visualOffset = () {
        switch (pos) {
          case _HandlePosition.topLeft:
            return const Offset(-visualPad, -visualPad);
          case _HandlePosition.midTop:
            return const Offset(0, -visualPad);
          case _HandlePosition.topRight:
            return const Offset(visualPad, -visualPad);
          case _HandlePosition.midLeft:
            return const Offset(-visualPad, 0);
          case _HandlePosition.midRight:
            return const Offset(visualPad, 0);
          case _HandlePosition.bottomLeft:
            return const Offset(-visualPad, visualPad);
          case _HandlePosition.midBottom:
            return const Offset(0, visualPad);
          case _HandlePosition.bottomRight:
            return const Offset(visualPad, visualPad);
        }
      }();

      return Positioned(
        left: center.dx - _DashboardScreenState._resizeHandleSize / 2 + visualOffset.dx,
        top: center.dy - _DashboardScreenState._resizeHandleSize / 2 + visualOffset.dy,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (_) {
            accumulated = Offset.zero;
            onStart(pos);
          },
          onPanUpdate: (details) {
            accumulated += scaleDelta(details.delta) * _DashboardScreenState._resizeDampening;
            onResize(pos, accumulated);
          },
          onPanEnd: (_) {
            accumulated = Offset.zero;
            onEnd();
          },
          onPanCancel: () {
            accumulated = Offset.zero;
            onEnd();
          },
          child: MouseRegion(
            cursor: cursorForHandle(pos),
            child: Container(
              width: _DashboardScreenState._resizeHandleSize,
              height: _DashboardScreenState._resizeHandleSize,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: Colors.transparent),
              child: Container(
                width: _DashboardScreenState._resizeHandleSize * 0.6,
                height: _DashboardScreenState._resizeHandleSize * 0.6,
                decoration: BoxDecoration(
                  color: accentPink,
                  shape: BoxShape.circle,
                  boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 6)],
                  border: Border.all(color: Colors.white, width: 1),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return _HandlePosition.values.map(handleFor).toList();
  }

  /// Get the appropriate cursor for a resize handle position.
  SystemMouseCursor cursorForHandle(_HandlePosition pos) {
    switch (pos) {
      case _HandlePosition.topLeft:
      case _HandlePosition.bottomRight:
        return SystemMouseCursors.resizeUpLeftDownRight;
      case _HandlePosition.topRight:
      case _HandlePosition.bottomLeft:
        return SystemMouseCursors.resizeUpRightDownLeft;
      case _HandlePosition.midLeft:
      case _HandlePosition.midRight:
        return SystemMouseCursors.resizeLeftRight;
      case _HandlePosition.midTop:
      case _HandlePosition.midBottom:
        return SystemMouseCursors.resizeUpDown;
    }
  }
}
