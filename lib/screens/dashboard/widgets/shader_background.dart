import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../models/slide_model.dart';
import 'package:flutter/scheduler.dart';

class ShaderWidget extends StatefulWidget {
  const ShaderWidget({
    super.key,
    this.shaderId,
    this.opacity = 1.0,
    this.boxColor,
    this.audioLevelStr = 0.0,
    this.speed = 1.0,
    this.intensity = 1.0,
    this.color1,
    this.color2,
  });

  final String? shaderId;
  final double opacity;
  final Color? boxColor;
  final double audioLevelStr;
  final double speed;
  final double intensity;
  final Color? color1;
  final Color? color2;

  @override
  State<ShaderWidget> createState() => _ShaderWidgetState();
}

class _ShaderWidgetState extends State<ShaderWidget>
    with SingleTickerProviderStateMixin {
  FragmentProgram? _program;
  late Ticker _ticker;
  double _time = 0.0;

  // Audio reactivity
  double _bassLevel = 0.0;
  Timer? _audioTimer;
  String? _error; // Added to track errors

  @override
  void initState() {
    super.initState();
    _loadShader();
    _ticker = createTicker(_onTick)..start();

    // Simulate audio reactivity for now if no real source
    // In a real implementation, we'd listen to a stream here
    _startAudioSimulation();
  }

  void _loadShader() async {
    try {
      // Default to background.frag if shaderId is not specified or basic
      String assetKey = 'shaders/bg_shader.frag';
      if (widget.shaderId != null && widget.shaderId!.isNotEmpty) {
        // logic to map ID to asset path could go here
        // for now we only have one shader
      }

      final program = await FragmentProgram.fromAsset(assetKey);
      if (mounted) {
        setState(() {
          _program = program;
        });
      }
    } catch (e) {
      debugPrint('Error loading shader: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  void _startAudioSimulation() {
    // If we had a real AudioService, we would listen here:
    // _audioSubscription = AudioService.instance.bassStream.listen((level) { ... });

    // For now, simulate a "beat"
    _audioTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (mounted) {
        // Simple sine wave simulation
        // In real app, this comes from mic analysis
        double simulatedBass =
            (0.5 + 0.5 * DateTime.now().millisecondsSinceEpoch % 1000 / 1000.0);
        setState(() {
          _bassLevel = simulatedBass;
        });
      }
    });
  }

  void _onTick(Duration elapsed) {
    setState(() {
      _time = elapsed.inMilliseconds / 1000.0;
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _audioTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Container(
        color: Colors.red.shade900,
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            'Shader Error:\n$_error',
            style: const TextStyle(color: Colors.white, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_program == null) {
      return Container(
        color: widget.boxColor ?? Colors.black,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return CustomPaint(
      painter: _ShaderPainter(
        program: _program!,
        time: _time,
        // Use real audio level if provided (e.g. from props), else simulated
        audioLevel: widget.audioLevelStr > 0
            ? widget.audioLevelStr
            : _bassLevel,
        opacity: widget.opacity,
        speed: widget.speed,
        intensity: widget.intensity,
        color1: widget.color1 ?? Colors.purple, // Default Fallback
        color2: widget.color2 ?? Colors.blue, // Default Fallback
      ),
      child: Container(),
    );
  }
}

class _ShaderPainter extends CustomPainter {
  _ShaderPainter({
    required this.program,
    required this.time,
    required this.audioLevel,
    required this.opacity,
    required this.speed,
    required this.intensity,
    required this.color1,
    required this.color2,
  });

  final FragmentProgram program;
  final double time;
  final double audioLevel;
  final double opacity;
  final double speed;
  final double intensity;
  final Color color1;
  final Color color2;

  @override
  void paint(Canvas canvas, Size size) {
    // Validating uniform count would be good but for now we assume strict layout
    try {
      final shader = program.fragmentShader();

      // 0: uTime
      shader.setFloat(0, time);
      // 1: uResolution (x, y)
      shader.setFloat(1, size.width);
      shader.setFloat(2, size.height);
      // 3: uAudio
      shader.setFloat(3, audioLevel);
      // 4: uSpeed
      shader.setFloat(4, speed);
      // 5: uIntensity
      shader.setFloat(5, intensity);
      // 6: uColor1
      shader.setFloat(6, color1.red / 255.0);
      shader.setFloat(7, color1.green / 255.0);
      shader.setFloat(8, color1.blue / 255.0);
      shader.setFloat(9, color1.opacity);
      // 10: uColor2
      shader.setFloat(10, color2.red / 255.0);
      shader.setFloat(11, color2.green / 255.0);
      shader.setFloat(12, color2.blue / 255.0);
      shader.setFloat(13, color2.opacity);

      final paint = Paint()
        ..shader = shader
        ..color = Colors.white.withOpacity(opacity);

      canvas.drawRect(Offset.zero & size, paint);
    } catch (e) {
      debugPrint("Shader Paint Error: $e");
    }
  }

  @override
  bool shouldRepaint(covariant _ShaderPainter oldDelegate) {
    return oldDelegate.time != time ||
        oldDelegate.audioLevel != audioLevel ||
        oldDelegate.opacity != opacity ||
        oldDelegate.speed != speed ||
        oldDelegate.intensity != intensity ||
        oldDelegate.color1 != color1 ||
        oldDelegate.color2 != color2;
  }
}
