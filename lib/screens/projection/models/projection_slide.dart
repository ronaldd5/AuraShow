import 'package:flutter/material.dart';
import '../../../core/theme/palette.dart';

/// Model representing a slide for projection in the output window.
/// 
/// Contains all styling and content information needed to render
/// a slide on a secondary display.
class ProjectionSlide {
  ProjectionSlide({
    required this.body,
    required this.templateTextColor,
    required this.templateBackground,
    required this.templateFontSize,
    required this.templateAlign,
    this.fontSizeOverride,
    this.fontFamilyOverride,
    this.textColorOverride,
    this.alignOverride,
    this.lineHeight,
    this.letterSpacing,
    this.isBold,
    this.isItalic,
    this.isUnderline,
    this.shadowColor,
    this.shadowBlur,
    this.shadowOffsetX,
    this.shadowOffsetY,
    this.outlineColor,
    this.outlineWidth,
    this.boxPadding,
    this.boxBackgroundColor,
    this.textTransform,
    this.boxLeft,
    this.boxTop,
    this.boxWidth,
    this.boxHeight,
    this.backgroundColor,
    this.mediaPath,
    this.mediaType,
    this.mediaOpacity,
    this.hueRotate,
    this.invert,
    this.blur,
    this.brightness,
    this.contrast,
    this.saturate,
    List<ProjectionLayer>? layers,
  }) : layers = layers ?? const [];

  final String body;
  final Color templateTextColor;
  final Color templateBackground;
  final double templateFontSize;
  final TextAlign templateAlign;

  final double? fontSizeOverride;
  final String? fontFamilyOverride;
  final Color? textColorOverride;
  final TextAlign? alignOverride;
  final double? lineHeight;
  final double? letterSpacing;
  final bool? isBold;
  final bool? isItalic;
  final bool? isUnderline;
  final Color? shadowColor;
  final double? shadowBlur;
  final double? shadowOffsetX;
  final double? shadowOffsetY;
  final Color? outlineColor;
  final double? outlineWidth;
  final double? boxPadding;
  final Color? boxBackgroundColor;
  final String? textTransform;
  final double? boxLeft;
  final double? boxTop;
  final double? boxWidth;
  final double? boxHeight;
  final Color? backgroundColor;
  final String? mediaPath;
  final String? mediaType;
  final double? mediaOpacity;
  final double? hueRotate;
  final double? invert;
  final double? blur;
  final double? brightness;
  final double? contrast;
  final double? saturate;
  final List<ProjectionLayer> layers;

  factory ProjectionSlide.fromJson(Map<String, dynamic> json) {
    Color? parseColor(dynamic v) => v == null ? null : Color(v as int);
    double? numToDouble(dynamic v) => (v as num?)?.toDouble();

    return ProjectionSlide(
      body: json['body'] ?? '',
      templateTextColor: parseColor(json['templateTextColor']) ?? Colors.white,
      templateBackground: parseColor(json['templateBackground']) ?? AppPalette.carbonBlack,
      templateFontSize: numToDouble(json['templateFontSize']) ?? 38,
      templateAlign: TextAlign.values.firstWhere(
        (e) => e.name == (json['templateAlign'] ?? 'center'),
        orElse: () => TextAlign.center,
      ),
      fontSizeOverride: numToDouble(json['fontSizeOverride']),
      fontFamilyOverride: json['fontFamilyOverride'] as String?,
      textColorOverride: parseColor(json['textColorOverride']),
      alignOverride: json['alignOverride'] != null
          ? TextAlign.values.firstWhere(
              (e) => e.name == json['alignOverride'],
              orElse: () => TextAlign.center,
            )
          : null,
      lineHeight: numToDouble(json['lineHeight']),
      letterSpacing: numToDouble(json['letterSpacing']),
      isBold: json['isBold'] as bool?,
      isItalic: json['isItalic'] as bool?,
      isUnderline: json['isUnderline'] as bool?,
      shadowColor: parseColor(json['shadowColor']),
      shadowBlur: numToDouble(json['shadowBlur']),
      shadowOffsetX: numToDouble(json['shadowOffsetX']),
      shadowOffsetY: numToDouble(json['shadowOffsetY']),
      outlineColor: parseColor(json['outlineColor']),
      outlineWidth: numToDouble(json['outlineWidth']),
      boxPadding: numToDouble(json['boxPadding']),
      boxBackgroundColor: parseColor(json['boxBackgroundColor']),
      textTransform: json['textTransform'] as String?,
      boxLeft: numToDouble(json['boxLeft']),
      boxTop: numToDouble(json['boxTop']),
      boxWidth: numToDouble(json['boxWidth']),
      boxHeight: numToDouble(json['boxHeight']),
      backgroundColor: parseColor(json['backgroundColor']),
      mediaPath: json['mediaPath'] as String?,
      mediaType: json['mediaType'] as String?,
      mediaOpacity: numToDouble(json['mediaOpacity']) ?? 1.0,
      hueRotate: numToDouble(json['hueRotate']),
      invert: numToDouble(json['invert']),
      blur: numToDouble(json['blur']),
      brightness: numToDouble(json['brightness']),
      contrast: numToDouble(json['contrast']),
      saturate: numToDouble(json['saturate']),
      layers: () {
        debugPrint('proj: parsing layers, json[layers]=${json['layers']?.runtimeType} length=${(json['layers'] as List?)?.length ?? 0}');
        return (json['layers'] as List?)
              ?.map((e) => ProjectionLayer.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [];
      }(),
    );
  }
}

/// Model representing a single layer in a projection slide.
/// 
/// Layers can be either media (image/video) or text content,
/// positioned at normalized coordinates (0-1) on the stage.
class ProjectionLayer {
  ProjectionLayer({
    required this.kind,
    required this.role,
    this.text,
    this.path,
    this.mediaType,
    this.left,
    this.top,
    this.width,
    this.height,
    this.opacity,
  });

  /// The kind of layer: 'media' or 'textbox'
  final String kind;
  
  /// The role of the layer: 'background' or 'foreground'
  final String role;
  
  /// Text content for textbox layers
  final String? text;
  
  /// File path for media layers
  final String? path;
  
  /// Media type: 'image' or 'video'
  final String? mediaType;
  
  /// Normalized left position (0-1)
  final double? left;
  
  /// Normalized top position (0-1)
  final double? top;
  
  /// Normalized width (0-1)
  final double? width;
  
  /// Normalized height (0-1)
  final double? height;
  
  /// Layer opacity (0-1)
  final double? opacity;

  factory ProjectionLayer.fromJson(Map<String, dynamic> json) {
    double? numToDouble(dynamic v) => (v as num?)?.toDouble();
    final layer = ProjectionLayer(
      kind: json['kind'] as String? ?? 'media',
      role: json['role'] as String? ?? 'foreground',
      text: json['text'] as String?,
      path: json['path'] as String?,
      mediaType: json['mediaType'] as String?,
      left: numToDouble(json['left']),
      top: numToDouble(json['top']),
      width: numToDouble(json['width']),
      height: numToDouble(json['height']),
      opacity: numToDouble(json['opacity']) ?? 1.0,
    );
    debugPrint('proj: parsed layer kind=${layer.kind} role=${layer.role} left=${layer.left} top=${layer.top} width=${layer.width} height=${layer.height}');
    return layer;
  }
}
