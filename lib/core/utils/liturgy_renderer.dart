import 'package:flutter/material.dart';

class LiturgyTextRenderer {
  /// Renders text with specialized formatting for formatting "Leader:" and "People:" lines.
  ///
  /// - Leader: Light/Italic
  /// - People: Bold/Yellow
  static Widget build(
    String text, {
    required TextStyle style,
    required TextAlign align,
    int? maxLines,
    TextOverflow? overflow,
  }) {
    // Quick check to avoid overhead
    final bool hasLeader = text.contains('Leader:');
    final bool hasPeople = text.contains('People:');

    if (!hasLeader && !hasPeople) {
      return Text(
        text,
        style: style,
        textAlign: align,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    final spans = <InlineSpan>[];
    final lines = text.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();
      TextStyle lineStyle = style;

      if (trimmed.startsWith('Leader:')) {
        lineStyle = style.copyWith(
          fontWeight: FontWeight.w300, // Light
          fontStyle: FontStyle.italic,
        );
      } else if (trimmed.startsWith('People:')) {
        lineStyle = style.copyWith(
          fontWeight: FontWeight.bold,
          color: Colors.yellow, // Yellow
        );
        // Note: If original style had shadows, they persist unless overridden.
        // Colors.yellow will override the color.
      }

      spans.add(
        TextSpan(
          text: line + (i < lines.length - 1 ? '\n' : ''),
          style: lineStyle,
        ),
      );
    }

    return RichText(
      text: TextSpan(children: spans, style: style),
      textAlign: align,
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
    );
  }
}
