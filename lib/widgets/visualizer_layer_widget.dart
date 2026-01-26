import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/slide_model.dart';
import '../platforms/desktop_capture.dart'; // <--- NEW: Uses the smart platform switcher
import '../platforms/interface/capture_platform_interface.dart'; // <--- NEW: For AudioCaptureMode

/// Audio analyzer that provides frequency data.
/// Supports preview mode (simulated), real audio capture, and app audio.
class AudioAnalyzer {
  static final AudioAnalyzer _instance = AudioAnalyzer._internal();
  factory AudioAnalyzer() => _instance;
  AudioAnalyzer._internal();

  final _random = math.Random();
  List<double> _frequencies = List.filled(128, 0.0);
  List<double> _smoothedFrequencies = List.filled(128, 0.0);
  Timer? _simulationTimer;
  StreamSubscription<AudioCaptureData>? _captureSubscription;
  final _controller = StreamController<List<double>>.broadcast();

  // Track if any real audio is playing
  bool _isAudioPlaying = false;

  // Track listeners for preview mode
  int _previewListenerCount = 0;

  // Track current capture mode
  bool _isCapturingRealAudio = false;
  String? _currentAudioSource;
  String? _currentDeviceId;

  Stream<List<double>> get frequencyStream => _controller.stream;
  List<double> get currentFrequencies => _smoothedFrequencies;
  bool get isAudioPlaying => _isAudioPlaying;

  /// Start audio capture from a specific source and device
  Future<void> startAudioCapture({
    required String audioSource,
    String? deviceId,
  }) async {
    // Stop any existing capture
    await stopAudioCapture();

    _currentAudioSource = audioSource;
    _currentDeviceId = deviceId;

    if (audioSource == 'system_audio') {
      // Start system audio loopback capture using DesktopCapture facade
      _isCapturingRealAudio = await DesktopCapture.instance
          .startCapture(mode: AudioCaptureMode.loopback, deviceId: deviceId);

      if (_isCapturingRealAudio) {
        _captureSubscription = DesktopCapture.instance.audioDataStream
            .listen((data) {
              _updateFromCapturedAudio(data.frequencies);
            });
      }
    } else if (audioSource == 'microphone') {
      // Start microphone capture using DesktopCapture facade
      _isCapturingRealAudio = await DesktopCapture.instance
          .startCapture(mode: AudioCaptureMode.microphone, deviceId: deviceId);

      if (_isCapturingRealAudio) {
        _captureSubscription = DesktopCapture.instance.audioDataStream
            .listen((data) {
              _updateFromCapturedAudio(data.frequencies);
            });
      }
    } else {
      // App audio - not implemented yet, use simulation
      _isCapturingRealAudio = false;
    }

    // If real capture failed, fall back to simulation
    if (!_isCapturingRealAudio && _previewListenerCount <= 0) {
      _startSimulation();
    }
  }

  /// Stop audio capture
  Future<void> stopAudioCapture() async {
    await _captureSubscription?.cancel();
    _captureSubscription = null;

    if (_isCapturingRealAudio) {
      await DesktopCapture.instance.stopCapture();
      _isCapturingRealAudio = false;
    }

    _currentAudioSource = null;
    _currentDeviceId = null;

    // Stop simulation if no preview listeners
    if (_previewListenerCount <= 0) {
      _stopSimulation();
      _resetFrequencies();
    }
  }

  /// Start preview mode simulation
  void startPreview() {
    _previewListenerCount++;
    if (!_isCapturingRealAudio) {
      _startSimulation();
    }
  }

  /// Stop preview mode simulation
  void stopPreview() {
    _previewListenerCount--;
    if (_previewListenerCount <= 0) {
      _previewListenerCount = 0;
      if (!_isAudioPlaying && !_isCapturingRealAudio) {
        _stopSimulation();
        _resetFrequencies();
      }
    }
  }

  /// Called when real audio starts playing (app audio)
  void setAudioPlaying(bool playing) {
    _isAudioPlaying = playing;
    if (playing && !_isCapturingRealAudio) {
      _startSimulation();
    } else if (!playing &&
        _previewListenerCount <= 0 &&
        !_isCapturingRealAudio) {
      _stopSimulation();
      _resetFrequencies();
    }
  }

