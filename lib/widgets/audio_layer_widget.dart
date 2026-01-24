import 'package:flutter/material.dart';
import '../models/slide_model.dart';

/// Widget to render an audio layer in the editor/projection.
/// Displays an audio icon with the file name. Playback is handled separately.
class AudioLayerWidget extends StatelessWidget {
  final SlideLayer layer;
  final double scale;
  final bool showControls;

  const AudioLayerWidget({
    Key? key,
    required this.layer,
    this.scale = 1.0,
    this.showControls = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textColor = layer.textColor ?? Colors.white;
    final boxColor = layer.boxColor ?? Colors.black54;
    final fileName = layer.path?.split(RegExp(r'[/\\]')).last ?? 'Audio';
    final baseFontSize = 16.0 * scale;

    return Container(
      decoration: BoxDecoration(
        color: boxColor,
        borderRadius: BorderRadius.circular(12 * scale),
        border: Border.all(color: textColor.withOpacity(0.3), width: 2 * scale),
      ),
      padding: EdgeInsets.all(12 * scale),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.music_note, size: 48 * scale, color: textColor),
          SizedBox(height: 8 * scale),
          Text(
            fileName,
            style: TextStyle(
              color: textColor,
              fontSize: baseFontSize,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          if (showControls) ...[
            SizedBox(height: 12 * scale),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.play_arrow,
                    color: textColor,
                    size: 24 * scale,
                  ),
                  onPressed: () {
                    // Playback handled by parent
                  },
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
                SizedBox(width: 8 * scale),
                IconButton(
                  icon: Icon(Icons.stop, color: textColor, size: 24 * scale),
                  onPressed: () {
                    // Stop handled by parent
                  },
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
