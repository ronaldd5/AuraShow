part of dashboard_screen;

// Shared numeric clamps for layout and rendering helpers.
double _safeClamp(double value, double min, double max) {
  if (!min.isFinite || !max.isFinite) {
    if (min.isFinite && value < min) return min;
    if (max.isFinite && value > max) return max;
    return value;
  }
  if (max < min) return min;
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

int _safeIntClamp(int value, int min, int max) {
  if (max < min) return min;
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

Alignment _textAlignToAlignment(TextAlign align, _VerticalAlign vertical) {
  double x;
  switch (align) {
    case TextAlign.left:
      x = -1;
      break;
    case TextAlign.right:
      x = 1;
      break;
    case TextAlign.center:
    case TextAlign.justify:
    case TextAlign.start:
    case TextAlign.end:
      x = 0;
      break;
  }

  double y;
  switch (vertical) {
    case _VerticalAlign.top:
      y = -1;
      break;
    case _VerticalAlign.bottom:
      y = 1;
      break;
    case _VerticalAlign.middle:
      y = 0;
      break;
  }

  return Alignment(x, y);
}

Rect _clampRectWithOverflow(Rect rect) {
  const double minBoxFraction = _DashboardScreenState._minBoxFraction;
  const double overflowAllowance = _DashboardScreenState._overflowAllowance;
  final width = _safeClamp(rect.width, minBoxFraction, 2.0);
  final height = _safeClamp(rect.height, minBoxFraction, 2.0);
  final maxLeft = 1 + overflowAllowance - width;
  final maxTop = 1 + overflowAllowance - height;
  final left = _safeClamp(rect.left, -overflowAllowance, maxLeft);
  final top = _safeClamp(rect.top, -overflowAllowance, maxTop);
  return Rect.fromLTWH(left, top, width, height);
}

double _autoSizedFont(_SlideContent slide, double base, Rect box) {
  if (slide.autoSize != true) return base;
  final lineCount = slide.body.split('\n').length;
  final charCount = slide.body.length.clamp(1, 4000);
  final areaFactor = (box.width * box.height).clamp(0.2, 1.0);
  double scale = 1.0;
  if (lineCount > 4) scale -= 0.08;
  if (lineCount > 8) scale -= 0.12;
  scale -= (charCount / 1200) * 0.12;
  scale *= areaFactor;
  return base * _safeClamp(scale, 0.35, 1.0);
}

Rect _snapRect(Rect rect, double totalW, double totalH, {double tolerancePx = _DashboardScreenState._snapTolerancePx}) {
  double snapEdge(double valuePx, List<double> anchorsPx) {
    for (final anchor in anchorsPx) {
      if ((valuePx - anchor).abs() <= tolerancePx) return anchor;
    }
    return valuePx;
  }

  final leftPx = rect.left * totalW;
  final rightPx = (rect.left + rect.width) * totalW;
  final topPx = rect.top * totalH;
  final bottomPx = (rect.top + rect.height) * totalH;

  final hAnchors = <double>[0, totalW * 0.25, totalW * 0.5, totalW * 0.75, totalW];
  final vAnchors = <double>[0, totalH * 0.25, totalH * 0.5, totalH * 0.75, totalH];

  final snappedLeftPx = snapEdge(leftPx, hAnchors);
  final snappedRightPx = snapEdge(rightPx, hAnchors);
  final snappedTopPx = snapEdge(topPx, vAnchors);
  final snappedBottomPx = snapEdge(bottomPx, vAnchors);

  final newLeft = snappedLeftPx / totalW;
  final newTop = snappedTopPx / totalH;
  final newWidth = (snappedRightPx - snappedLeftPx) / totalW;
  final newHeight = (snappedBottomPx - snappedTopPx) / totalH;
  return Rect.fromLTWH(newLeft, newTop, newWidth, newHeight);
}

Rect _resizeRectFromHandle(
  Rect startRect,
  Offset deltaLocalPx,
  _HandlePosition pos,
  double totalW,
  double totalH, {
  double? aspectRatio,
}) {
  final leftPx = startRect.left * totalW;
  final rightPx = (startRect.left + startRect.width) * totalW;
  final topPx = startRect.top * totalH;
  final bottomPx = (startRect.top + startRect.height) * totalH;

  double newLeft = leftPx;
  double newRight = rightPx;
  double newTop = topPx;
  double newBottom = bottomPx;

  final dx = deltaLocalPx.dx;
  final dy = deltaLocalPx.dy;

  final moveLeft = pos == _HandlePosition.topLeft || pos == _HandlePosition.midLeft || pos == _HandlePosition.bottomLeft;
  final moveRight = pos == _HandlePosition.topRight || pos == _HandlePosition.midRight || pos == _HandlePosition.bottomRight;
  final moveTop = pos == _HandlePosition.topLeft || pos == _HandlePosition.topRight || pos == _HandlePosition.midTop;
  final moveBottom = pos == _HandlePosition.bottomLeft || pos == _HandlePosition.bottomRight || pos == _HandlePosition.midBottom;

  if (moveLeft) newLeft = leftPx + dx;
  if (moveRight) newRight = rightPx + dx;
  if (moveTop) newTop = topPx + dy;
  if (moveBottom) newBottom = bottomPx + dy;

  final newWidthPx = (newRight - newLeft).clamp(_DashboardScreenState._minBoxFraction * totalW, 2 * totalW);
  final newHeightPx = (newBottom - newTop).clamp(_DashboardScreenState._minBoxFraction * totalH, 2 * totalH);

  double targetWidth = newWidthPx;
  double targetHeight = newHeightPx;

  if (aspectRatio != null && aspectRatio > 0) {
    final bool horizontalMove = moveLeft || moveRight;
    final bool verticalMove = moveTop || moveBottom;

    if (horizontalMove && !verticalMove) {
      targetHeight = targetWidth / aspectRatio;
    } else if (verticalMove && !horizontalMove) {
      targetWidth = targetHeight * aspectRatio;
    } else {
      if (dx.abs() >= dy.abs()) {
        targetHeight = targetWidth / aspectRatio;
      } else {
        targetWidth = targetHeight * aspectRatio;
      }
    }

    targetWidth = targetWidth.clamp(_DashboardScreenState._minBoxFraction * totalW, 2 * totalW);
    targetHeight = targetHeight.clamp(_DashboardScreenState._minBoxFraction * totalH, 2 * totalH);
  }

  final anchorLeft = !moveLeft;
  final anchorRight = !moveRight;
  final anchorTop = !moveTop;
  final anchorBottom = !moveBottom;

  if (anchorLeft && !anchorRight) {
    newRight = newLeft + targetWidth;
  } else if (anchorRight && !anchorLeft) {
    newLeft = newRight - targetWidth;
  } else {
    newRight = newLeft + targetWidth;
  }

  if (anchorTop && !anchorBottom) {
    newBottom = newTop + targetHeight;
  } else if (anchorBottom && !anchorTop) {
    newTop = newBottom - targetHeight;
  } else {
    newBottom = newTop + targetHeight;
  }

  final leftNorm = newLeft / totalW;
  final topNorm = newTop / totalH;
  final widthNorm = (newRight - newLeft) / totalW;
  final heightNorm = (newBottom - newTop) / totalH;
  return Rect.fromLTWH(leftNorm, topNorm, widthNorm, heightNorm);
}

String _applyTransform(String text, _TextTransform transform) {
  switch (transform) {
    case _TextTransform.uppercase:
      return text.toUpperCase();
    case _TextTransform.lowercase:
      return text.toLowerCase();
    case _TextTransform.title:
      return text
          .split(RegExp(r'\s+'))
          .map((word) => word.isEmpty ? word : word[0].toUpperCase() + word.substring(1).toLowerCase())
          .join(' ');
    case _TextTransform.none:
      return text;
  }
}

List<Shadow> _textShadows(_SlideContent slide) {
  final shadows = <Shadow>[];
  final blur = (slide.shadowBlur ?? 0).clamp(0, 30).toDouble();
  final dx = (slide.shadowOffsetX ?? 0).clamp(-20, 20).toDouble();
  final dy = (slide.shadowOffsetY ?? 0).clamp(-20, 20).toDouble();
  final shadowColor = (slide.shadowColor ?? Colors.black).withOpacity(blur > 0 ? 0.7 : 0.0);
  if (blur > 0) {
    shadows.add(Shadow(color: shadowColor, blurRadius: blur, offset: Offset(dx, dy)));
  }

  final outlineWidth = (slide.outlineWidth ?? 0).clamp(0, 8).toDouble();
  final outlineColor = slide.outlineColor ?? Colors.black;
  if (outlineWidth > 0) {
    final step = outlineWidth;
    final outline = [
      Offset(step, 0),
      Offset(-step, 0),
      Offset(0, step),
      Offset(0, -step),
      Offset(step, step),
      Offset(step, -step),
      Offset(-step, step),
      Offset(-step, -step),
    ];
    for (final o in outline) {
      shadows.add(Shadow(color: outlineColor.withOpacity(0.9), offset: o, blurRadius: 0));
    }
  }

  return shadows;
}