  void _updateFromCapturedAudio(List<double> frequencies) {
    if (frequencies.length != _frequencies.length) {
      // Resample if needed
      _frequencies = _resampleFrequencies(frequencies, _frequencies.length);
    } else {
      _frequencies = frequencies;
    }

    // Smooth the frequencies for nicer animation
    for (int i = 0; i < _frequencies.length; i++) {
      _smoothedFrequencies[i] =
          _smoothedFrequencies[i] * 0.7 + _frequencies[i] * 0.3;
    }

    _controller.add(_smoothedFrequencies);
  }

  List<double> _resampleFrequencies(List<double> source, int targetLength) {
    final result = List<double>.filled(targetLength, 0.0);
    final ratio = source.length / targetLength;

    for (int i = 0; i < targetLength; i++) {
      final sourceIndex = (i * ratio).floor();
      if (sourceIndex < source.length) {
        result[i] = source[sourceIndex];
      }
    }

    return result;
  }

  void _startSimulation() {
    if (_simulationTimer != null) return;
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      _updateSimulatedFrequencies();
    });
  }

  void _stopSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
  }

  void _resetFrequencies() {
    // Smoothly fade out frequencies to 0
    for (int i = 0; i < _smoothedFrequencies.length; i++) {
      _smoothedFrequencies[i] = 0.0;
      _frequencies[i] = 0.0;
    }
    _controller.add(_smoothedFrequencies);
  }

  void _updateSimulatedFrequencies() {
    // Generate realistic-looking audio frequency data
    for (int i = 0; i < _frequencies.length; i++) {
      // Bass frequencies (lower indices) tend to be stronger
      double bassFactor = 1.0 - (i / _frequencies.length) * 0.6;

      // Add some randomness with smooth transitions
      double target = _random.nextDouble() * bassFactor;

      // Add beat-like pulses occasionally
      if (_random.nextDouble() < 0.05) {
        target = bassFactor * (0.7 + _random.nextDouble() * 0.3);
      }

      _frequencies[i] = target;
    }

    // Smooth the frequencies for nicer animation
    for (int i = 0; i < _frequencies.length; i++) {
      _smoothedFrequencies[i] =
          _smoothedFrequencies[i] * 0.7 + _frequencies[i] * 0.3;
    }

    _controller.add(_smoothedFrequencies);
  }

  void dispose() {
    _stopSimulation();
    stopAudioCapture();
    _controller.close();
  }
}

/// Main visualizer widget that supports multiple visualization types.
class VisualizerLayerWidget extends StatefulWidget {
  final SlideLayer layer;
  final double scale;

  const VisualizerLayerWidget({Key? key, required this.layer, this.scale = 1.0})
    : super(key: key);

  @override
  State<VisualizerLayerWidget> createState() => _VisualizerLayerWidgetState();
}

