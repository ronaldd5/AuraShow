import 'package:flutter/material.dart';
import '../core/theme/palette.dart';

class CustomSidebar extends StatelessWidget {
  const CustomSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      decoration: BoxDecoration(
        color: AppPalette.carbonBlack,
        border: const Border(right: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        children: [
          _sideIcon(Icons.layers, true),
          _sideIcon(Icons.image, false),
          _sideIcon(Icons.video_collection, false),
          _sideIcon(Icons.font_download, false),
          const Spacer(),
          _sideIcon(Icons.help_outline, false),
        ],
      ),
    );
  }

  Widget _sideIcon(IconData icon, bool active) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Icon(icon, color: active ? AppPalette.dustyMauve : AppPalette.dustyRose, size: 24),
    );
  }
}