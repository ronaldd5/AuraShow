import 'dart:convert';
import 'package:flutter/material.dart';

import 'package:flutter/scheduler.dart';
import 'package:video_player/video_player.dart';

/// specialized builder that ticks every frame to update the time from a controller
class KaraokePlaybackBuilder extends StatefulWidget {
  final VideoPlayerController? controller;
  final Widget Function(BuildContext, Duration) builder;

  const KaraokePlaybackBuilder({
    super.key,
    this.controller,
    required this.builder,
  });

  @override
  State<KaraokePlaybackBuilder> createState() => _KaraokePlaybackBuilderState();
}

class _KaraokePlaybackBuilderState extends State<KaraokePlaybackBuilder>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  Duration _lastPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (widget.controller == null) return;
    if (widget.controller!.value.isPlaying) {
      final pos = widget.controller!.value.position;
      if (pos != _lastPosition) {
        setState(() => _lastPosition = pos);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _lastPosition);
  }
}

class KaraokeTextRenderer extends StatefulWidget {
  final String text;
  final String?
  alignmentData; // JSON string: {"start": 0.5, "end": 0.8, "word": "Amaz"}
  final Duration currentTime;
  final TextStyle style;
  final Color activeColor;
  final Color inactiveColor;

  const KaraokeTextRenderer({
    super.key,
    required this.text,
    this.alignmentData,
    required this.currentTime,
    required this.style,
    this.activeColor = Colors.blueAccent,
    this.inactiveColor = Colors.grey,
  });

  @override
  State<KaraokeTextRenderer> createState() => _KaraokeTextRendererState();
}

class _KaraokeTextRendererState extends State<KaraokeTextRenderer> {
  List<_KaraokeToken> _tokens = [];

  @override
  void initState() {
    super.initState();
    _parseAlignment();
  }

  @override
  void didUpdateWidget(covariant KaraokeTextRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.alignmentData != oldWidget.alignmentData ||
        widget.text != oldWidget.text) {
      _parseAlignment();
    }
  }

  void _parseAlignment() {
    if (widget.alignmentData == null || widget.alignmentData!.isEmpty) {
      _tokens = [];
      return;
    }

    try {
      final List<dynamic> jsonList = json.decode(widget.alignmentData!);
      _tokens = jsonList.map((e) => _KaraokeToken.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error parsing alignment data: $e');
      _tokens = [];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_tokens.isEmpty) {
      // Fallback to simple text if no matching alignment data
      return Text(
        widget.text,
        style: widget.style.copyWith(color: widget.activeColor),
        textAlign: TextAlign.center,
      );
    }

    // "The Flex": Render gradient text based on timing
    // We will build a RichText with TextSpans.
    // Ideally we want a granular character-level gradient, but TextSpan only supports color.
    // For true "wipe", we might need ShaderMask.
    // Let's implement word/syllable-level highlighting first (easier and functional).
    // "Active Color" for passed words, "Inactive" for future.
    // Interpolate the *current* word.

    List<InlineSpan> spans = [];
    final currentSec = widget.currentTime.inMilliseconds / 1000.0;

    for (var token in _tokens) {
      Color color = widget.inactiveColor;

      if (currentSec >= token.end) {
        // Already sung
        color = widget.activeColor;
      } else if (currentSec >= token.start) {
        // Currently singing (interpolate?)
        // Simple switch for now, or use ShaderMask for advanced wipe
        color = Color.lerp(
          widget.inactiveColor,
          widget.activeColor,
          (currentSec - token.start) / (token.end - token.start),
        )!;
      }

      spans.add(
        TextSpan(
          text: token.word,
          style: widget.style.copyWith(color: color),
        ),
      );
      // Add space if needed? Alignment usually includes trailing space or handled by tokens.
      // Assuming tokens cover the text.
    }

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(children: spans),
    );
  }
}

class _KaraokeToken {
  final String word;
  final double start;
  final double end;

  _KaraokeToken({required this.word, required this.start, required this.end});

  factory _KaraokeToken.fromJson(Map<String, dynamic> json) {
    return _KaraokeToken(
      word: json['word'] ?? '',
      start: (json['start'] as num).toDouble(),
      end: (json['end'] as num).toDouble(),
    );
  }
}