class _VisualizerLayerWidgetState extends State<VisualizerLayerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  StreamSubscription<List<double>>? _subscription;
  List<double> _frequencies = [];
  double _rotation = 0.0;
  bool _wasAnimating = false;
  String? _lastAudioSource;
  String? _lastDeviceId;

  bool get _shouldAnimate {
    // Animate if:
    // 1. Preview mode is on, OR
    // 2. Audio source is system_audio or microphone (with real capture), OR
    // 3. Real audio is playing in the app
    final audioSource = widget.layer.visualizerAudioSource ?? 'app_audio';
    final previewMode = widget.layer.visualizerPreviewMode ?? false;

    return previewMode ||
        audioSource == 'system_audio' ||
        audioSource == 'microphone' ||
        AudioAnalyzer().isAudioPlaying;
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _wasAnimating = _shouldAnimate;
    _lastAudioSource = widget.layer.visualizerAudioSource;
    _lastDeviceId = widget.layer.visualizerAudioDevice;

    _startAudioCapture();

    _subscription = AudioAnalyzer().frequencyStream.listen((data) {
      if (mounted) {
        setState(() {
          _frequencies = data;
          if (_shouldAnimate) {
            _rotation += (widget.layer.visualizerRotationSpeed ?? 0.5) * 0.02;
          }
        });
      }
    });
  }

  @override
  void didUpdateWidget(VisualizerLayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    final wasAnimating = _wasAnimating;
    final nowAnimating = _shouldAnimate;

    final audioSourceChanged =
        oldWidget.layer.visualizerAudioSource !=
        widget.layer.visualizerAudioSource;
    final deviceChanged =
        oldWidget.layer.visualizerAudioDevice !=
        widget.layer.visualizerAudioDevice;

    // Restart capture if audio source or device changed
    if (audioSourceChanged || deviceChanged) {
      _lastAudioSource = widget.layer.visualizerAudioSource;
      _lastDeviceId = widget.layer.visualizerAudioDevice;
      _startAudioCapture();
    } else if (wasAnimating != nowAnimating) {
      if (nowAnimating) {
        _startAudioCapture();
      } else {
        AudioAnalyzer().stopPreview();
        AudioAnalyzer().stopAudioCapture();
      }
    }

    _wasAnimating = nowAnimating;
  }

  void _startAudioCapture() {
    final audioSource = widget.layer.visualizerAudioSource ?? 'app_audio';
    final deviceId = widget.layer.visualizerAudioDevice;
    final previewMode = widget.layer.visualizerPreviewMode ?? false;

    if (previewMode) {
      // Just use preview mode
      AudioAnalyzer().startPreview();
    } else if (audioSource == 'system_audio' || audioSource == 'microphone') {
      // Start real audio capture
      AudioAnalyzer().startAudioCapture(
        audioSource: audioSource,
        deviceId: deviceId,
      );
    } else {
      // App audio - use preview for now
      AudioAnalyzer().startPreview();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _subscription?.cancel();
    if (_wasAnimating) {
      AudioAnalyzer().stopPreview();
      AudioAnalyzer().stopAudioCapture();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.layer.visualizerType ?? 'bars';
    final color1 = widget.layer.visualizerColor1 ?? Colors.cyan;
    final color2 = widget.layer.visualizerColor2 ?? Colors.purple;
    final barCount = widget.layer.visualizerBarCount ?? 32;
    final sensitivity = widget.layer.visualizerSensitivity ?? 1.0;
    final smoothing = widget.layer.visualizerSmoothing ?? 0.5;
    final mirror = widget.layer.visualizerMirror ?? false;
    final glow = widget.layer.visualizerGlow ?? true;
    final glowIntensity = widget.layer.visualizerGlowIntensity ?? 1.0;
    final colorMode = widget.layer.visualizerColorMode ?? 'gradient';
    final lineWidth = widget.layer.visualizerLineWidth ?? 4.0;
    final gap = widget.layer.visualizerGap ?? 2.0;
    final radius = widget.layer.visualizerRadius ?? 0.3;
    final shape = widget.layer.visualizerShape ?? 'rounded';
    final filled = widget.layer.visualizerFilled ?? true;
    final minHeight = widget.layer.visualizerMinHeight ?? 0.02;
    final frequencyRange = widget.layer.visualizerFrequencyRange ?? 'full';

    // If not animating, show idle state (just minimum bars)
    final displayFrequencies = _shouldAnimate
        ? _frequencies
        : List.filled(barCount, 0.0);

    return ClipRect(
      child: CustomPaint(
        painter: VisualizerPainter(
          frequencies: displayFrequencies,
          type: type,
          color1: color1,
          color2: color2,
          barCount: barCount,
          sensitivity: sensitivity,
          smoothing: smoothing,
          mirror: mirror,
          glow: glow,
          glowIntensity: glowIntensity,
          colorMode: colorMode,
          lineWidth: lineWidth * widget.scale,
          gap: gap * widget.scale,
          radius: radius,
          rotation: _rotation,
          shape: shape,
          filled: filled,
          minHeight: minHeight,
          frequencyRange: frequencyRange,
          scale: widget.scale,
          isActive: _shouldAnimate,
        ),
        size: Size.infinite,
      ),
    );
  }
}

/// Painter for rendering the different visualizer types.
class VisualizerPainter extends CustomPainter {
  final List<double> frequencies;
  final String type;
  final Color color1;
  final Color color2;
  final int barCount;
  final double sensitivity;
  final double smoothing;
  final bool mirror;
  final bool glow;
  final double glowIntensity;
  final String colorMode;
  final double lineWidth;
  final double gap;
  final double radius;
  final double rotation;
  final String shape;
  final bool filled;
  final double minHeight;
  final String frequencyRange;
  final double scale;
  final bool isActive;

  VisualizerPainter({
    required this.frequencies,
    required this.type,
    required this.color1,
    required this.color2,
    required this.barCount,
    required this.sensitivity,
    required this.smoothing,
    required this.mirror,
    required this.glow,
    required this.glowIntensity,
    required this.colorMode,
    required this.lineWidth,
    required this.gap,
    required this.radius,
    required this.rotation,
    required this.shape,
    required this.filled,
    required this.minHeight,
    required this.frequencyRange,
    required this.scale,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (frequencies.isEmpty) return;

    final paint = Paint()
      ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = lineWidth
      ..strokeCap = StrokeCap.round;

    final double effectiveGlow = isActive ? glowIntensity : 0.2;

    switch (type) {
      case 'bars':
        _drawBars(canvas, size, paint, effectiveGlow);
        break;
      case 'waveform':
        _drawWaveform(canvas, size, paint, effectiveGlow);
        break;
      case 'circular':
        _drawCircular(canvas, size, paint, effectiveGlow);
        break;
      case 'particles':
        _drawParticles(canvas, size, paint, effectiveGlow);
        break;
      case 'spectrum':
        _drawSpectrum(canvas, size, paint, effectiveGlow);
        break;
    }
  }

  void _drawBars(Canvas canvas, Size size, Paint paint, double glowIntensity) {
    final availableFrequencies = _getFilteredFrequencies();
    final count = barCount;
    final totalGap = (count - 1) * gap;
    final barWidth = (size.width - totalGap) / count;

    for (int i = 0; i < count; i++) {
      final freqIdx = (i / count * availableFrequencies.length).floor();
      final magnitude = availableFrequencies[freqIdx] * sensitivity;
      final height = math.max(minHeight * size.height, magnitude * size.height);

      final x = i * (barWidth + gap);
      final y = size.height - height;

      _applyStyle(
        paint,
        i / count,
        magnitude,
        glowIntensity,
        size,
        Offset(x + barWidth / 2, size.height - height / 2),
      );

      Rect rect;
      if (mirror) {
        final halfHeight = height / 2;
        rect = Rect.fromLTWH(x, size.height / 2 - halfHeight, barWidth, height);
      } else {
        rect = Rect.fromLTWH(x, y, barWidth, height);
      }

      if (shape == 'rounded') {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(barWidth / 2)),
          paint,
        );
      } else if (shape == 'circle') {
        canvas.drawOval(rect, paint);
      } else {
        canvas.drawRect(rect, paint);
      }
    }
  }

  void _drawWaveform(
    Canvas canvas,
    Size size,
    Paint paint,
    double glowIntensity,
  ) {
    final availableFrequencies = _getFilteredFrequencies();
    final path = Path();
    final count = barCount * 2;
    final step = size.width / count;

    path.moveTo(0, size.height / 2);

    for (int i = 0; i <= count; i++) {
      final freqIdx =
          (i / count * availableFrequencies.length).floor() %
          availableFrequencies.length;
      final magnitude = availableFrequencies[freqIdx] * sensitivity;
      final yOffset = (magnitude * size.height / 2) * (i % 2 == 0 ? 1 : -1);
      path.lineTo(i * step, size.height / 2 + yOffset);
    }

    _applyStyle(
      paint,
      0.5,
      0.5,
      glowIntensity,
      size,
      Offset(size.width / 2, size.height / 2),
    );
    paint.style = PaintingStyle.stroke;
    canvas.drawPath(path, paint);
  }

  void _drawCircular(
    Canvas canvas,
    Size size,
    Paint paint,
    double glowIntensity,
  ) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = math.min(size.width, size.height) * radius;
    final availableFrequencies = _getFilteredFrequencies();
    final count = barCount;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    for (int i = 0; i < count; i++) {
      final angle = (i / count) * math.pi * 2;
      final freqIdx = (i / count * availableFrequencies.length).floor();
      final magnitude = availableFrequencies[freqIdx] * sensitivity;
      final height = math.max(minHeight * 100, magnitude * 100) * scale;

      final innerPos = Offset(
        math.cos(angle) * baseRadius,
        math.sin(angle) * baseRadius,
      );
      final outerPos = Offset(
        math.cos(angle) * (baseRadius + height),
        math.sin(angle) * (baseRadius + height),
      );

      _applyStyle(
        paint,
        i / count,
        magnitude,
        glowIntensity,
        size,
        center + outerPos,
      );

      if (shape == 'circle' || shape == 'rounded') {
        paint.strokeCap = StrokeCap.round;
      } else {
        paint.strokeCap = StrokeCap.butt;
      }

      canvas.drawLine(innerPos, outerPos, paint);

      if (mirror) {
        final innerPosMirror = Offset(
          math.cos(angle) * baseRadius,
          math.sin(angle) * baseRadius,
        );
        final outerPosMirror = Offset(
          math.cos(angle) * (baseRadius - height),
          math.sin(angle) * (baseRadius - height),
        );
        canvas.drawLine(innerPosMirror, outerPosMirror, paint);
      }
    }
    canvas.restore();
  }

  void _drawParticles(
    Canvas canvas,
    Size size,
    Paint paint,
    double glowIntensity,
  ) {
    final availableFrequencies = _getFilteredFrequencies();
    final count = barCount;
    final random = math.Random(42); // Seeded for stability

    for (int i = 0; i < count; i++) {
      final freqIdx = (i / count * availableFrequencies.length).floor();
      final magnitude = availableFrequencies[freqIdx] * sensitivity;

      if (magnitude < 0.1) continue;

      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final pSize = magnitude * 50 * scale;

      _applyStyle(
        paint,
        i / count,
        magnitude,
        glowIntensity,
        size,
        Offset(x, y),
      );
      canvas.drawCircle(Offset(x, y), pSize, paint);
    }
  }

  void _drawSpectrum(
    Canvas canvas,
    Size size,
    Paint paint,
    double glowIntensity,
  ) {
    final availableFrequencies = _getFilteredFrequencies();
    final path = Path();
    final step = size.width / (availableFrequencies.length - 1);

    path.moveTo(0, size.height);

    for (int i = 0; i < availableFrequencies.length; i++) {
      final magnitude = availableFrequencies[i] * sensitivity;
      final x = i * step;
      final y = size.height - (magnitude * size.height);
      if (i == 0)
        path.moveTo(x, y);
      else
        path.lineTo(x, y);
    }

    if (filled) {
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
      path.close();
    }

    _applyStyle(
      paint,
      0.5,
      0.5,
      glowIntensity,
      size,
      Offset(size.width / 2, size.height / 2),
    );
    canvas.drawPath(path, paint);
  }

  List<double> _getFilteredFrequencies() {
    switch (frequencyRange) {
      case 'bass':
        return frequencies.sublist(0, frequencies.length ~/ 4);
      case 'mid':
        return frequencies.sublist(
          frequencies.length ~/ 4,
          frequencies.length ~/ 2,
        );
      case 'treble':
        return frequencies.sublist(frequencies.length ~/ 2);
      default:
        return frequencies;
    }
  }

  void _applyStyle(
    Paint paint,
    double t,
    double magnitude,
    double glowIntensity,
    Size size,
    Offset pos,
  ) {
    Color color;
    switch (colorMode) {
      case 'gradient':
        color = Color.lerp(color1, color2, t) ?? color1;
        break;
      case 'rainbow':
        color = HSVColor.fromAHSV(1.0, t * 360, 0.8, 1.0).toColor();
        break;
      case 'reactive':
        color = Color.lerp(color1, color2, magnitude) ?? color1;
        break;
      default:
        color = color1;
    }

    if (!isActive) {
      color = color.withOpacity(0.3);
    }

    paint.color = color;

    if (glow && glowIntensity > 0) {
      paint.maskFilter = MaskFilter.blur(
        BlurStyle.normal,
        10 * glowIntensity * scale,
      );
    } else {
      paint.maskFilter = null;
    }
  }

  @override
  bool shouldRepaint(covariant VisualizerPainter oldDelegate) {
    return true;
  }
}