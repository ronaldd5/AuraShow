import 'package:flutter/material.dart';

enum StageElementType {
  clock,
  timer,
  nextSlide,
  currentSlide,
  message,
  customText,
}

class StageElement {
  final String id;
  final StageElementType type;
  final Rect rect; // Normalized coordinates (0.0 - 1.0)
  final String? text; // For custom text
  final Map<String, dynamic>
  data; // For element-specific settings (clock format, etc)
  final double? fontSize;
  final Color? color;
  final bool visible;

  const StageElement({
    required this.id,
    required this.type,
    required this.rect,
    this.text,
    this.data = const {},
    this.fontSize,
    this.color,
    this.visible = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'rect': {
      'left': rect.left,
      'top': rect.top,
      'width': rect.width,
      'height': rect.height,
    },
    'text': text,
    'data': data,
    'fontSize': fontSize,
    'color': color?.value,
    'visible': visible,
  };

  factory StageElement.fromJson(Map<String, dynamic> json) {
    final r = json['rect'];
    return StageElement(
      id: json['id'],
      type: StageElementType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => StageElementType.customText,
      ),
      rect: Rect.fromLTWH(
        (r['left'] as num).toDouble(),
        (r['top'] as num).toDouble(),
        (r['width'] as num).toDouble(),
        (r['height'] as num).toDouble(),
      ),
      text: json['text'],
      data: json['data'] != null
          ? Map<String, dynamic>.from(json['data'])
          : const {},
      fontSize: (json['fontSize'] as num?)?.toDouble(),
      color: json['color'] != null ? Color(json['color']) : null,
      visible: json['visible'] ?? true,
    );
  }

  StageElement copyWith({
    Rect? rect,
    String? text,
    Map<String, dynamic>? data,
    double? fontSize,
    Color? color,
    bool? visible,
  }) {
    return StageElement(
      id: id,
      type: type,
      rect: rect ?? this.rect,
      text: text ?? this.text,
      data: data ?? this.data,
      fontSize: fontSize ?? this.fontSize,
      color: color ?? this.color,
      visible: visible ?? this.visible,
    );
  }
}

class StageLayout {
  final String id;
  final String name;
  final List<StageElement> elements;

  const StageLayout({
    required this.id,
    required this.name,
    this.elements = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'elements': elements.map((e) => e.toJson()).toList(),
  };

  factory StageLayout.fromJson(Map<String, dynamic> json) {
    return StageLayout(
      id: json['id'],
      name: json['name'],
      elements:
          (json['elements'] as List?)
              ?.map((e) => StageElement.fromJson(e))
              .toList() ??
          [],
    );
  }

  StageLayout copyWith({String? name, List<StageElement>? elements}) {
    return StageLayout(
      id: id,
      name: name ?? this.name,
      elements: elements ?? this.elements,
    );
  }
}
