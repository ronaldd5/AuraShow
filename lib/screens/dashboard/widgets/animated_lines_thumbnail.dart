import 'package:flutter/material.dart';
import '../../../core/theme/palette.dart';

class AnimatedLinesThumbnail extends StatelessWidget {
  final int lines;
  final bool isSelected;

  const AnimatedLinesThumbnail({
    Key? key,
    required this.lines,
    this.isSelected = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 100,
      height: 60,
      decoration: BoxDecoration(
        color: AppPalette.carbonBlack,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? AppPalette.willowGreen : Colors.white12,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppPalette.willowGreen.withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Stack(
        children: [
          // Simulated Slide Background
          Center(
            child: Container(
              width: 80,
              height: 45,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    lines == 0 ? 6 : lines, // Show 6 lines if "No limit" (0)
                    (index) => Container(
                      margin: const EdgeInsets.symmetric(vertical: 1.5),
                      width: 50 + (index % 2 == 0 ? 10 : -10),
                      height: 2,
                      decoration: BoxDecoration(
                        color: Colors.white38,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Label
          Positioned(
            bottom: 4,
            right: 6,
            child: Text(
              lines == 0 ? 'Any' : '$lines',
              style: TextStyle(
                color: isSelected ? AppPalette.willowGreen : Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
