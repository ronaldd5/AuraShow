part of '../dashboard_screen.dart';

extension FilterExtensions on DashboardScreenState {
  Widget _applyFilters(Widget child, SlideContent slide) {
    final matrix = _colorMatrix(slide);
    final blurSigma = (slide.blur ?? 0).clamp(0, 40).toDouble();
    Widget filtered = ColorFiltered(
      colorFilter: ColorFilter.matrix(matrix),
      child: child,
    );
    if (blurSigma > 0) {
      filtered = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: filtered,
      );
    }
    return filtered;
  }

  List<double> _colorMatrix(SlideContent slide) {
    List<double> matrix = _identityMatrix();
    matrix = _matrixMultiply(
      matrix,
      _hueMatrix((slide.hueRotate ?? 0) * math.pi / 180),
    );
    matrix = _matrixMultiply(matrix, _saturationMatrix(slide.saturate ?? 1));
    matrix = _matrixMultiply(matrix, _contrastMatrix(slide.contrast ?? 1));
    matrix = _matrixMultiply(matrix, _brightnessMatrix(slide.brightness ?? 1));
    final invertAmount = (slide.invert ?? 0).clamp(0, 1).toDouble();
    if (invertAmount > 0) {
      matrix = _lerpMatrix(matrix, _invertMatrix(), invertAmount);
    }
    return matrix;
  }

  List<double> _identityMatrix() => [
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];

  List<double> _invertMatrix() => [
    -1,
    0,
    0,
    0,
    255,
    0,
    -1,
    0,
    0,
    255,
    0,
    0,
    -1,
    0,
    255,
    0,
    0,
    0,
    1,
    0,
  ];

  List<double> _saturationMatrix(double s) {
    const rw = 0.2126, gw = 0.7152, bw = 0.0722;
    final inv = 1 - s;
    final r = inv * rw;
    final g = inv * gw;
    final b = inv * bw;
    return [
      r + s,
      g,
      b,
      0,
      0,
      r,
      g + s,
      b,
      0,
      0,
      r,
      g,
      b + s,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  List<double> _hueMatrix(double radians) {
    final cosR = math.cos(radians);
    final sinR = math.sin(radians);
    const rw = 0.213, gw = 0.715, bw = 0.072;
    return [
      rw + cosR * (1 - rw) + sinR * (-rw),
      gw + cosR * (-gw) + sinR * (-gw),
      bw + cosR * (-bw) + sinR * (1 - bw),
      0,
      0,
      rw + cosR * (-rw) + sinR * 0.143,
      gw + cosR * (1 - gw) + sinR * 0.14,
      bw + cosR * (-bw) + sinR * (-0.283),
      0,
      0,
      rw + cosR * (-rw) + sinR * (-(1 - rw)),
      gw + cosR * (-gw) + sinR * gw,
      bw + cosR * (1 - bw) + sinR * bw,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  List<double> _contrastMatrix(double c) {
    final t = 128 * (1 - c);
    return [c, 0, 0, 0, t, 0, c, 0, 0, t, 0, 0, c, 0, t, 0, 0, 0, 1, 0];
  }

  List<double> _brightnessMatrix(double b) {
    final offset = 255 * (b - 1);
    return [
      1,
      0,
      0,
      0,
      offset,
      0,
      1,
      0,
      0,
      offset,
      0,
      0,
      1,
      0,
      offset,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  List<double> _lerpMatrix(List<double> a, List<double> b, double t) {
    final out = List<double>.filled(20, 0);
    for (int i = 0; i < 20; i++) {
      out[i] = a[i] + (b[i] - a[i]) * t;
    }
    return out;
  }

  List<double> _matrixMultiply(List<double> a, List<double> b) {
    final out = List<double>.filled(20, 0);
    for (int r = 0; r < 4; r++) {
      for (int c = 0; c < 5; c++) {
        double v = 0;
        for (int k = 0; k < 4; k++) {
          v += a[r * 5 + k] * b[k * 5 + c];
        }
        if (c == 4) {
          v += a[r * 5 + 4];
        }
        out[r * 5 + c] = v;
      }
    }
    return out;
  }
}
