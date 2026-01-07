import 'package:flutter/material.dart';

/// Defines the type of media associated with a slide.
enum MediaType { image, video, youtube, none }

class Slide {
  String id;
  String title;
  String content;
  double fontSize;
  
  // Media Properties
  String? mediaPath; // Can be a local File path or a YouTube URL
  MediaType mediaType;
  
  // Layout Properties
  TextAlign alignment;
  
  // Grouping Properties (The "FreeShow" look)
  String groupName; // e.g., "Verse 1", "Chorus", "Bridge"
  Color groupColor; // The identifying color for the group footer/label

  Slide({
    required this.id,
    required this.title,
    required this.content,
    this.fontSize = 40,
    this.mediaPath,
    this.mediaType = MediaType.none,
    this.alignment = TextAlign.center,
    this.groupName = "Verse",
    this.groupColor = const Color(0xFF1E40AF), // Default Semi-Dark Blue
  });

  /// Helper method to create a copy of a slide with modified fields
  Slide copyWith({
    String? id,
    String? title,
    String? content,
    double? fontSize,
    String? mediaPath,
    MediaType? mediaType,
    TextAlign? alignment,
    String? groupName,
    Color? groupColor,
  }) {
    return Slide(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      fontSize: fontSize ?? this.fontSize,
      mediaPath: mediaPath ?? this.mediaPath,
      mediaType: mediaType ?? this.mediaType,
      alignment: alignment ?? this.alignment,
      groupName: groupName ?? this.groupName,
      groupColor: groupColor ?? this.groupColor,
    );
  }

  /// Converts a Slide to a Map for JSON storage (SharedPreferences)
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'fontSize': fontSize,
        'mediaPath': mediaPath,
        'mediaType': mediaType.name,
        'alignment': alignment.name,
        'groupName': groupName,
        'groupColor': groupColor.value,
      };

  /// Creates a Slide from a Map (retrieved from SharedPreferences)
  factory Slide.fromJson(Map<String, dynamic> json) {
    final int colorValue;
    final dynamic rawColor = json['groupColor'];
    if (rawColor is int) {
      colorValue = rawColor;
    } else if (rawColor is String) {
      colorValue = int.tryParse(rawColor) ?? 0xFF1E40AF;
    } else {
      colorValue = 0xFF1E40AF;
    }

    return Slide(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      fontSize: (json['fontSize'] ?? 40.0).toDouble(),
      mediaPath: json['mediaPath'],
      mediaType: MediaType.values.firstWhere(
        (e) => e.name == (json['mediaType'] ?? "none"),
        orElse: () => MediaType.none,
      ),
      alignment: TextAlign.values.firstWhere(
        (e) => e.name == (json['alignment'] ?? "center"),
        orElse: () => TextAlign.center,
      ),
      groupName: json['groupName'] ?? "Verse",
      groupColor: Color(colorValue),
    );
  }
}