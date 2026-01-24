import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:google_fonts/google_fonts.dart';

class ScriptureDisplay extends StatelessWidget {
  const ScriptureDisplay({
    super.key,
    required this.text,
    required this.reference,
    required this.highlightedIndices,
    this.onWordTap,
    this.fontSize = 50,
    this.textColor = Colors.white,
    this.fontFamily = 'Roboto',
    this.textAlign = TextAlign.center,
  });

  final String text;
  final String reference;
  final List<int> highlightedIndices;
  final Function(int index)? onWordTap;
  final double fontSize;
  final Color textColor;
  final String fontFamily;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final words = _splitIntoWords(text);

    // Create the text span logic once so we can use it for both Widget and TextPainter
    TextSpan buildTextSpan() {
      return TextSpan(
        children: words.asMap().entries.map((entry) {
          final index = entry.key;
          final word = entry.value;
          final isHighlighted = highlightedIndices.contains(index);

          return TextSpan(text: '$word ', style: _getWordStyle(isHighlighted));
        }).toList(),
      );
    }

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final textSpan = buildTextSpan();

                  // Use Text.rich for rendering
                  // We wrap it in a GestureDetector to capture taps at the widget level
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) {
                      if (onWordTap == null) return;

                      // Use TextPainter to determine which word was clicked
                      final rootStyle = GoogleFonts.getFont(
                        fontFamily,
                        fontSize: fontSize,
                        color: textColor,
                        height: 1.3,
                      );

                      // Rebuild the span with the root style as parent style
                      final styledSpan = TextSpan(
                        style: rootStyle,
                        children: words.asMap().entries.map((entry) {
                          final index = entry.key;
                          final word = entry.value;
                          final isHighlighted = highlightedIndices.contains(
                            index,
                          );
                          return TextSpan(
                            text: '$word ',
                            style: _getWordStyle(isHighlighted),
                          );
                        }).toList(),
                      );

                      final textPainter = TextPainter(
                        text: styledSpan,
                        textDirection: TextDirection.ltr,
                        textAlign: textAlign,
                      );

                      textPainter.layout(maxWidth: constraints.maxWidth);

                      final relativePosition = details.localPosition;
                      final position = textPainter.getPositionForOffset(
                        relativePosition,
                      );

                      // Map character offset to word index
                      int currentOffset = 0;
                      for (int i = 0; i < words.length; i++) {
                        final word = words[i];
                        // +1 for the space we added
                        final endOffset = currentOffset + word.length + 1;

                        if (position.offset >= currentOffset &&
                            position.offset < endOffset) {
                          onWordTap!(i);
                          return;
                        }
                        currentOffset = endOffset;
                      }
                    },
                    child: Text.rich(
                      textSpan,
                      style: GoogleFonts.getFont(
                        fontFamily,
                        fontSize: fontSize,
                        color: textColor,
                        height: 1.3,
                      ),
                      textAlign: textAlign,
                    ),
                  );
                },
              ),
              SizedBox(height: fontSize * 0.4),
              Text(
                reference,
                style: GoogleFonts.getFont(
                  fontFamily,
                  fontSize: fontSize * 0.6,
                  color: textColor.withOpacity(0.8),
                  fontWeight: FontWeight.w300,
                ),
                textAlign: textAlign,
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle _getWordStyle(bool isHighlighted) {
    if (!isHighlighted) {
      return TextStyle(color: textColor);
    }

    return TextStyle(
      color: const Color(0xFFFFD700), // Gold
      fontWeight: FontWeight.bold,
      shadows: [
        BoxShadow(
          color: const Color(0xFFFFD700).withOpacity(0.6),
          blurRadius: 15,
          spreadRadius: 5,
        ),
        const BoxShadow(
          color: Colors.black45,
          blurRadius: 4,
          offset: Offset(2, 2),
        ),
      ],
    );
  }

  List<String> _splitIntoWords(String text) {
    // Basic splitting by whitespace, filtering empty strings
    return text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  }
}
