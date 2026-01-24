import 'package:flutter/material.dart';

/// Centralized modern dark theme palette.
class AppPalette {
  /// Main Background: Pure Black
  static const Color background = Color(0xFF18181B); // Material Dark Surface

  /// Surface: Very dark gray for panels/cards to separate from black bg
  static const Color surface = Color(0xFF27272A); // Lighter Surface

  /// Surface Highlight: For hover states or active elements
  static const Color surfaceHighlight = Color(0xFF3F3F46);

  /// Border: Subtle dark separator
  static const Color border = Color(0xFF333333);

  /// Primary Accent: Unified Darker Blue
  static const Color primary = Color(0xFF0284C7); // Sky 600

  /// Secondary Accent: Complementary lighter blue
  static const Color accent = Color(0xFF38BDF8); // Sky 400

  /// Text Primary: High contrast white
  static const Color textPrimary = Color(0xFFFFFFFF);

  /// Text Secondary: Muted gray for subtitles/labels
  static const Color textSecondary = Color(0xFFB3B3B3);

  /// Text Muted: Disabled or low priority text
  static const Color textMuted = Color(0xFF666666);

  // Legacy mappings for backward compatibility during refactor
  static const Color carbonBlack = background;
  static const Color willowGreen = primary;
  static const Color dustyRose = accent;
  static const Color dustyMauve = Color(0xFF0284C7); // Darker Blue (Sky 600)
  static const Color teaGreen = textPrimary;

  static const LinearGradient mainGradient = LinearGradient(
    colors: [background, surface],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
