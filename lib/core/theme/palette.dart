import 'package:flutter/material.dart';

/// Centralized color palette derived from the current scheme.
class AppPalette {
  static const Color teaGreen = Color(0xFFFFFFFF); // repurposed: all text white
  static const Color willowGreen = Color(0xFF5D737E); // accent slate
  static const Color dustyRose = Color(0xFFE6AF2E); // accent gold
  static const Color dustyMauve = Color(0xFFA3320B); // accent rust
  static const Color carbonBlack = Color(0xFF1A1A1A); // main background (further lifted for clearer surface edges)

  static const LinearGradient mainGradient = LinearGradient(
    colors: [carbonBlack, willowGreen, dustyRose, dustyMauve, teaGreen],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
