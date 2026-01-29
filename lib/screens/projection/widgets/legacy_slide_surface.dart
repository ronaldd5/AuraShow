import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/theme/palette.dart';

/// Legacy slide surface for simple text-only projection.
///
/// Used as fallback when no rich slide data is available.
class LegacySlideSurface extends StatelessWidget {
  const LegacySlideSurface({
    super.key,
    required this.stageWidth,
    required this.stageHeight,
    required this.content,
    required this.alignment,
    required this.imagePath,
    this.output,
    this.backgroundActive = true,
    this.slideActive = true,
    this.overlayActive = true,
  });

  final double stageWidth;
  final double stageHeight;
  final String content;
  final TextAlign alignment;
  final String? imagePath;
  final Map<String, dynamic>? output;
  final bool backgroundActive;
  final bool slideActive;
  final bool overlayActive;

  @override
  Widget build(BuildContext context) {
    final bool isStageNotes =
        (output?['styleProfile'] == 'stageNotes') ||
        (output?['stageNotes'] == true);
    return Container(
      key: ValueKey<String>("$content-$imagePath-${alignment.name}"),
      width: stageWidth,
      height: stageHeight,
      decoration: BoxDecoration(
        color: backgroundActive
            ? AppPalette.carbonBlack
            : AppPalette.carbonBlack,
        image: backgroundActive && imagePath != null
            ? DecorationImage(
                image: imagePath!.startsWith('http')
                    ? NetworkImage(imagePath!)
                    : FileImage(File(imagePath!)) as ImageProvider,
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: Container(
        color: imagePath != null
            ? AppPalette.carbonBlack.withOpacity(0.45)
            : Colors.transparent,
        alignment: Alignment.center,
        child: slideActive
            ? Text(
                content,
                textAlign: alignment,
                style: const TextStyle(
                  fontSize: 80,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(blurRadius: 20, color: AppPalette.carbonBlack),
                  ],
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
