import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Service for managing group/section label colors (Verse, Chorus, Bridge, etc.)
/// Allows users to customize colors and persists preferences to disk.
class LabelColorService {
  // Singleton pattern
  static final LabelColorService instance = LabelColorService._();
  LabelColorService._();

  // The Default "FreeShow-style" Palette
  final Map<String, Color> _defaults = {
    'VERSE': const Color(0xFF3498DB), // Blue
    'CHORUS': const Color(0xFFE74C3C), // Red
    'BRIDGE': const Color(0xFFF39C12), // Orange
    'PRE-CHORUS': const Color(0xFF9B59B6), // Purple
    'TAG': const Color(0xFF1ABC9C), // Teal
    'ENDING': const Color(0xFF34495E), // Dark Grey
    'INTRO': const Color(0xFF2ECC71), // Green
    'OUTRO': const Color(0xFF95A5A6), // Light Grey
    'HOOK': const Color(0xFFE91E63), // Pink
    'VAMP': const Color(0xFF00BCD4), // Cyan
  };

  // The Active Map (starts with defaults)
  Map<String, Color> _currentColors = {};

  bool _isInitialized = false;

  // Initialize and load from disk
  Future<void> load() async {
    if (_isInitialized) return;

    _currentColors = Map.from(_defaults); // Start with defaults

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? savedData = prefs.getString('group_colors');

      if (savedData != null) {
        final Map<String, dynamic> jsonMap = jsonDecode(savedData);
        jsonMap.forEach((key, value) {
          // JSON stores colors as Integers (ARGB)
          _currentColors[key] = Color(value as int);
        });
      }
      _isInitialized = true;
    } catch (e) {
      debugPrint("Error loading color settings: $e");
    }
  }

  /// Get color for a label (Case Insensitive, strips numbers)
  /// "Verse 1" -> looks up "VERSE"
  Color getColor(String label) {
    // Normalize: "Verse 1" -> "VERSE", "Pre-Chorus 2" -> "PRE-CHORUS"
    String key = label
        .toUpperCase()
        .replaceAll(RegExp(r'\s*\d+$'), '') // Remove trailing numbers
        .trim();

    return _currentColors[key] ?? Colors.grey.shade700;
  }

  /// Save a new color preference
  Future<void> setColor(String label, Color color) async {
    final key = label.toUpperCase().replaceAll(RegExp(r'\s*\d+$'), '').trim();
    _currentColors[key] = color;

    // Save to disk
    try {
      final prefs = await SharedPreferences.getInstance();
      // Convert Colors to Ints for JSON
      final Map<String, int> saveMap = _currentColors.map(
        (key, value) => MapEntry(key, value.value),
      );
      await prefs.setString('group_colors', jsonEncode(saveMap));
    } catch (e) {
      debugPrint("Error saving color settings: $e");
    }
  }

  /// Get list of all known groups (sorted)
  List<String> get groups {
    final list = _currentColors.keys.toList();
    list.sort();
    return list;
  }

  // Alias for backward compatibility if needed, or deprecate knownGroups
  List<String> get knownGroups => groups;

  /// Update or add a group color
  Future<void> updateGroup(String label, Color color) async =>
      setColor(label, color);

  /// Get all current colors (for display)
  Map<String, Color> get currentColors => Map.from(_currentColors);

  /// Reset to defaults
  Future<void> resetToDefaults() async {
    _currentColors = Map.from(_defaults);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('group_colors');
    } catch (e) {
      debugPrint("Error resetting color settings: $e");
    }
  }

  /// Default fallback color
  Color get defaultColor => Colors.grey;
}
